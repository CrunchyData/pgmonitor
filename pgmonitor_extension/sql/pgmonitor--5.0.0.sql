CREATE TABLE IF NOT EXISTS @extschema@.metric_views (
    view_schema text NOT NULL DEFAULT '@extschema@'
    , view_name text NOT NULL
    , materialized_view boolean NOT NULL DEFAULT true
    , concurrent_refresh boolean NOT NULL DEFAULT true
    , run_interval interval NOT NULL DEFAULT '10 minutes'::interval
    , last_run timestamptz
    , active boolean NOT NULL DEFAULT true
    , scope text NOT NULL default 'global'
    , CONSTRAINT metric_views_pk PRIMARY KEY (view_schema, view_name)
    , CONSTRAINT metric_views_scope_ck CHECK (scope IN ('global', 'database'))
);
CREATE INDEX metric_views_active_matview ON @extschema@.metric_views (active, materialized_view);
SELECT pg_catalog.pg_extension_config_dump('metric_views', '');

/*
 * Tables and functions for monitoring changes to pg_settings and pg_hba_file_rules system catalogs.
 * Tables allow recording of existing settings so they can be referred back to to see what changed
 */
CREATE TABLE @extschema@.pg_settings_checksum (
    settings_hash_generated text NOT NULL
    , settings_hash_known_provided text
    , settings_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );
COMMENT ON COLUMN @extschema@.pg_settings_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON @extschema@.pg_settings_checksum (created_at);

CREATE TABLE @extschema@.pg_hba_checksum (
    hba_hash_generated text NOT NULL
    , hba_hash_known_provided text
    , hba_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );
COMMENT ON COLUMN @extschema@.pg_hba_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON @extschema@.pg_hba_checksum (created_at);


CREATE TABLE @extschema@.pg_stat_statements_reset_info(
   reset_time timestamptz 
);


--TODO create prometheus metrics table to match columns to Prometheus output formatting info. better table name?
-- Use jsonb to allow full flexiblity for whatever upstream may need to have set for metric output
/*
 CREATE TABLE @extschema@.prometheus_metric_details (
    view_schema text NOT NULL
    , view_name text NOT NULL
    , column_details jsonb NOT NULL
    , CONSTRAINT prometheus_metric_details_pk PRIMARY KEY (view_schema, view_name);

-- I know this isn't valid json. will look it up
INSERT INTO @extschema@.prometheus_metric_details (view_schema, view_name, column_details) 
VALUES ('monitor'
        , 'ccp_connection_stats'
        , '{ "active" => { "TYPE stuff", "HELP stuff" }
            , "total" =>  { "TYPE stuff", "HELP stuff" }
           }' );
 */
CREATE PROCEDURE @extschema@.refresh_metric_views (p_view_schema text DEFAULT 'monitor', p_view_name text DEFAULT NULL)
    LANGUAGE plpgsql
    AS $$
DECLARE

v_loop_sql           text;
v_refresh_sql        text;
v_recovery           boolean;
v_row                record;

BEGIN

SELECT pg_is_in_recovery() INTO v_recovery;
IF v_recovery THEN
    RAISE DEBUG 'Database instance in recovery mode. Exiting without view refresh';
    RETURN;
END IF;

v_loop_sql := format('SELECT view_schema, view_name, concurrent_refresh
                        FROM @extschema@.metric_views
                        WHERE active
                        AND materialized_view
                        AND ( last_run IS NULL OR (CURRENT_TIMESTAMP - last_run) > run_interval )');

IF p_view_name IS NOT NULL THEN
    v_loop_sql := format('%s AND view_schema = %L AND view_name = %L', v_loop_sql, p_view_schema, p_view_name);
END IF;

FOR v_row IN EXECUTE v_loop_sql LOOP

    v_refresh_sql := 'REFRESH MATERIALIZED VIEW ';
    IF v_row.concurrent_refresh THEN
        v_refresh_sql := v_refresh_sql || 'CONCURRENTLY ';
    END IF;
    v_refresh_sql := format('%s %I.%I', v_refresh_sql, v_row.view_schema, v_row.view_name);
    RAISE DEBUG 'pgmonitor view refresh: %s', v_refresh_sql;
    EXECUTE v_refresh_sql;

    UPDATE @extschema@.metric_views
    SET last_run = CURRENT_TIMESTAMP
    WHERE view_schema = v_row.view_schema
    AND view_name = v_row.view_name;

    COMMIT;

END LOOP;

END
$$;


-- TODO Create function & view for monitoring that materialized views have run successfully within their scheduled time


CREATE FUNCTION @extschema@.sequence_status() RETURNS TABLE (sequence_name text, last_value bigint, slots numeric, used numeric, percent int, cycle boolean, numleft numeric, table_usage text)  
    LANGUAGE sql SECURITY DEFINER STABLE
    SET search_path TO pg_catalog, pg_temp
AS $function$

/* 
 * Provide detailed status information of sequences in the current database
 */

WITH default_value_sequences AS (
    -- Get sequences defined as default values with related table
    -- Note this subquery can be locked/hung by DDL that affects tables with sequences. 
    --  Use @extschema@.sequence_exhaustion() to actually monitor for sequences running out
    SELECT s.seqrelid, c.oid 
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_attrdef ad on (ad.adrelid,ad.adnum) = (a.attrelid,a.attnum)
    JOIN pg_catalog.pg_class c on a.attrelid = c.oid
    JOIN pg_catalog.pg_sequence s ON s.seqrelid = regexp_replace(pg_get_expr(ad.adbin,ad.adrelid), $re$^nextval\('(.+?)'::regclass\)$$re$, $re$\1$re$)::regclass
    WHERE (pg_get_expr(ad.adbin,ad.adrelid)) ~ '^nextval\('
), dep_sequences AS (
    -- Get sequences set as dependencies with related tables (identities)    
    SELECT s.seqrelid, c.oid
    FROM pg_catalog.pg_sequence s 
    JOIN pg_catalog.pg_depend d ON s.seqrelid = d.objid
    JOIN pg_catalog.pg_class c ON d.refobjid = c.oid
    UNION
    SELECT seqrelid, oid FROM default_value_sequences
), all_sequences AS (
    -- Get any remaining sequences
    SELECT s.seqrelid AS sequence_oid, ds.oid AS table_oid
    FROM pg_catalog.pg_sequence s
    LEFT JOIN dep_sequences ds ON s.seqrelid = ds.seqrelid
)
SELECT sequence_name
    , last_value
    , slots
    , used
    , ROUND(used/slots*100)::int AS percent
    , cycle
    , CASE WHEN slots < used THEN 0 ELSE slots - used END AS numleft
    , table_usage
FROM (
     SELECT format('%I.%I',s.schemaname, s.sequencename)::text AS sequence_name
        , COALESCE(s.last_value,s.min_value) AS last_value
        , s.cycle
        , CEIL((s.max_value-min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS slots
        , CEIL((COALESCE(s.last_value,s.min_value)-s.min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS used
        , string_agg(a.table_oid::regclass::text, ', ') AS table_usage
    FROM pg_catalog.pg_sequences s
    JOIN all_sequences a ON (format('%I.%I', s.schemaname, s.sequencename))::regclass = a.sequence_oid
    GROUP BY 1,2,3,4,5
) x 
ORDER BY ROUND(used/slots*100) DESC

$function$;


CREATE FUNCTION @extschema@.sequence_exhaustion(p_percent integer DEFAULT 75, OUT count bigint)
    LANGUAGE sql SECURITY DEFINER STABLE
    SET search_path TO pg_catalog, pg_temp
AS $function$

/* 
 * Returns count of sequences that have used up the % value given via the p_percent parameter (default 75%)
 */

SELECT count(*) AS count
FROM (
     SELECT CEIL((s.max_value-min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS slots
        , CEIL((COALESCE(s.last_value,s.min_value)-s.min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS used
    FROM pg_catalog.pg_sequences s
) x 
WHERE (ROUND(used/slots*100)::int) > p_percent;

$function$;

/*
 * Can't just do a raw check for the hash value since Prometheus only records numeric values for alerts
 * If either checksum function returns 0, then NO settings have changed 
 * If either checksum function returns 1, then something has changed since last known valid state
 * For replicas, logging past settings is not possible to compare what may have changed
 * For replicas, by default, it is expected that its settings will match the primary
 * For replicas, if the pg_settings or pg_hba.conf are necessarily different from the primary, a known good hash of that replica's
    settings can be sent as an argument to the relevant checksum function. Views are provided to easily obtain the hash values used by this monitoring tool. 
 * If any known hash parameters are passed to the checksum functions, note that it will override any past hash values stored in the log table when doing comparisons and completely re-evaluate the entire state. This is true even if done on a primary where the current state will then also be logged for comparison if it differs from the given hash.
 */


/**** These hash views are required to exist before the associated functions can be created  ****/
CREATE VIEW @extschema@.pg_settings_hash AS
    WITH settings_ordered_list AS (
        SELECT name
            , COALESCE(setting, '<<NULL>>') AS setting
        FROM pg_catalog.pg_settings 
        ORDER BY name, setting)
    SELECT md5(string_agg(name||setting, ',')) AS md5_hash
        , string_agg(name||setting, ',') AS settings_string
    FROM settings_ordered_list;


CREATE VIEW @extschema@.pg_hba_hash AS
    -- Order by line number so it's caught if no content is changed but the order of entries is changed
    WITH hba_ordered_list AS (
        SELECT COALESCE(type, '<<NULL>>') AS type
            , array_to_string(COALESCE(database, ARRAY['<<NULL>>']), ',') AS database
            , array_to_string(COALESCE(user_name, ARRAY['<<NULL>>']), ',') AS user_name
            , COALESCE(address, '<<NULL>>') AS address
            , COALESCE(netmask, '<<NULL>>') AS netmask
            , COALESCE(auth_method, '<<NULL>>') AS auth_method
            , array_to_string(COALESCE(options, ARRAY['<<NULL>>']), ',') AS options
        FROM pg_catalog.pg_hba_file_rules
        ORDER BY line_number)
    SELECT md5(string_agg(type||database||user_name||address||netmask||auth_method||options, ',')) AS md5_hash
        , string_agg(type||database||user_name||address||netmask||auth_method||options, ',') AS hba_string
    FROM hba_ordered_list;


CREATE FUNCTION @extschema@.pg_settings_checksum(p_known_settings_hash text DEFAULT NULL) 
    RETURNS smallint
    LANGUAGE plpgsql SECURITY DEFINER 
    SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

v_is_in_recovery        boolean;
v_settings_hash         text;
v_settings_hash_old     text;
v_settings_match        smallint := 0;
v_settings_string       text;
v_settings_string_old   text;
v_valid                 smallint;

BEGIN

SELECT pg_is_in_recovery() INTO v_is_in_recovery;

SELECT md5_hash
    , settings_string
INTO v_settings_hash
    , v_settings_string
FROM @extschema@.pg_settings_hash;

SELECT settings_hash_generated, valid
INTO v_settings_hash_old, v_valid
FROM @extschema@.pg_settings_checksum
ORDER BY created_at DESC LIMIT 1;

IF p_known_settings_hash IS NOT NULL THEN
    v_settings_hash_old := p_known_settings_hash;
    -- Do not base validity on the stored value if manual hash is given. 
    v_valid := 0;
END IF;

IF (v_settings_hash_old IS NOT NULL) THEN

    IF (v_settings_hash != v_settings_hash_old) THEN

        v_valid := 1;

        IF v_is_in_recovery = false THEN 
            INSERT INTO @extschema@.pg_settings_checksum (
                    settings_hash_generated
                    , settings_hash_known_provided
                    , settings_string
                    , valid)
            VALUES (
                    v_settings_hash
                    , p_known_settings_hash
                    , v_settings_string
                    , v_valid);
        END IF;
    END IF;

ELSE

    v_valid := 0;
    IF v_is_in_recovery = false THEN
        INSERT INTO @extschema@.pg_settings_checksum (
                settings_hash_generated
                , settings_hash_known_provided
                , settings_string
                , valid)
        VALUES (v_settings_hash
                , p_known_settings_hash
                , v_settings_string
                , v_valid);
    END IF;

END IF; 

RETURN v_valid;

END
$function$;


--TODO make sure this is only usable on PG12+
CREATE FUNCTION @extschema@.pg_hba_checksum(p_known_hba_hash text DEFAULT NULL) 
    RETURNS smallint
    LANGUAGE plpgsql SECURITY DEFINER 
    SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

v_hba_hash              text;
v_hba_hash_old          text;
v_hba_match             smallint := 0;
v_hba_string            text;
v_hba_string_old        text;
v_is_in_recovery        boolean;
v_valid                 smallint;

BEGIN

SELECT pg_is_in_recovery() INTO v_is_in_recovery;

IF current_setting('server_version_num')::int >= 100000 THEN

    SELECT md5_hash
        , hba_string
    INTO v_hba_hash
        , v_hba_string
    FROM @extschema@.pg_hba_hash;

ELSE
    RAISE EXCEPTION 'pg_hba change monitoring unsupported in versions older than PostgreSQL 10';
END IF;

SELECT  hba_hash_generated, valid
INTO v_hba_hash_old, v_valid
FROM @extschema@.pg_hba_checksum
ORDER BY created_at DESC LIMIT 1;

IF p_known_hba_hash IS NOT NULL THEN
    v_hba_hash_old := p_known_hba_hash;
    -- Do not base validity on the stored value if manual hash is given. 
    v_valid := 0;
END IF;

IF (v_hba_hash_old IS NOT NULL) THEN

    IF (v_hba_hash != v_hba_hash_old) THEN

        v_valid := 1;

        IF v_is_in_recovery = false THEN 
            INSERT INTO @extschema@.pg_hba_checksum (
                    hba_hash_generated
                    , hba_hash_known_provided
                    , hba_string
                    , valid)
            VALUES (
                    v_hba_hash
                    , p_known_hba_hash
                    , v_hba_string
                    , v_valid);
        END IF;
    END IF;

ELSE

    v_valid := 0;
    IF v_is_in_recovery = false THEN
        INSERT INTO @extschema@.pg_hba_checksum (
                hba_hash_generated
                , hba_hash_known_provided
                , hba_string
                , valid)
        VALUES (v_hba_hash
                , p_known_hba_hash
                , v_hba_string
                , v_valid);
    END IF;

END IF; 

RETURN v_valid;

END
$function$;


/*
 * This function provides quick, clear interface for resetting the checksum monitor to treat the currently detected configuration as valid after alerting on a change. Note that configuration history will be cleared.
 */
CREATE FUNCTION @extschema@.pg_settings_checksum_set_valid() RETURNS smallint
    LANGUAGE sql 
AS $function$

TRUNCATE @extschema@.pg_settings_checksum;

SELECT @extschema@.pg_settings_checksum();

$function$;


/*
 * This function provides quick, clear interface for resetting the checksum monitor to treat the currently detected configuration as valid after alerting on a change. Note that configuration history will be cleared.
 */
CREATE FUNCTION @extschema@.pg_hba_checksum_set_valid() RETURNS smallint
    LANGUAGE sql 
AS $function$

TRUNCATE @extschema@.pg_hba_checksum;

SELECT @extschema@.pg_hba_checksum();

$function$;


-- Function to reset pg_stat_statements periodically
-- TODO have BGW also run this as part of the scheduled interval
CREATE FUNCTION @extschema@.pg_stat_statements_reset_info(p_throttle_minutes integer DEFAULT 1440)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

  v_reset_timestamp      timestamptz;
  v_throttle             interval;
 
BEGIN

  IF p_throttle_minutes < 0 THEN
      RETURN 0;
  END IF;

  v_throttle := make_interval(mins := p_throttle_minutes);

  SELECT COALESCE(max(reset_time), '1970-01-01'::timestamptz) INTO v_reset_timestamp FROM @extschema@.pg_stat_statements_reset_info;

  IF ((CURRENT_TIMESTAMP - v_reset_timestamp) > v_throttle) THEN
      -- Ensure table is empty 
      DELETE FROM @extschema@.pg_stat_statements_reset_info;
      PERFORM pg_stat_statements_reset();
      INSERT INTO @extschema@.pg_stat_statements_reset_info(reset_time) values (now());
  END IF;

  RETURN (SELECT extract(epoch from reset_time) FROM @extschema@.pg_stat_statements_reset_info);

EXCEPTION 
   WHEN others then 
       RETURN 0;
END 
$function$;


-- TODO Create sub-extension to add support for nodemx queries (require pgmonitor extension)
-- TODO Create sub-extension to add support for pgbouncer queries disabled by default (dependent on pgbouncer_fdw 1.0.0 and pgmonitor extension)
-- TODO Add pg_stat_statements disabled by defualt. use WITH NO DATA option

CREATE MATERIALIZED VIEW @extschema@.ccp_stat_user_tables AS 
    SELECT current_database() as dbname
    , schemaname
    , relname
    , seq_scan
    , seq_tup_read
    , idx_scan
    , idx_tup_fetch
    , n_tup_ins
    , n_tup_upd
    , n_tup_del
    , n_tup_hot_upd
    , n_live_tup
    , n_dead_tup
    , vacuum_count
    , autovacuum_count
    , analyze_count
    , autoanalyze_count 
    FROM pg_catalog.pg_stat_user_tables;
CREATE UNIQUE INDEX ccp_user_tables_db_schema_relname_idx ON @extschema@.ccp_stat_user_tables (dbname, schemaname, relname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_stat_user_tables'
    , '5 minutes'::interval
    , 'database');


CREATE MATERIALIZED VIEW @extschema@.ccp_table_size AS
    SELECT current_database() as dbname
    , n.nspname as schemaname
    , c.relname
    , pg_total_relation_size(c.oid) as size_bytes 
    FROM pg_catalog.pg_class c 
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid 
    WHERE NOT pg_is_other_temp_schema(n.oid) 
    AND relkind IN ('r', 'm', 'f');
CREATE UNIQUE INDEX ccp_table_size_idx ON @extschema@.ccp_table_size (dbname, schemaname, relname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_table_size'
    , '5 minutes'::interval
    , 'database');


CREATE MATERIALIZED VIEW @extschema@.ccp_database_size AS
    SELECT datname as dbname
    , pg_database_size(datname) as bytes 
    FROM pg_catalog.pg_database 
    WHERE datistemplate = false;
CREATE UNIQUE INDEX ccp_database_size_idx ON @extschema@.ccp_database_size (dbname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_database_size'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_locks AS 
    SELECT pg_database.datname as dbname
    , tmp.mode
    , COALESCE(count,0) as count
    FROM
    (
      VALUES ('accesssharelock'),
             ('rowsharelock'),
             ('rowexclusivelock'),
             ('shareupdateexclusivelock'),
             ('sharelock'),
             ('sharerowexclusivelock'),
             ('exclusivelock'),
             ('accessexclusivelock')
    ) AS tmp(mode) CROSS JOIN pg_catalog.pg_database
    LEFT JOIN
        (SELECT database, lower(mode) AS mode,count(*) AS count
        FROM pg_catalog.pg_locks WHERE database IS NOT NULL
        GROUP BY database, lower(mode)
    ) AS tmp2
    ON tmp.mode=tmp2.mode and pg_database.oid = tmp2.database;
CREATE UNIQUE INDEX ccp_locks_idx ON @extschema@.ccp_locks (dbname, mode);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_locks'
    , '1 minute'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_stat_bgwriter AS
    SELECT checkpoints_timed
    , checkpoints_req
    , checkpoint_write_time
    , checkpoint_sync_time
    , buffers_checkpoint
    , buffers_clean
    , maxwritten_clean
    , buffers_backend
    , buffers_backend_fsync
    , buffers_alloc
    , stats_reset 
    FROM pg_catalog.pg_stat_bgwriter;
/* According to docs, this table should only ever have 1 row */
CREATE UNIQUE INDEX ccp_stat_bgwriter_idx ON @extschema@.ccp_stat_bgwriter (stats_reset);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope 
    , concurrent_refresh )
VALUES (
   'ccp_stat_bgwriter'
    , '5 minutes'::interval
    , 'global'
    , false );


CREATE MATERIALIZED VIEW @extschema@.ccp_stat_database AS
    SELECT s.datname AS dbname
    , xact_commit
    , xact_rollback
    , blks_read
    , blks_hit
    , tup_returned
    , tup_fetched
    , tup_inserted
    , tup_updated
    , tup_deleted
    , conflicts
    , temp_files
    , temp_bytes
    , deadlocks
    FROM pg_catalog.pg_stat_database s 
    JOIN pg_catalog.pg_database d ON d.datname = s.datname
    WHERE d.datistemplate = false;
CREATE UNIQUE INDEX ccp_stat_database_idx ON @extschema@.ccp_stat_database (dbname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_stat_database'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_sequence_exhaustion AS
    SELECT count FROM @extschema@.sequence_exhaustion(75);
CREATE UNIQUE INDEX ccp_sequence_exhaustion_idx ON @extschema@.ccp_sequence_exhaustion (count);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_sequence_exhaustion'
    , '5 minutes'::interval
    , 'database');


CREATE MATERIALIZED VIEW @extschema@.ccp_pg_settings_checksum AS
    SELECT @extschema@.pg_settings_checksum() AS status;
CREATE UNIQUE INDEX ccp_pg_settings_checksum_idx ON @extschema@.ccp_pg_settings_checksum (status);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_pg_settings_checksum'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_pg_hba_checksum AS
    SELECT @extschema@.pg_hba_checksum() AS status;
CREATE UNIQUE INDEX ccp_pg_hba_checksum_idx ON @extschema@.ccp_pg_hba_checksum (status);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_pg_hba_checksum'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_wal_activity AS
    SELECT last_5_min_size_bytes,
      (SELECT COALESCE(sum(size),0) FROM pg_catalog.pg_ls_waldir()) AS total_size_bytes
      FROM (SELECT COALESCE(sum(size),0) AS last_5_min_size_bytes FROM pg_catalog.pg_ls_waldir() WHERE modification > CURRENT_TIMESTAMP - '5 minutes'::interval) x;
CREATE UNIQUE INDEX ccp_wal_activity_idx ON @extschema@.ccp_wal_activity (last_5_min_size_bytes, total_size_bytes);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_wal_activity'
    , '2 minutes'::interval
    , 'global');
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

