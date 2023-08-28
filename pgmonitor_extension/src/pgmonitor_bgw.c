/*
 * pgmonitor_bgw.c
 *
 * A background worker process to refresh the materialized views
 * for the pgmonitor metrics.
 * Runs within the database itself without needing a third-party scheduler
 */

#include "postgres.h"

/* These are always necessary for a bgworker */
#include "miscadmin.h"
#include "postmaster/bgworker.h"
#include "storage/ipc.h"
#include "storage/latch.h"
#include "storage/lwlock.h"
#include "storage/proc.h"
#include "storage/shmem.h"

/* these headers are used by this particular worker's code */
#include "access/xact.h"
#include "executor/spi.h"
#include "fmgr.h"
#include "lib/stringinfo.h"
#include "pgstat.h"
#include "utils/builtins.h"
#include "utils/snapmgr.h"
#include "tcop/utility.h"
#include "commands/async.h"
#include "utils/varlena.h"
#include "tcop/pquery.h"
#include "utils/memutils.h"


PG_MODULE_MAGIC;

void        _PG_init(void);
PGDLLEXPORT void pgmonitor_bgw_main(Datum);
PGDLLEXPORT void pgmonitor_bgw_run_maint(Datum);

/* flags set by signal handlers */
static volatile sig_atomic_t got_sighup = false;
static volatile sig_atomic_t got_sigterm = false;

/* GUC variables */
static int pgmonitor_bgw_interval = 30; // Default 30 seconds
static char *pgmonitor_bgw_role = "postgres"; // Default to postgres role
static char *pgmonitor_bgw_dbname = NULL;

static bool (*split_function_ptr)(char *, char, List **) = &SplitGUCList;

/*
 * Signal handler for SIGTERM
 *      Set a flag to let the main loop to terminate, and set our latch to wake
 *      it up.
 */
static void
pgmonitor_bgw_sigterm(SIGNAL_ARGS)
{
    int         save_errno = errno;

    got_sigterm = true;

    if (MyProc)
        SetLatch(&MyProc->procLatch);

    errno = save_errno;
}

/*
 * Signal handler for SIGHUP
 *      Set a flag to tell the main loop to reread the config file, and set
 *      our latch to wake it up.
 */
static void pgmonitor_bgw_sighup(SIGNAL_ARGS) {
    int         save_errno = errno;

    got_sighup = true;

    if (MyProc)
        SetLatch(&MyProc->procLatch);

    errno = save_errno;
}

/*
 * Entrypoint of this module.
 */
void
_PG_init(void)
{
    BackgroundWorker worker;

    DefineCustomIntVariable("pgmonitor_bgw.interval",
                            "How often refresh is called (in seconds).",
                            NULL,
                            &pgmonitor_bgw_interval,
                            30,
                            1,
                            INT_MAX,
                            PGC_SIGHUP,
                            0,
                            NULL,
                            NULL,
                            NULL);

    DefineCustomStringVariable("pgmonitor_bgw.dbname",
                            "CSV list of specific databases in the cluster to run pgmonitor BGW on.",
                            NULL,
                            &pgmonitor_bgw_dbname,
                            NULL,
                            PGC_SIGHUP,
                            0,
                            NULL,
                            NULL,
                            NULL);

    DefineCustomStringVariable("pgmonitor_bgw.role",
                               "Role to be used by BGW. Must have execute permissions on refresh_metrics() and permission to refresh all materialized views and table sources maintained by pgmonitor",
                               NULL,
                               &pgmonitor_bgw_role,
                               "postgres",
                               PGC_SIGHUP,
                               0,
                               NULL,
                               NULL,
                               NULL);

    if (!process_shared_preload_libraries_in_progress)
        return;

    // Start BGW when database starts
    sprintf(worker.bgw_name, "pgmonitor master background worker");
    worker.bgw_flags = BGWORKER_SHMEM_ACCESS |
        BGWORKER_BACKEND_DATABASE_CONNECTION;
    worker.bgw_start_time = BgWorkerStart_RecoveryFinished;
    worker.bgw_restart_time = 600;
    sprintf(worker.bgw_library_name, "pgmonitor_bgw");
    sprintf(worker.bgw_function_name, "pgmonitor_bgw_main");
    worker.bgw_main_arg = CStringGetDatum(pgmonitor_bgw_dbname);
    worker.bgw_notify_pid = 0;
    RegisterBackgroundWorker(&worker);

}

void pgmonitor_bgw_main(Datum main_arg) {
    StringInfoData buf;

    /* Establish signal handlers before unblocking signals. */
    pqsignal(SIGHUP, pgmonitor_bgw_sighup);
    pqsignal(SIGTERM, pgmonitor_bgw_sigterm);

    /* We're now ready to receive signals */
    BackgroundWorkerUnblockSignals();

    elog(LOG, "%s master process initialized with role %s"
            , MyBgworkerEntry->bgw_name
            , pgmonitor_bgw_role);

    initStringInfo(&buf);

    /*
     * Main loop: do this until the SIGTERM handler tells us to terminate
     */
    while (!got_sigterm) {
        BackgroundWorker        worker;
        BackgroundWorkerHandle  *handle;
        BgwHandleStatus         status;
        char                    *rawstring;
        int                     dbcounter;
        int                     rc;
        int                     full_string_length;
        List                    *elemlist;
        ListCell                *l;
        pid_t                   pid;

        /* Using Latch loop method suggested in latch.h
         * Uses timeout flag in WaitLatch() further below instead of sleep to allow clean shutdown */
        ResetLatch(&MyProc->procLatch);

        CHECK_FOR_INTERRUPTS();

        /* In case of a SIGHUP, just reload the configuration. */
        if (got_sighup) {
            got_sighup = false;
            ProcessConfigFile(PGC_SIGHUP);
        }
        elog(DEBUG1, "pgmonitor_bgw: After sighup check (got_sighup: %d)", got_sighup);

        /* In case of a SIGTERM in middle of loop, stop all further processing and return from BGW function to allow it to exit cleanly. */
        if (got_sigterm) {
            elog(LOG, "pgmonitor master BGW received SIGTERM. Shutting down. (got_sigterm: %d)", got_sigterm);
            return;
        }

        // Use method of shared_preload_libraries to split the pgmonitor_bgw_dbname string found in src/backend/utils/init/miscinit.c 
        // Need a modifiable copy of string 
        if (pgmonitor_bgw_dbname != NULL) {
            rawstring = pstrdup(pgmonitor_bgw_dbname);
            // Parse string into list of identifiers 
            if (!(*split_function_ptr)(rawstring, ',', &elemlist)) {
                // syntax error in list 
                pfree(rawstring);
                list_free(elemlist);
                ereport(LOG,
                        (errcode(ERRCODE_SYNTAX_ERROR),
                         errmsg("invalid list syntax in parameter \"pgmonitor_bgw.dbname\" in postgresql.conf")));
                return;
            }
            
            dbcounter = 0;
            foreach(l, elemlist) {

                char *dbname = (char *) lfirst(l);
                
                elog(DEBUG1, "pgmonitor_bgw: Dynamic bgw launch begun for %s (%d)", dbname, dbcounter);
                worker.bgw_flags = BGWORKER_SHMEM_ACCESS |
                    BGWORKER_BACKEND_DATABASE_CONNECTION;
                worker.bgw_start_time = BgWorkerStart_RecoveryFinished;
                worker.bgw_restart_time = BGW_NEVER_RESTART;
                sprintf(worker.bgw_library_name, "pgmonitor_bgw");
                sprintf(worker.bgw_function_name, "pgmonitor_bgw_run_maint");
                full_string_length = snprintf(worker.bgw_name, sizeof(worker.bgw_name),
                              "pgmonitor dynamic background worker (dbname=%s)", dbname);
                if (full_string_length >= sizeof(worker.bgw_name)) {
                    /* dbname was truncated, add an ellipsis to denote it */
                    const char truncated_mark[] = "...)";
                    memcpy(worker.bgw_name + sizeof(worker.bgw_name) - sizeof(truncated_mark),
                           truncated_mark, sizeof(truncated_mark));
                }
                worker.bgw_main_arg = Int32GetDatum(dbcounter);
                worker.bgw_notify_pid = MyProcPid;

                dbcounter++;

                elog(DEBUG1, "pgmonitor_bgw: Registering dynamic background worker...");
                if (!RegisterDynamicBackgroundWorker(&worker, &handle)) {
                    elog(ERROR, "Unable to register dynamic background worker for pgmonitor. Consider increasing max_worker_processes if you see this frequently. Main background worker process will try restarting in 10 minutes.");
                }

                elog(DEBUG1, "pgmonitor_bgw: Waiting for BGW startup...");
                status = WaitForBackgroundWorkerStartup(handle, &pid);
                elog(DEBUG1, "pgmonitor_bgw: BGW startup status: %d", status);

                if (status == BGWH_STOPPED) {
                    ereport(ERROR,
                            (errcode(ERRCODE_INSUFFICIENT_RESOURCES),
                             errmsg("Could not start dynamic pgmonitor background process"),
                           errhint("More details may be available in the server log.")));
                }

                if (status == BGWH_POSTMASTER_DIED) {
                    ereport(ERROR,
                            (errcode(ERRCODE_INSUFFICIENT_RESOURCES),
                          errmsg("Cannot start dynamic pgmonitor background processes without postmaster"),
                             errhint("Kill all remaining database processes and restart the database.")));
                }
                Assert(status == BGWH_STARTED);

                // Shutdown wait function introduced in 9.5. The latch problems this wait fixes are only encountered in 
                // 9.6 and later.
                elog(DEBUG1, "pgmonitor_bgw: Waiting for BGW shutdown...");
                status = WaitForBackgroundWorkerShutdown(handle);
                elog(DEBUG1, "pgmonitor_bgw: BGW shutdown status: %d", status);
                Assert(status == BGWH_STOPPED);
            }

            pfree(rawstring);
            list_free(elemlist);
        } else { // pgmonitor_bgw_dbname if null
            elog(DEBUG1, "pgmonitor_bgw: pgmonitor_bgw.dbname GUC is NULL. Nothing to do in main loop.");
        }


        elog(DEBUG1, "pgmonitor_bgw: Latch status just before waitlatch call: %d", MyProc->procLatch.is_set);

        rc = WaitLatch(&MyProc->procLatch,
                       WL_LATCH_SET | WL_TIMEOUT | WL_POSTMASTER_DEATH,
                       pgmonitor_bgw_interval * 1000L,
                       PG_WAIT_EXTENSION);
        /* emergency bailout if postmaster has died */
        if (rc & WL_POSTMASTER_DEATH) {
            proc_exit(1);
        }

        elog(DEBUG1, "pgmonitor_bgw: Latch status after waitlatch call: %d", MyProc->procLatch.is_set);

    } // end sigterm while

} // end main

/*
 * Unable to pass the database name as a string argument (not sure why yet)
 * Instead, the GUC is parsed both in the main function and below and a counter integer 
 *  is passed to determine which database the BGW will run in.
 */
void pgmonitor_bgw_run_maint(Datum arg) {

    char                *dbname = "template1";
    char                *pgmonitor_schema;
    char                *rawstring;
    int                 db_main_counter = DatumGetInt32(arg);
    List                *elemlist;
    int                 ret;
    StringInfoData      buf;
    #if (PG_VERSION_NUM >= 140000)    
    SPIExecuteOptions   spi_exec_opts;
    Portal              portal = ActivePortal;
    bool                portal_created = false;
    #endif

    /* Establish signal handlers before unblocking signals. */
    pqsignal(SIGHUP, pgmonitor_bgw_sighup);
    pqsignal(SIGTERM, pgmonitor_bgw_sigterm);

    /* We're now ready to receive signals */
    BackgroundWorkerUnblockSignals();

    elog(DEBUG1, "pgmonitor_bgw: Before parsing dbname GUC in dynamic main func: %s", pgmonitor_bgw_dbname);
    rawstring = pstrdup(pgmonitor_bgw_dbname);
    elog(DEBUG1, "pgmonitor_bgw: GUC rawstring copy: %s", rawstring);
    // Parse string into list of identifiers 
    if (!(*split_function_ptr)(rawstring, ',', &elemlist)) {
        // syntax error in list 
        pfree(rawstring);
        list_free(elemlist);
        ereport(LOG,
                (errcode(ERRCODE_SYNTAX_ERROR),
                 errmsg("invalid list syntax in parameter \"pgmonitor_bgw.dbname\" in postgresql.conf")));
        return;
    }

    dbname = list_nth(elemlist, db_main_counter);
    elog(DEBUG1, "pgmonitor_bgw: Parsing dbname list: %s (%d)", dbname, db_main_counter);
    
    if (strcmp(dbname, "template1") == 0) {
        elog(DEBUG1, "pgmonitor_bgw: Default database name found in dbname local variable (\"template1\").");
    }

    elog(DEBUG1, "pgmonitor_bgw: Before bgw initialize connection for db %s", dbname);

    BackgroundWorkerInitializeConnection(dbname, pgmonitor_bgw_role, 0);
    
    elog(DEBUG1, "pgmonitor_bgw: After bgw initialize connection for db %s", dbname);

    initStringInfo(&buf);

    SetCurrentStatementStartTimestamp();

    #if (PG_VERSION_NUM >= 140000)    
    SPI_connect_ext(SPI_OPT_NONATOMIC);
    if (!PortalIsValid(portal)) {
        portal_created = true;
        portal = CreateNewPortal();
        portal->visible = false;
        portal->resowner = CurrentResourceOwner;
        ActivePortal = portal;
        PortalContext = portal->portalContext;
        
        StartTransactionCommand();
        EnsurePortalSnapshotExists();
    }
    #else
    StartTransactionCommand();
    SPI_connect();
    PushActiveSnapshot(GetTransactionSnapshot());
    #endif

    pgstat_report_appname("pgmonitor dynamic background worker");

    // First determine if pgmonitor is even installed in this database
    appendStringInfo(&buf, "SELECT extname FROM pg_catalog.pg_extension WHERE extname = 'pgmonitor'");
    pgstat_report_activity(STATE_RUNNING, buf.data);
    elog(DEBUG1, "pgmonitor_bgw: Checking if pgmonitor extension is installed in database: %s" , dbname);
    ret = SPI_execute(buf.data, true, 1);
    if (ret != SPI_OK_SELECT) {
        elog(FATAL, "Cannot determine if pgmonitor is installed in database %s: error code %d", dbname, ret);
    }
    if (SPI_processed <= 0) {
        elog(DEBUG1, "pgmonitor_bgw: pgmonitor not installed in database %s. Nothing to do so dynamic worker exiting gracefully.", dbname);
        // Nothing left to do. Return end the run of BGW function.
        SPI_finish();
        PopActiveSnapshot();
        CommitTransactionCommand();
        pgstat_report_activity(STATE_IDLE, NULL);

        pfree(rawstring);
        list_free(elemlist);

        return;
    }

    // If so then actually log that it's started for that database. 
    elog(LOG, "%s dynamic background worker initialized with role %s on database %s"
            , MyBgworkerEntry->bgw_name
            , pgmonitor_bgw_role
            , dbname);

    resetStringInfo(&buf);
    appendStringInfo(&buf, "SELECT n.nspname FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON e.extnamespace = n.oid WHERE extname = 'pgmonitor'");
    pgstat_report_activity(STATE_RUNNING, buf.data);
    ret = SPI_execute(buf.data, true, 1);


    if (ret != SPI_OK_SELECT) {
        elog(FATAL, "Cannot determine which schema pgmonitor has been installed to: error code %d", ret);
    }

    if (SPI_processed > 0) {
        bool isnull;

        pgmonitor_schema = DatumGetCString(SPI_getbinval(SPI_tuptable->vals[0]
                , SPI_tuptable->tupdesc
                , 1
                , &isnull));

        elog(DEBUG1, "pgmonitor_bgw: pgmonitor schema: %s.", pgmonitor_schema);

        if (isnull)
            elog(FATAL, "Query to determine pgmonitor schema returned NULL.");

    } else {
        elog(FATAL, "Query to determine pgmonitor schema returned zero rows.");
    }

    resetStringInfo(&buf);

    #if (PG_VERSION_NUM >= 140000)    
    appendStringInfo(&buf, "CALL \"%s\".refresh_metrics()", pgmonitor_schema);
    #else
    appendStringInfo(&buf, "SELECT \"%s\".refresh_metrics_legacy()", pgmonitor_schema);
    #endif

    pgstat_report_activity(STATE_RUNNING, buf.data);

    #if (PG_VERSION_NUM >= 140000)    
    // Call refresh_metrics procedure non-atomically
    memset(&spi_exec_opts, 0, sizeof(spi_exec_opts));
    spi_exec_opts.allow_nonatomic = true;
    ret = SPI_execute_extended(buf.data, &spi_exec_opts);

    if (ret != SPI_OK_UTILITY)
        elog(FATAL, "Cannot call pgmonitor refresh_metrics() procedure: error code %d", ret);

    elog(LOG, "%s: %s called by role %s on database %s"
            , MyBgworkerEntry->bgw_name
            , buf.data
            , pgmonitor_bgw_role
            , dbname);

    SPI_finish();

    if (portal_created) {
        if (ActiveSnapshotSet())
            PopActiveSnapshot();
        CommitTransactionCommand();
        PortalDrop(portal, false);
        ActivePortal = NULL;
        PortalContext = NULL;
    }
    #else
    // Call refresh_metrics_legacy function 
    ret = SPI_execute(buf.data, false, 0);

    if (ret != SPI_OK_SELECT)
        elog(FATAL, "Cannot call pgmonitor refresh_metrics_legacy() function: error code %d", ret);

    elog(LOG, "%s: %s called by role %s on database %s"
            , MyBgworkerEntry->bgw_name
            , buf.data
            , pgmonitor_bgw_role
            , dbname);

    SPI_finish();
    PopActiveSnapshot();
    CommitTransactionCommand();
    #endif 

    #if (PG_VERSION_NUM < 150000)
    ProcessCompletedNotifies();
    #endif
    pgstat_report_activity(STATE_IDLE, NULL);
    elog(DEBUG1, "pgmonitor_bgw: pgmonitor dynamic BGW shutting down gracefully for database %s.", dbname);
    
    pfree(rawstring);
    list_free(elemlist);

    return;
}

