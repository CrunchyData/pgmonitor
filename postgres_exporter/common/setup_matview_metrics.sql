-- #########################
-- Materialized View Objects
-- #########################

CREATE SCHEMA IF NOT EXISTS monitor;

CREATE TABLE monitor.matview_metrics (
    , matview_schema text NOT NULL DEFAULT 'monitor'
    , matview_name text NOT NULL
    , concurrent_refresh boolean NOT NULL DEFAULT true
    , run_interval interval NOT NULL
    , last_run timestamptz
    , CONSTRAINT matview_metrics_pk PRIMARY KEY (matview_schema, matview_name)
)

CREATE PROCEDURE monitor.matview_refresh_metrics (p_matview_schema text DEFAULT 'monitor', p_matview_name text DEFAULT NULL)
    LANGUAGE plpgsql
    AS $$
DECLARE

v_loop_sql           text;
v_refresh_sql        text;
v_row                record;

BEGIN

v_loop_sql := format('SELECT matview_schema, matview_name, concurrent_refresh, run_interval, last_run FROM monitor.matview_metrics')
IF p_matview_name IS NOT NULL THEN
    v_loop_sql := format('%s WHERE matview_schema = %L AND matview_name = %L', v_loop_sql, p_matview_schema, p_matview_name);
END IF;

FOR v_row IN EXECUTE v_loop_sql LOOP

    IF CURRENT_TIMESTAMP - v_row.last_run > v_row.run_interval THEN

        v_refresh_sql := 'REFRESH MATERIALIZED VIEW '
        IF v_row.concurrent_refresh THEN
            v_refresh_sql := v_refresh_sql || 'CONCURRENTLY '
        END IF;
        v_refresh_sql := format('%s %I.%I', v_refresh_sql, v_row.matview_schema, v_row.matview_name);
        RAISE DEBUG 'pgmonitor matview refresh: %s', v_row.matview_name;
        EXECUTE v_refresh_sql;
        COMMIT;

    END IF;
            

END LOOP;

END
$$;

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

CREATE MATERIALIZED VIEW monitor.ccp_database_size
AS SELECT datname as dbname
    , pg_database_size(datname) as bytes 
    FROM pg_catalog.pg_database 
    WHERE datistemplate = false;
CREATE UNIQUE INDEX ccp_database_size_idx ON monitor.ccp_database_size (dbname);
ALTER MATERIALIZED VIEW monitor.ccp_database_size OWNER TO ccp_monitoring;

GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA monitor TO ccp_monitoring;
GRANT ALL ON ALL TABLES IN SCHEMA monitor TO ccp_monitoring;

