-- #########################
-- Materialized View Objects
-- #########################

CREATE SCHEMA IF NOT EXISTS monitor;

-- Preserve existing data if users added more matviews or changed schedule. Allows setup call to be idempodent.
DO $pgmonitor$
DECLARE
v_exists    smallint;
BEGIN

    SELECT count(*) INTO v_exists FROM information_schema.tables WHERE table_schema = 'monitor' AND table_name = 'matview_metrics';
    IF v_exists > 0 THEN
        CREATE TEMPORARY TABLE matview_metrics_preserve_temp (LIKE monitor.matview_metrics);
        INSERT INTO matview_metrics_preserve_temp SELECT * FROM monitor.matview_metrics;
        DROP TABLE monitor.matview_metrics;
    END IF;

    CREATE TABLE IF NOT EXISTS monitor.matview_metrics (
        matview_schema text NOT NULL DEFAULT 'monitor'
        , matview_name text NOT NULL
        , concurrent_refresh boolean NOT NULL DEFAULT true
        , run_interval interval NOT NULL
        , last_run timestamptz
        , active boolean NOT NULL DEFAULT true
        , scope text NOT NULL default 'global'
        , CONSTRAINT matview_metrics_pk PRIMARY KEY (matview_schema, matview_name)
        , CONSTRAINT matview_metrics_scope_ck CHECK (scope IN ('global', 'database'))
    );

    IF v_exists > 0 THEN
        INSERT INTO monitor.matview_metrics SELECT * FROM matview_metrics_preserve_temp;
        DROP TABLE matview_metrics_preserve_temp;
    END IF;

END
$pgmonitor$;


DROP PROCEDURE IF EXISTS monitor.matview_refresh_metrics (text, text);
CREATE PROCEDURE monitor.matview_refresh_metrics (p_matview_schema text DEFAULT 'monitor', p_matview_name text DEFAULT NULL)
    LANGUAGE plpgsql
    AS $$
DECLARE

v_loop_sql           text;
v_refresh_sql        text;
v_row                record;

BEGIN

v_loop_sql := format('SELECT matview_schema, matview_name, concurrent_refresh, run_interval, last_run 
                        FROM monitor.matview_metrics
                        WHERE active');

IF p_matview_name IS NOT NULL THEN
    v_loop_sql := format('%s AND matview_schema = %L AND matview_name = %L', v_loop_sql, p_matview_schema, p_matview_name);
END IF;

FOR v_row IN EXECUTE v_loop_sql LOOP

    IF ((CURRENT_TIMESTAMP - v_row.last_run) > v_row.run_interval) OR (v_row.last_run IS NULL) THEN

        v_refresh_sql := 'REFRESH MATERIALIZED VIEW ';
        IF v_row.concurrent_refresh THEN
            v_refresh_sql := v_refresh_sql || 'CONCURRENTLY ';
        END IF;
        v_refresh_sql := format('%s %I.%I', v_refresh_sql, v_row.matview_schema, v_row.matview_name);
        RAISE DEBUG 'pgmonitor matview refresh: %s', v_refresh_sql;
        EXECUTE v_refresh_sql;

        UPDATE monitor.matview_metrics 
        SET last_run = CURRENT_TIMESTAMP 
        WHERE matview_schema = v_row.matview_schema
        AND matview_name = v_row.matview_name;

        COMMIT;

    END IF;
            

END LOOP;

END
$$;

DROP MATERIALIZED VIEW IF EXISTS monitor.ccp_stat_user_tables;
CREATE MATERIALIZED VIEW monitor.ccp_stat_user_tables
AS SELECT current_database() as dbname
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
CREATE UNIQUE INDEX ccp_user_tables_db_schema_relname_idx ON monitor.ccp_stat_user_tables (dbname, schemaname, relname);
ALTER MATERIALIZED VIEW monitor.ccp_stat_user_tables OWNER TO ccp_monitoring;


DROP MATERIALIZED VIEW IF EXISTS monitor.ccp_table_size;
CREATE MATERIALIZED VIEW monitor.ccp_table_size
AS SELECT current_database() as dbname
    , n.nspname as schemaname
    , c.relname
    , pg_total_relation_size(c.oid) as size_bytes 
    FROM pg_catalog.pg_class c 
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid 
    WHERE NOT pg_is_other_temp_schema(n.oid) 
    AND relkind IN ('r', 'm', 'f');
CREATE UNIQUE INDEX ccp_table_size_idx ON monitor.ccp_table_size (dbname, schemaname, relname);
ALTER MATERIALIZED VIEW monitor.ccp_table_size OWNER TO ccp_monitoring;


DROP MATERIALIZED VIEW IF EXISTS monitor.ccp_database_size;
CREATE MATERIALIZED VIEW monitor.ccp_database_size
AS SELECT datname as dbname
    , pg_database_size(datname) as bytes 
    FROM pg_catalog.pg_database 
    WHERE datistemplate = false;
CREATE UNIQUE INDEX ccp_database_size_idx ON monitor.ccp_database_size (dbname);
ALTER MATERIALIZED VIEW monitor.ccp_database_size OWNER TO ccp_monitoring;


GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA monitor TO ccp_monitoring;
GRANT ALL ON ALL TABLES IN SCHEMA monitor TO ccp_monitoring;

-- Don't alter any existing data that may already exist in the table
INSERT INTO monitor.matview_metrics (
    matview_name 
    , run_interval
    , scope )
VALUES (
   'ccp_stat_user_tables'
    , '10 minutes'::interval
    , 'database')
ON CONFLICT DO NOTHING;

INSERT INTO monitor.matview_metrics (
    matview_name 
    , run_interval
    , scope )
VALUES (
   'ccp_table_size'
    , '10 minutes'::interval
    , 'database')
ON CONFLICT DO NOTHING;

INSERT INTO monitor.matview_metrics (
    matview_name 
    , run_interval
    , scope )
VALUES (
   'ccp_database_size'
    , '10 minutes'::interval
    , 'global')
ON CONFLICT DO NOTHING;
