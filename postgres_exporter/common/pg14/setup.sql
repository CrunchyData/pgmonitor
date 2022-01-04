-- PG14 pgMonitor Setup
--
-- Copyright © 2017-2022 Crunchy Data Solutions, Inc. All Rights Reserved.
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN;
    END IF;

    -- The pgmonitor role is required by the pgnodemx extension in PostgreSQL versions 9.5 and 9.6
    -- and should be removed when upgrading to PostgreSQL 10 and above.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgmonitor') THEN
        DROP ROLE pgmonitor;
    END IF;
END
$$;
 
GRANT pg_monitor to ccp_monitoring;
GRANT pg_execute_server_program TO ccp_monitoring;

ALTER ROLE ccp_monitoring SET lock_timeout TO '2min';

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

DROP TABLE IF EXISTS monitor.pgbackrest_info CASCADE;
CREATE TABLE IF NOT EXISTS monitor.pgbackrest_info (config_file text NOT NULL, data jsonb NOT NULL, gather_timestamp timestamptz DEFAULT now() NOT NULL);
-- Force more aggressive autovacuum to avoid table bloat over time
ALTER TABLE monitor.pgbackrest_info SET (autovacuum_analyze_scale_factor = 0, autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = 10, autovacuum_analyze_threshold = 10);

DROP FUNCTION IF EXISTS monitor.pgbackrest_info(); -- old version from 2.3
DROP FUNCTION IF EXISTS monitor.pgbackrest_info(int);
CREATE OR REPLACE FUNCTION monitor.pgbackrest_info(p_throttle_minutes int DEFAULT 10) RETURNS SETOF monitor.pgbackrest_info
    LANGUAGE plpgsql
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
CREATE FUNCTION monitor.sequence_status() RETURNS TABLE (sequence_name text, last_value bigint, slots numeric, used numeric, percent int, cycle boolean, numleft numeric, table_usage text)  
    LANGUAGE sql SECURITY DEFINER STABLE
    SET search_path TO pg_catalog, pg_temp
AS $function$

/* 
 * Provide detailed status information of sequences in the current database
 */

WITH default_value_sequences AS (
    -- Get sequences defined as default values with related table
    -- Note this subquery can be locked/hung by DDL that affects tables with sequences. 
    --  Use monitor.sequence_exhaustion() to actually monitor for sequences running out
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


DROP FUNCTION IF EXISTS monitor.sequence_exhaustion(int);
CREATE FUNCTION monitor.sequence_exhaustion(p_percent integer DEFAULT 75, OUT count bigint)
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
 * Tables and functions for monitoring changes to pg_settings and pg_hba_file_rules system catalogs.
 * Can't just do a raw check for the hash value since Prometheus only records numeric values for alerts
 * Tables allow recording of existing settings so they can be referred back to to see what changed
 * If either checksum function returns 0, then NO settings have changed 
 * If either checksum function returns 1, then something has changed since last known valid state
 * For replicas, logging past settings is not possible to compare what may have changed
 * For replicas, by default, it is expected that its settings will match the primary
 * For replicas, if the pg_settings or pg_hba.conf are necessarily different from the primary, a known good hash of that replica's
    settings can be sent as an argument to the relevant checksum function. Views are provided to easily obtain the hash values used by this monitoring tool. 
 * If any known hash parameters are passed to the checksum functions, note that it will override any past hash values stored in the log table when doing comparisons and completely re-evaluate the entire state. This is true even if done on a primary where the current state will then also be logged for comparison if it differs from the given hash.
 */

DROP TABLE IF EXISTS monitor.pg_settings_checksum;
DROP TABLE IF EXISTS monitor.pg_hba_checksum;

CREATE TABLE monitor.pg_settings_checksum (
    settings_hash_generated text NOT NULL
    , settings_hash_known_provided text
    , settings_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );

COMMENT ON COLUMN monitor.pg_settings_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON monitor.pg_settings_checksum (created_at);

CREATE TABLE monitor.pg_hba_checksum (
    hba_hash_generated text NOT NULL
    , hba_hash_known_provided text
    , hba_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );

COMMENT ON COLUMN monitor.pg_hba_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON monitor.pg_hba_checksum (created_at);


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


DROP FUNCTION IF EXISTS monitor.pg_hba_checksum(text);
CREATE FUNCTION monitor.pg_hba_checksum(p_known_hba_hash text DEFAULT NULL) 
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
    FROM monitor.pg_hba_hash;

ELSE
    RAISE EXCEPTION 'pg_hba change monitoring unsupported in versions older than PostgreSQL 10';
END IF;

SELECT  hba_hash_generated, valid
INTO v_hba_hash_old, v_valid
FROM monitor.pg_hba_checksum
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
            INSERT INTO monitor.pg_hba_checksum (
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
        INSERT INTO monitor.pg_hba_checksum (
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


DROP FUNCTION IF EXISTS monitor.pg_hba_checksum_set_valid();
/*
 * This function provides quick, clear interface for resetting the checksum monitor to treat the currently detected configuration as valid after alerting on a change. Note that configuration history will be cleared.
 */
CREATE FUNCTION monitor.pg_hba_checksum_set_valid() RETURNS smallint
    LANGUAGE sql 
AS $function$

TRUNCATE monitor.pg_hba_checksum;

SELECT monitor.pg_hba_checksum();

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


DROP VIEW IF EXISTS monitor.pg_hba_hash;
CREATE VIEW monitor.pg_hba_hash AS
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



DROP TABLE IF EXISTS monitor.pg_stat_statements_reset_info;
-- Table to store last reset time for pg_stat_statements
CREATE TABLE monitor.pg_stat_statements_reset_info(
   reset_time timestamptz 
);

DROP FUNCTION IF EXISTS monitor.pg_stat_statements_reset_info(int);
-- Function to reset pg_stat_statements periodically
CREATE FUNCTION monitor.pg_stat_statements_reset_info(p_throttle_minutes integer DEFAULT 1440)
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

  SELECT COALESCE(max(reset_time), '1970-01-01'::timestamptz) INTO v_reset_timestamp FROM monitor.pg_stat_statements_reset_info;

  IF ((CURRENT_TIMESTAMP - v_reset_timestamp) > v_throttle) THEN
      -- Ensure table is empty 
      DELETE FROM monitor.pg_stat_statements_reset_info;
      PERFORM pg_stat_statements_reset();
      INSERT INTO monitor.pg_stat_statements_reset_info(reset_time) values (now());
  END IF;

  RETURN (SELECT extract(epoch from reset_time) FROM monitor.pg_stat_statements_reset_info);

EXCEPTION 
   WHEN others then 
       RETURN 0;
END 
$function$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
GRANT ALL ON ALL TABLES IN SCHEMA monitor TO ccp_monitoring;
