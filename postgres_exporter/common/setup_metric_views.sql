-- #########################
-- Metric View Objects
-- #########################

CREATE SCHEMA IF NOT EXISTS monitor;

-- Preserve existing data if users added more views or changed schedule. Allows setup call to be idempodent.
DO $pgmonitor$
DECLARE
v_exists    smallint;
BEGIN

    SELECT count(*) INTO v_exists FROM information_schema.tables WHERE table_schema = 'monitor' AND table_name = 'metric_views';
    IF v_exists > 0 THEN
        CREATE TEMPORARY TABLE metric_views_preserve_temp (LIKE monitor.metric_views);
        INSERT INTO metric_views_preserve_temp SELECT * FROM monitor.metric_views;
        DROP TABLE monitor.metric_views;
    END IF;

    CREATE TABLE IF NOT EXISTS monitor.metric_views (
        view_schema text NOT NULL DEFAULT 'monitor'
        , view_name text NOT NULL
        , concurrent_refresh boolean NOT NULL DEFAULT true
        , run_interval interval NOT NULL
        , last_run timestamptz
        , active boolean NOT NULL DEFAULT true
        , scope text NOT NULL default 'global'
        , CONSTRAINT metric_views_pk PRIMARY KEY (view_schema, view_name)
        , CONSTRAINT metric_views_scope_ck CHECK (scope IN ('global', 'database'))
    );

    IF v_exists > 0 THEN
        INSERT INTO monitor.metric_views SELECT * FROM metric_views_preserve_temp;
        DROP TABLE metric_views_preserve_temp;
    END IF;

END
$pgmonitor$;


DROP PROCEDURE IF EXISTS monitor.refresh_metric_views (text, text);
CREATE PROCEDURE monitor.refresh_metric_views (p_view_schema text DEFAULT 'monitor', p_view_name text DEFAULT NULL)
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

v_loop_sql := format('SELECT view_schema, view_name, concurrent_refresh, run_interval, last_run 
                        FROM monitor.metric_views
                        WHERE active');

IF p_view_name IS NOT NULL THEN
    v_loop_sql := format('%s AND view_schema = %L AND view_name = %L', v_loop_sql, p_view_schema, p_view_name);
END IF;

FOR v_row IN EXECUTE v_loop_sql LOOP

    IF ((CURRENT_TIMESTAMP - v_row.last_run) > v_row.run_interval) OR (v_row.last_run IS NULL) THEN

        v_refresh_sql := 'REFRESH MATERIALIZED VIEW ';
        IF v_row.concurrent_refresh THEN
            v_refresh_sql := v_refresh_sql || 'CONCURRENTLY ';
        END IF;
        v_refresh_sql := format('%s %I.%I', v_refresh_sql, v_row.view_schema, v_row.view_name);
        RAISE DEBUG 'pgmonitor view refresh: %s', v_refresh_sql;
        EXECUTE v_refresh_sql;

        UPDATE monitor.metric_views 
        SET last_run = CURRENT_TIMESTAMP 
        WHERE view_schema = v_row.view_schema
        AND view_name = v_row.view_name;

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

-- Don't alter any existing data that is already there for any given view
INSERT INTO monitor.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_stat_user_tables'
    , '10 minutes'::interval
    , 'database')
ON CONFLICT DO NOTHING;

INSERT INTO monitor.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_table_size'
    , '10 minutes'::interval
    , 'database')
ON CONFLICT DO NOTHING;

INSERT INTO monitor.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_database_size'
    , '10 minutes'::interval
    , 'global')
ON CONFLICT DO NOTHING;
