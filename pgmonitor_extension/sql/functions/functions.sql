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
 * Function interface to the pg_stat_statements contrib view to allow multi-version PG support
 *  Only columns that are used by pgMonitor metrics are returned
 */
CREATE FUNCTION @extschema@.pg_stat_statements_func() RETURNS TABLE
(
    "role" name
    , dbname name
    , queryid bigint
    , query text
    , calls bigint
    , total_exec_time double precision
    , max_exec_time double precision
    , mean_exec_time double precision
    , rows bigint
    , wal_records bigint
    , wal_fpi bigint
    , wal_bytes numeric
)
    LANGUAGE plpgsql
AS $function$
DECLARE
BEGIN

IF current_setting('server_version_num')::int >= 130000 THEN
    RETURN QUERY SELECT
        pg_get_userbyid(s.userid) AS role
        , d.datname AS dbname
        , s.queryid
        , btrim(replace(left(s.query, 40), '\n', '')) AS query
        , s.calls
        , s.total_exec_time
        , s.max_exec_time
        , s.mean_exec_time
        , s.rows
        , s.wal_records
        , s.wal_fpi
        , s.wal_bytes
      FROM public.pg_stat_statements s
      JOIN pg_catalog.pg_database d ON d.oid = s.dbid;
ELSE
    RETURN QUERY SELECT
        pg_get_userbyid(s.userid) AS role
        , d.datname AS dbname
        , s.queryid
        , btrim(replace(left(s.query, 40), '\n', '')) AS query
        , s.calls
        , s.total_exec_time
        , s.max_exec_time
        , s.mean_exec_time
        , s.rows
        , 0 AS wal_records
        , 0 AS wal_fpi
        , 0 AS wal_bytes
      FROM public.pg_stat_statements s
      JOIN pg_catalog.pg_database d ON d.oid = s.dbid;
END IF;

END 
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
-- The run_interval stored in metric_views for "ccp_pg_stat_statements_reset" is
--   what is used to determine how often this function resets the stats
CREATE FUNCTION @extschema@.pg_stat_statements_reset_info()
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

  v_reset_timestamp      timestamptz;
  v_reset_interval       interval;
  v_sql                  text;
  v_stat_schema          name;
 
BEGIN
-- ******** NOTE ********
-- This function must be owned by a superuser to work

  SELECT n.nspname INTO v_stat_schema
  FROM pg_catalog.pg_extension e
  JOIN pg_catalog.pg_namespace n ON e.extnamespace = n.oid
  WHERE e.extname = 'pg_stat_statements';

  IF v_stat_schema IS NULL THEN
    RAISE EXCEPTION 'Unable to find pg_stat_statements extension installed on this database';
  END IF;

  SELECT run_interval INTO v_reset_interval
  FROM @extschema@.metric_views
  WHERE view_schema = '@extschema@'
  AND view_name = 'ccp_pg_stat_statements_reset';

  SELECT COALESCE(max(reset_time), '1970-01-01'::timestamptz) INTO v_reset_timestamp FROM @extschema@.pg_stat_statements_reset_info;

  IF ((CURRENT_TIMESTAMP - v_reset_timestamp) > v_reset_interval) THEN
      -- Ensure table is empty 
      DELETE FROM @extschema@.pg_stat_statements_reset_info;
      v_sql := format('SELECT %I.pg_stat_statements_reset()', v_stat_schema);
      EXECUTE v_sql;
      INSERT INTO @extschema@.pg_stat_statements_reset_info(reset_time) values (CURRENT_TIMESTAMP);
  END IF;

  RETURN (SELECT extract(epoch from reset_time) FROM @extschema@.pg_stat_statements_reset_info);

END 
$function$;


-- Function to fetch pgbackrest stats
-- TODO See if the shell script can be further pulled into this function more and maybe get rid of it

CREATE FUNCTION @extschema@.pgbackrest_info()
    RETURNS SETOF @extschema@.pgbackrest_info
    LANGUAGE plpgsql
    SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE

v_gather_timestamp      timestamptz;
v_system_identifier     bigint;
 
BEGIN
-- Get pgBackRest info in JSON format

IF pg_catalog.pg_is_in_recovery() = 'f' THEN

    -- Ensure table is empty 
    DELETE FROM @extschema@.pgbackrest_info;

    SELECT system_identifier into v_system_identifier FROM pg_control_system();

    -- Copy data into the table directory from the pgBackRest into command
    EXECUTE format( $cmd$ COPY @extschema@.pgbackrest_info (config_file, data) FROM program '/usr/bin/pgbackrest-info.sh %s' WITH (format text,DELIMITER '|') $cmd$, v_system_identifier::text );

END IF;

RETURN QUERY SELECT * FROM @extschema@.pgbackrest_info;

IF NOT FOUND THEN
    RAISE EXCEPTION 'No backups being returned from pgbackrest info command';
END IF;

END 
$function$;


CREATE FUNCTION @extschema@.refresh_metrics_legacy (p_object_schema text DEFAULT 'monitor', p_object_name text DEFAULT NULL)
    RETURNS void
    LANGUAGE plpgsql
    AS $function$
DECLARE

v_loop_sql                      text;
v_refresh_statement     text;
v_refresh_sql                   text;
v_row                           record;

BEGIN
/* 
 * Function version of refresh_metrics() procedure for PG versions less than 14 that cannot be called via BGW 
 */

-- TODO Add advisory lock to avoid stacking concurrent runs. Throw a warning in logs that if it's happening repeatedly, adjust the BGW interval
-- TODO Record the runtime of each objects refresh time. Note that for <=PG13 that runtime is cumulative time for ALL metrics since it's one huge transaction

IF pg_catalog.pg_is_in_recovery() = TRUE THEN
    RAISE DEBUG 'Database instance in recovery mode. Exiting without view refresh';
    RETURN;
END IF;

v_loop_sql := format('SELECT view_schema, view_name, concurrent_refresh
                        FROM @extschema@.metric_views
                        WHERE active
                        AND materialized_view
                        AND ( last_run IS NULL OR (CURRENT_TIMESTAMP - last_run) > run_interval )');

IF p_object_name IS NOT NULL THEN
    v_loop_sql := format('%s AND view_schema = %L AND view_name = %L', v_loop_sql, p_object_schema, p_object_name);
END IF;

FOR v_row IN EXECUTE v_loop_sql LOOP

    v_refresh_sql := 'REFRESH MATERIALIZED VIEW ';
    IF v_row.concurrent_refresh THEN
        v_refresh_sql := v_refresh_sql || 'CONCURRENTLY ';
    END IF;
    v_refresh_sql := format('%s %I.%I', v_refresh_sql, v_row.view_schema, v_row.view_name);
    RAISE DEBUG 'pgmonitor view refresh: %', v_refresh_sql;
    EXECUTE v_refresh_sql;

    UPDATE @extschema@.metric_views
    SET last_run = CURRENT_TIMESTAMP
    WHERE view_schema = v_row.view_schema
    AND view_name = v_row.view_name;

END LOOP;

v_loop_sql := format('SELECT table_schema, table_name, refresh_statement
    FROM @extschema@.metric_tables
    WHERE active
    AND ( last_run IS NULL OR (CURRENT_TIMESTAMP - last_run) > run_interval )');

IF p_object_name IS NOT NULL THEN
    v_loop_sql := format('%s AND table_schema = %L AND table_name = %L', v_loop_sql, p_object_schema, p_object_name);
END IF;

FOR v_row IN EXECUTE v_loop_sql LOOP
    RAISE DEBUG 'pgmonitor table refresh: %', v_row.refresh_statement;
    EXECUTE format(v_row.refresh_statement);

    UPDATE @extschema@.metric_tables
    SET last_run = CURRENT_TIMESTAMP
    WHERE table_schema = v_row.table_schema
    AND table_name = v_row.table_name;

END LOOP;

RETURN;
END
$function$;

