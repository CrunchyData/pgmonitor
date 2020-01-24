DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN;
    END IF;
END
$$;
 
GRANT pg_monitor to ccp_monitoring;

ALTER ROLE ccp_monitoring SET lock_timeout TO '2min';

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

DROP TABLE IF EXISTS monitor.pgbackrest_info CASCADE;
CREATE TABLE IF NOT EXISTS monitor.pgbackrest_info (config_file text NOT NULL, data jsonb NOT NULL, gather_timestamp timestamptz DEFAULT now() NOT NULL);
-- Force more aggressive autovacuum to avoid table bloat over time
ALTER TABLE monitor.pgbackrest_info SET (autovacuum_analyze_scale_factor = 0, autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = 10, autovacuum_analyze_threshold = 10);

DROP FUNCTION IF EXISTS monitor.pgbackrest_info(); -- old version from 2.3
DROP FUNCTION IF EXISTS monitor.pgbackrest_info(int);
CREATE OR REPLACE FUNCTION monitor.pgbackrest_info(p_throttle_minutes int DEFAULT 10) RETURNS SETOF monitor.pgbackrest_info
    LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE

v_gather_timestamp      timestamptz;
v_throttle              interval;
 
BEGIN
-- Get pgBackRest info in JSON format

v_throttle := make_interval(mins := p_throttle_minutes);

SELECT COALESCE(max(gather_timestamp), '1970-01-01'::timestamptz) INTO v_gather_timestamp FROM monitor.pgbackrest_info;

IF pg_catalog.pg_is_in_recovery() = 'f' THEN
    IF ((CURRENT_TIMESTAMP - v_gather_timestamp) > v_throttle) THEN

        -- Ensure table is empty 
        DELETE FROM monitor.pgbackrest_info;

        -- Copy data into the table directory from the pgBackRest into command
        COPY monitor.pgbackrest_info (config_file, data) FROM program '/usr/bin/pgbackrest-info.sh' WITH (format text,DELIMITER '|');

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
 * Table and functions for monitoring changes to pg_settings and pg_hba_file_rules system catalogs.
 * Can't just do a raw check for the hash value since Prometheus only records numeric values for alerts
 * Table allows recording of existing settings so it can be referred back to to see what changed
 * If function returns 0, then NO settings have changed for either pg_settings or hba since last known valid state 
 * If function returns 1, then just pg_settings have changed since last known valid state
 * If function returns 2, then just hba has changed since last known valid state
 * If function returns 3, then both pg_settings and hba have changed since last known valid state
 * For replicas, logging past settings is not possible to compare what may have changed
 * For replicas, by default, it is expected that its settings will match the primary
 * For replicas, if the pg_settings or pg_hba.conf are necessarily different from the primary, a known good hash of that replica's
    settings can be sent as arguments to the settings_checksum() function. Views are provided to easily obtain hash values 
    that this monitoring metric expects to use.
 * If any known hash parameters are passed to the settings_checksum() function, note that it will override any past hash values for both
    pg_settings and hba stored in the log table when doing comparisons and completely re-evaluate the entire state. This is
    true even if done on a primary where the current state will then also be logged for comparison.
 */

DROP TABLE IF EXISTS monitor.settings_checksum;
DROP FUNCTION IF EXISTS monitor.settings_checksum(text, text);
DROP FUNCTION monitor.settings_checksum_set_valid();
DROP VIEW IF EXISTS monitor.pg_settings_hash;
DROP VIEW IF EXISTS monitor.pg_hba_hash;

CREATE TABLE monitor.settings_checksum (
    settings_hash_generated text NOT NULL
    , settings_hash_known_provided text
    , settings_string text NOT NULL
    , hba_hash_generated text NOT NULL
    , hba_hash_known_provided text
    , hba_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );

COMMENT ON COLUMN monitor.settings_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON monitor.settings_checksum (created_at);

CREATE FUNCTION monitor.settings_checksum(p_known_settings_hash text DEFAULT NULL, p_known_hba_hash text DEFAULT NULL) 
    RETURNS smallint
    LANGUAGE plpgsql SECURITY DEFINER 
AS $function$
DECLARE

v_hba_hash              text;
v_hba_hash_old          text;
v_hba_match             smallint := 0;
v_hba_string            text;
v_hba_string_old        text;
v_is_in_recovery        boolean;
v_match_total           smallint := 0;
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

IF current_setting('server_version_num')::int >= 100000 THEN

    SELECT md5_hash
        , hba_string
    INTO v_hba_hash
        , v_hba_string
    FROM monitor.pg_hba_hash;

ELSE
    v_hba_hash := 'unsupported in versions older than PostgreSQL 10';
    v_hba_string := 'unsupported in versions older than PostgreSQL 10';
END IF;

SELECT settings_hash_generated, hba_hash_generated, valid
INTO v_settings_hash_old, v_hba_hash_old, v_valid
FROM monitor.settings_checksum
ORDER BY created_at DESC LIMIT 1;

IF p_known_hba_hash IS NOT NULL THEN
    IF current_setting('server_version_num')::int >= 100000 THEN
        v_hba_hash_old := p_known_hba_hash;
    ELSE 
        RAISE EXCEPTION 'p_known_hba_hash parameter can only be used with PG10+';
    END IF;
END IF;

IF p_known_settings_hash IS NOT NULL THEN
    v_settings_hash_old := p_known_settings_hash;
END IF;

IF v_is_in_recovery THEN
    -- Do not base validity on the stored value on primary. 
    -- Allow it to be re-evaluated on the replica itself
    v_valid := 0;
END IF;

-- Check for NOT NULL in v_settings_hash_old since that will be set both when a manual known hash is given
--      or the last stored one from the log file is used. Otherwise, must insert new row in history table.
IF v_settings_hash_old IS NOT NULL THEN

    IF v_valid > 0 OR (v_settings_hash != v_settings_hash_old OR v_hba_hash != v_hba_hash_old) THEN
        
        IF v_settings_hash != v_settings_hash_old OR (v_valid = 1 AND p_known_settings_hash IS NULL) THEN
            v_settings_match := 1;
        END IF;
        
        IF v_hba_hash != v_hba_hash_old OR (v_valid = 2 AND p_known_hba_hash IS NULL )THEN
            v_hba_match := 2;
        END IF;

        IF (p_known_settings_hash IS NOT NULL OR p_known_hba_hash IS NOT NULL) THEN
            -- If known hash values are being provided, always re-evaluate state
            v_match_total := v_settings_match + v_hba_match;
        ELSIF v_valid = 3 THEN
            -- If previous state had both mismatched on the primary, and no known hashes are provided, preserve that state
            v_match_total = 3;
        ELSE
            -- Otherwise, ensure new state is set
            v_match_total := v_settings_match + v_hba_match;
        END IF;

        -- Only insert a new row if one of the hashes has changed since last time (and on primary)
        IF v_is_in_recovery = false AND (v_settings_hash != v_settings_hash_old OR v_hba_hash != v_hba_hash_old) THEN 
            INSERT INTO monitor.settings_checksum (
                    settings_hash_generated
                    , settings_hash_known_provided
                    , settings_string
                    , hba_hash_generated
                    , hba_hash_known_provided
                    , hba_string
                    , valid)
            VALUES (v_settings_hash
                    , p_known_settings_hash
                    , v_settings_string
                    , v_hba_hash
                    , p_known_hba_hash
                    , v_hba_string
                    , v_match_total);
        END IF;

    END IF; 

ELSE

    IF v_is_in_recovery = false THEN
        INSERT INTO monitor.settings_checksum (
                settings_hash_generated
                , settings_hash_known_provided
                , settings_string
                , hba_hash_generated
                , hba_hash_known_provided
                , hba_string
                , valid)
        VALUES (v_settings_hash
                , p_known_settings_hash
                , v_settings_string
                , v_hba_hash
                , p_known_hba_hash
                , v_hba_string
                , v_match_total);
    END IF;

END IF;

RETURN v_match_total;

END
$function$;


/*
 * This function provides quick, clear interface for resetting the checksum monitor to treat the currently detected configuration as valid  against the one stored in the history table after alerting on a change.
 */
CREATE FUNCTION monitor.settings_checksum_set_valid() RETURNS void
    LANGUAGE sql 
AS $function$

-- Should also handle edge case of there being multiple timestamps with same value
-- All should be updated to ensure consistency in a weird state
WITH max_time AS ( 
    SELECT max(created_at) as max_created FROM monitor.settings_checksum ) 
UPDATE monitor.settings_checksum 
SET valid = 0 
FROM max_time 
WHERE created_at = max_time.max_created;

$function$;


CREATE VIEW monitor.pg_settings_hash AS
    WITH settings_ordered_list AS (
        SELECT name
            , COALESCE(setting, '<<NULL>>') AS setting
        FROM pg_catalog.pg_settings 
        ORDER BY name, setting)
    SELECT md5(string_agg(name||setting, ',')) AS md5_hash
        , string_agg(name||setting, ',') AS settings_string
    FROM settings_ordered_list;


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


GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
GRANT ALL ON ALL TABLES IN SCHEMA monitor TO ccp_monitoring;
