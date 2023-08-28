-- TODO Create sub-extension for bloat support
    -- dependency on pgmonitor extension
    -- require that schema install path must match. Do a check in "first" sql file that checks to make sure @extschema@ matches pgmonitor's schema


/**** metric views ****/
CREATE VIEW @extschema@.ccp_is_in_recovery AS
    SELECT CASE WHEN pg_is_in_recovery = true THEN 1 ELSE 2 END AS status from pg_is_in_recovery();
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_is_in_recovery'
    , false    
    , 'global');


CREATE VIEW @extschema@.ccp_postgresql_version AS
    SELECT current_setting('server_version_num')::int AS current;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_postgresql_version'
    , false    
    , 'global');


CREATE VIEW @extschema@.ccp_postmaster_runtime AS
    SELECT extract('epoch' from pg_postmaster_start_time) AS start_time_seconds
    FROM pg_catalog.pg_postmaster_start_time();
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_postmaster_runtime'
    , false    
    , 'global');

-- Did not make as a matview since this is a critical metric to always be sure is current
CREATE VIEW @extschema@.ccp_transaction_wraparound AS
    WITH max_age AS (
        SELECT 2000000000 as max_old_xid
        , setting AS autovacuum_freeze_max_age 
        FROM pg_catalog.pg_settings 
        WHERE name = 'autovacuum_freeze_max_age')
    , per_database_stats AS ( 
        SELECT datname
        , m.max_old_xid::int
        , m.autovacuum_freeze_max_age::int
        , age(d.datfrozenxid) AS oldest_current_xid 
        FROM pg_catalog.pg_database d 
        JOIN max_age m ON (true) 
        WHERE d.datallowconn)
    SELECT max(oldest_current_xid) AS oldest_current_xid
    , max(ROUND(100*(oldest_current_xid/max_old_xid::float))) AS percent_towards_wraparound
    , max(ROUND(100*(oldest_current_xid/autovacuum_freeze_max_age::float))) AS percent_towards_emergency_autovac
    FROM per_database_stats;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_transaction_wraparound'
    , false    
    , 'global');
 

-- Did not make as a matview since this is a critical metric to always be sure is current
CREATE VIEW @extschema@.ccp_archive_command_status AS
    SELECT CASE 
        WHEN EXTRACT(epoch from (last_failed_time - last_archived_time)) IS NULL THEN 0
        WHEN EXTRACT(epoch from (last_failed_time - last_archived_time)) < 0 THEN 0
        ELSE EXTRACT(epoch from (last_failed_time - last_archived_time)) 
        END AS seconds_since_last_fail
    , EXTRACT(epoch from (CURRENT_TIMESTAMP - last_archived_time)) AS seconds_since_last_archive
    , archived_count
    , failed_count
    FROM pg_catalog.pg_stat_archiver;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_archive_command_status'
    , false    
    , 'global');


CREATE VIEW @extschema@.ccp_postmaster_uptime AS
    SELECT extract(epoch from (clock_timestamp() - pg_postmaster_start_time() )) AS seconds;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_postmaster_uptime'
    , false    
    , 'global');


CREATE VIEW @extschema@.ccp_settings_pending_restart AS
    SELECT count(*) AS count FROM pg_catalog.pg_settings WHERE pending_restart = true;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_settings_pending_restart'
    , false    
    , 'global');

-- Must be able to get replica stats, so cannot be matview
CREATE VIEW @extschema@.ccp_replication_lag AS
    SELECT
       CASE
       WHEN (pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn()) OR (pg_is_in_recovery() = false) THEN 0
       ELSE EXTRACT (EPOCH FROM clock_timestamp() - pg_last_xact_replay_timestamp())::INTEGER
       END
    AS replay_time
    ,  CASE
       WHEN pg_is_in_recovery() = false THEN 0
       ELSE EXTRACT (EPOCH FROM clock_timestamp() - pg_last_xact_replay_timestamp())::INTEGER
       END
    AS received_time;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_replication_lag'
    , false    
    , 'global');


-- Must be able to get replica stats, so cannot be matview
CREATE VIEW @extschema@.ccp_connection_stats AS
    SELECT ((total - idle) - idle_in_txn) as active
        , total
        , idle
        , idle_in_txn
        , (SELECT COALESCE(EXTRACT(epoch FROM (MAX(clock_timestamp() - state_change))),0) FROM pg_catalog.pg_stat_activity WHERE state = 'idle in transaction') AS max_idle_in_txn_time
        , (SELECT COALESCE(EXTRACT(epoch FROM (MAX(clock_timestamp() - query_start))),0) FROM pg_catalog.pg_stat_activity WHERE backend_type = 'client backend' AND state <> 'idle' ) AS max_query_time
        , (SELECT COALESCE(EXTRACT(epoch FROM (MAX(clock_timestamp() - query_start))),0) FROM pg_catalog.pg_stat_activity WHERE backend_type = 'client backend' AND wait_event_type = 'Lock' ) AS max_blocked_query_time
        , max_connections
        FROM (
                SELECT COUNT(*) as total
                        , COALESCE(SUM(CASE WHEN state = 'idle' THEN 1 ELSE 0 END),0) AS idle
                        , COALESCE(SUM(CASE WHEN state = 'idle in transaction' THEN 1 ELSE 0 END),0) AS idle_in_txn FROM pg_catalog.pg_stat_activity) x
        JOIN (SELECT setting::float AS max_connections FROM pg_settings WHERE name = 'max_connections') xx ON (true);
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_connection_stats'
    , false    
    , 'global');



-- Must be able to get replica stats (cascading replicas), so cannot be matview
CREATE VIEW @extschema@.ccp_replication_lag_size AS
    SELECT client_addr AS replica
        , client_hostname AS replica_hostname
        , client_port AS replica_port
        , pg_wal_lsn_diff(sent_lsn, replay_lsn) AS bytes 
        FROM pg_catalog.pg_stat_replication;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_replication_lag_size'
    , false    
    , 'global');


-- Did not make as a matview since this is a critical metric to avoid disk fill
CREATE VIEW @extschema@.ccp_replication_slots AS
    SELECT slot_name, active::int, pg_wal_lsn_diff(CASE WHEN pg_is_in_recovery() THEN pg_last_wal_replay_lsn() ELSE pg_current_wal_insert_lsn() END, restart_lsn) AS retained_bytes FROM pg_catalog.pg_replication_slots;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_replication_slots'
    , false    
    , 'global');

-- Did not make as a matview since this is a critical metric to always be sure is current
CREATE VIEW @extschema@.ccp_data_checksum_failure AS
    SELECT datname AS dbname
    , checksum_failures AS count
    , coalesce(extract(epoch from (clock_timestamp() - checksum_last_failure)), 0) AS time_since_last_failure_seconds 
    FROM pg_catalog.pg_stat_database;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , scope )
VALUES (
   'ccp_data_checksum_failure'
    , false    
    , 'global');

-- TODO test this
-- Enabling this metric this view will reset the pg_stat_statements statistics based on 
--   the run_interval set in metric_views
CREATE VIEW @extschema@.ccp_pg_stat_statements_reset AS
    SELECT @extschema@.pg_stat_statements_reset_info() AS time;
INSERT INTO @extschema@.metric_views (
    view_name 
    , materialized_view
    , run_interval
    , scope
    , active )
VALUES (
    'ccp_pg_stat_statements_reset'
    , false
    , '1440 seconds'::interval
    , 'global'
    , false );
