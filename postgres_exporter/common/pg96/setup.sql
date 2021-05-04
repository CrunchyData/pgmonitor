-- PG9.6 pgMonitor Setup
--
-- Copyright 2017-2021 Crunchy Data Solutions, Inc. All Rights Reserved.
--

DO $$
BEGIN
    -- The pgmonitor role is required by the pgnodemx extension in PostgreSQL versions 9.5 and 9.6
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgmonitor') THEN
        CREATE ROLE pgmonitor;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN IN ROLE pgmonitor;
    END IF;
END
$$;
 
ALTER ROLE ccp_monitoring SET lock_timeout TO '2min';

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

DROP FUNCTION IF EXISTS monitor.pg_stat_activity();
CREATE OR REPLACE FUNCTION monitor.pg_stat_activity() RETURNS SETOF pg_catalog.pg_stat_activity
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO pg_catalog, pg_temp
AS $$
BEGIN 
    RETURN query(SELECT * FROM pg_catalog.pg_stat_activity); 
END
$$; 

REVOKE ALL ON FUNCTION monitor.pg_stat_activity() FROM PUBLIC;


DROP FUNCTION IF EXISTS monitor.streaming_replica_check();
CREATE OR REPLACE FUNCTION monitor.streaming_replica_check() RETURNS TABLE (replica_hostname text, replica_addr inet, replica_port int, byte_lag numeric)
    LANGUAGE SQL SECURITY DEFINER
    SET search_path TO pg_catalog, pg_temp
AS $$
    SELECT client_hostname as replica_hostname
        , client_addr as replica_addr
        , client_port as replica_port
            , pg_xlog_location_diff(pg_stat_replication.sent_location, pg_stat_replication.replay_location) AS byte_lag 
                FROM pg_catalog.pg_stat_replication;
$$;

REVOKE ALL ON FUNCTION monitor.streaming_replica_check() FROM PUBLIC;


-- Drop previously unused version of this function if it exists from older pgmonitor installs
DROP FUNCTION IF EXISTS monitor.pg_ls_wal_dir(text);

CREATE OR REPLACE FUNCTION monitor.pg_ls_waldir() RETURNS SETOF TEXT 
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO pg_catalog, pg_temp
as $$
BEGIN 
    IF current_setting('server_version_num')::int >= 100000 THEN
       RAISE EXCEPTION 'Use version of this function included with core in PG10+';
    ELSE
        RETURN query(SELECT pg_catalog.pg_ls_dir('pg_xlog')); 
    END IF;
END
$$;
REVOKE ALL ON FUNCTION monitor.pg_ls_waldir() FROM PUBLIC;


DROP TABLE IF EXISTS monitor.pgbackrest_info CASCADE;
CREATE TABLE IF NOT EXISTS monitor.pgbackrest_info (config_file text NOT NULL, data jsonb NOT NULL, gather_timestamp timestamptz DEFAULT now() NOT NULL);
-- Force more aggressive autovacuum to avoid table bloat over time
ALTER TABLE monitor.pgbackrest_info SET (autovacuum_analyze_scale_factor = 0, autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = 10, autovacuum_analyze_threshold = 10);

DROP FUNCTION IF EXISTS monitor.pgbackrest_info(); -- old version from 2.3
DROP FUNCTION IF EXISTS monitor.pgbackrest_info(int);
CREATE OR REPLACE FUNCTION monitor.pgbackrest_info(p_throttle_minutes int DEFAULT 10) RETURNS SETOF monitor.pgbackrest_info
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

v_gather_timestamp      timestamptz;
v_throttle              interval;
v_system_identifier     bigint;
 
BEGIN
-- Get pgBackRest info in JSON format

v_throttle := make_interval(mins := p_throttle_minutes);

SELECT COALESCE(max(gather_timestamp), '1970-01-01'::timestamptz) INTO v_gather_timestamp FROM monitor.pgbackrest_info;

IF pg_catalog.pg_is_in_recovery() = 'f' THEN
    IF ((CURRENT_TIMESTAMP - v_gather_timestamp) > v_throttle) THEN

        -- Ensure table is empty 
        DELETE FROM monitor.pgbackrest_info;

        SELECT system_identifier into v_system_identifier FROM pg_control_system();

        -- Copy data into the table directory from the pgBackRest into command
        EXECUTE format( $cmd$ COPY monitor.pgbackrest_info (config_file, data) FROM program '/usr/bin/pgbackrest-info.sh %s' WITH (format text,DELIMITER '|') $cmd$, v_system_identifier::text );

    END IF;
END IF;

RETURN QUERY SELECT * FROM monitor.pgbackrest_info;

IF NOT FOUND THEN
    RAISE EXCEPTION 'No backups being returned from pgbackrest info command';
END IF;

END 
$function$;


DROP FUNCTION IF EXISTS monitor.sequence_status();
CREATE FUNCTION monitor.sequence_status() RETURNS TABLE (sequence_name text, last_value bigint, slots numeric, used numeric, percent bigint, cycle boolean, numleft numeric, table_usage text)  
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

v_int_max       int8;
v_int2_max      int2 := 32767;
v_int4_max      int4 := 2147483647;
v_int8_max      int8 := 9223372036854775807;
v_row           record;
v_seq_locked    text;
v_sql           text;

BEGIN

/* 
 * Provide detailed status information of sequences in the current database
 */

FOR v_row IN 
     WITH default_value_sequences AS (
        -- Get sequences defined as default values with related table
        -- Note this subquery can be locked/hung by DDL that affects tables with sequences. 
        --  Use monitor.sequence_exhaustion() to actually monitor for sequences running out
        SELECT s.oid AS seqrelid, c.oid, t.typname
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_attrdef ad ON (ad.adrelid,ad.adnum) = (a.attrelid,a.attnum)
        JOIN pg_catalog.pg_type t ON a.atttypid = t.oid
        JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
        JOIN pg_catalog.pg_class s ON s.oid = regexp_replace(pg_get_expr(ad.adbin,ad.adrelid), $re$^nextval\('(.+?)'::regclass\)$$re$, $re$\1$re$)::regclass
        WHERE (pg_get_expr(ad.adbin,ad.adrelid)) ~ '^nextval\('
        AND t.typname IN ('int2', 'int4', 'int8')
    ), dep_sequences AS (
        -- Get sequences set as dependencies with related tables (identities)    
        SELECT s.oid AS seqrelid, c.oid, t.typname
        FROM pg_catalog.pg_class s 
        JOIN pg_catalog.pg_depend d ON s.oid = d.objid
        JOIN pg_catalog.pg_attribute a ON (d.refobjid,d.refobjsubid) = (a.attrelid,a.attnum)
        JOIN pg_catalog.pg_type t ON a.atttypid = t.oid
        JOIN pg_catalog.pg_class c ON d.refobjid = c.oid
        WHERE s.relkind = ('S')
        AND t.typname IN ('int2', 'int4', 'int8')
        UNION
        SELECT seqrelid, oid, typname FROM default_value_sequences
    )
    -- Get any remaining sequences
    SELECT n.nspname AS schemaname
        , s.relname AS sequencename
        , s.oid AS sequenceoid
        , n.oid AS schemaoid
        , CASE WHEN typname IS NULL THEN 'int8' ELSE typname::text END AS typname
        , string_agg(ds.oid::regclass::text, ', ') AS table_usage
    FROM pg_catalog.pg_class s
    JOIN pg_catalog.pg_namespace n ON s.relnamespace = n.oid
    LEFT JOIN dep_sequences ds ON s.oid = ds.seqrelid
    WHERE s.relkind = 'S'
    AND n.nspname !~ 'pg_temp'
    GROUP BY 1,2,3,4,5
LOOP
    IF v_row.typname = 'int2' THEN
        v_int_max := v_int2_max;
    ELSIF v_row.typname = 'int4' THEN
        v_int_max := v_int4_max;
    ELSIF v_row.typname = 'int8' THEN
        v_int_max := v_int8_max;
    ELSE
        RAISE EXCEPTION 'Unexpected datatype encountered: %', v_row.typname;
    END IF;

    v_sql := format ('SELECT relation FROM pg_catalog.pg_locks WHERE relation = %L AND mode IN (''AccessExclusiveLock'', ''ExclusiveLock'')', v_row.sequenceoid);
    EXECUTE v_sql INTO v_seq_locked;
    IF v_seq_locked IS NOT NULL THEN
        RAISE DEBUG 'Sequence % (oid: %) locked and unable to obtain its status. Skipping.', v_row.sequencename, v_row.sequenceoid;
        CONTINUE;
    END IF;


    v_sql := format ('SELECT sequence_name
                , last_value
                , slots
                , used
                , ROUND(used/slots*100)::bigint AS percent
                , cycle
                , CASE WHEN slots < used THEN 0 ELSE slots - used END AS numleft
                , table_usage
            FROM (
                 SELECT ''%1$s.%2$s''::text AS sequence_name
                    , COALESCE(s.last_value,s.min_value) AS last_value
                    , s.is_cycled AS cycle
                    , CEIL((%3$L-min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS slots
                    , CEIL((COALESCE(s.last_value,s.min_value)-s.min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS used
                    , %4$L::text AS table_usage
                FROM %1$I.%2$I s
            ) x 
            ORDER BY ROUND(used/slots*100) DESC'
        , v_row.schemaname
        , v_row.sequencename
        , v_int_max
        , v_row.table_usage);

    RETURN QUERY EXECUTE v_sql;

END LOOP;

END
$function$;


DROP FUNCTION IF EXISTS monitor.sequence_exhaustion(int);
CREATE FUNCTION monitor.sequence_exhaustion(p_percent int DEFAULT 75, out count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

v_row           record;
v_seq_locked    text;
v_sql           text;

BEGIN

/* 
 * Returns count of sequences that have used up the % value given via the p_percent parameter (default 75%)
 */

FOR v_row IN 
    SELECT n.nspname AS schemaname
        , s.relname AS sequencename
        , s.oid AS sequenceoid
    FROM pg_catalog.pg_class s
    JOIN pg_catalog.pg_namespace n ON s.relnamespace = n.oid
    WHERE s.relkind = 'S'
    AND n.nspname !~ 'pg_temp'
LOOP

    v_sql := format ('SELECT relation FROM pg_catalog.pg_locks WHERE relation = %L AND mode IN (''AccessExclusiveLock'', ''ExclusiveLock'')', v_row.sequenceoid);
    EXECUTE v_sql INTO v_seq_locked;
    IF v_seq_locked IS NOT NULL THEN
        RAISE DEBUG 'Sequence % (oid: %) locked and unable to obtain its status. Skipping.', v_row.sequencename, v_row.sequenceoid;
        CONTINUE;
    END IF;

    v_sql := format ('SELECT count(*) 
            FROM (
                 SELECT CEIL((max_value-min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS slots
                    , CEIL((COALESCE(s.last_value,s.min_value)-s.min_value::NUMERIC+1)/s.increment_by::NUMERIC) AS used
                FROM %I.%I s
            ) x 
            WHERE (ROUND(used/slots*100)::int) > %L'
        , v_row.schemaname
        , v_row.sequencename
        , p_percent);

    EXECUTE v_sql INTO count;

END LOOP;


END
$function$;

/*
 * Tables and functions for monitoring changes to pg_settings system catalogs.
 * Can't just do a raw check for the hash value since Prometheus only records numeric values for alerts
 * Tables allow recording of existing settings so they can be referred back to to see what changed
 * If either checksum function returns 0, then NO settings have changed 
 * If either checksum function returns 1, then something has changed since last known valid state
 * For replicas, logging past settings is not possible to compare what may have changed
 * For replicas, by default, it is expected that its settings will match the primary
 * For replicas, if the pg_settings are necessarily different from the primary, a known good hash of that replica's
    settings can be sent as an argument to the relevant checksum function. Views are provided to easily obtain the hash values used by this monitoring tool. 
 * If any known hash parameters are passed to the checksum functions, note that it will override any past hash values stored in the log table when doing comparisons and completely re-evaluate the entire state. This is true even if done on a primary where the current state will then also be logged for comparison if it differs from the given hash.
 */

DROP TABLE IF EXISTS monitor.pg_settings_checksum;

CREATE TABLE monitor.pg_settings_checksum (
    settings_hash_generated text NOT NULL
    , settings_hash_known_provided text
    , settings_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );

COMMENT ON COLUMN monitor.pg_settings_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON monitor.pg_settings_checksum (created_at);

DROP FUNCTION IF EXISTS monitor.pg_settings_checksum(text);
CREATE FUNCTION monitor.pg_settings_checksum(p_known_settings_hash text DEFAULT NULL) 
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
FROM monitor.pg_settings_hash;

SELECT settings_hash_generated, valid
INTO v_settings_hash_old, v_valid
FROM monitor.pg_settings_checksum
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
            INSERT INTO monitor.pg_settings_checksum (
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
        INSERT INTO monitor.pg_settings_checksum (
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


DROP FUNCTION IF EXISTS monitor.pg_settings_checksum_set_valid();
/*
 * This function provides quick, clear interface for resetting the checksum monitor to treat the currently detected configuration as valid after alerting on a change. Note that configuration history will be cleared.
 */
CREATE FUNCTION monitor.pg_settings_checksum_set_valid() RETURNS smallint
    LANGUAGE sql 
AS $function$

TRUNCATE monitor.pg_settings_checksum;

SELECT monitor.pg_settings_checksum();

$function$;

DROP VIEW IF EXISTS monitor.pg_settings_hash;
CREATE VIEW monitor.pg_settings_hash AS
    WITH settings_ordered_list AS (
        SELECT name
            , COALESCE(setting, '<<NULL>>') AS setting
        FROM pg_catalog.pg_settings 
        ORDER BY name, setting)
    SELECT md5(string_agg(name||setting, ',')) AS md5_hash
        , string_agg(name||setting, ',') AS settings_string
    FROM settings_ordered_list;



GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
GRANT ALL ON ALL TABLES IN SCHEMA monitor TO ccp_monitoring;
