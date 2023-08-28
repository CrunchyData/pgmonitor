CREATE PROCEDURE @extschema@.refresh_metrics (p_object_schema text DEFAULT 'monitor', p_object_name text DEFAULT NULL)
    LANGUAGE plpgsql
    AS $$
DECLARE

v_loop_sql                      text;
v_refresh_statement     text;
v_refresh_sql                   text;
v_row                           record;

BEGIN

-- TODO Add advisory lock to avoid stacking concurrent runs. Throw a warning in logs that if it's happening repeatedly, adjust the BGW interval
-- TODO Record the runtime of each objects refresh time in config table

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

    COMMIT;
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

    COMMIT;
END LOOP;

END
$$;

