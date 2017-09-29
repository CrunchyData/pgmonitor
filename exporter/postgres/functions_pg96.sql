CREATE ROLE monitor WITH LOGIN;
 
CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION monitor;

CREATE OR REPLACE FUNCTION monitor.pg_stat_activity() RETURNS SETOF pg_catalog.pg_stat_activity
    LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN 
    RETURN query(SELECT * FROM pg_catalog.pg_stat_activity); 
END
$$; 

REVOKE ALL ON FUNCTION monitor.pg_stat_activity() FROM PUBLIC;


CREATE OR REPLACE FUNCTION monitor.streaming_replica_check() RETURNS TABLE (replica_hostname text, replica_addr inet, replica_port int, byte_lag numeric)
    LANGUAGE SQL SECURITY DEFINER
AS $$
    SELECT client_hostname as replica_hostname
        , client_addr as replica_addr
        , client_port as replica_port
            , pg_xlog_location_diff(pg_stat_replication.sent_location, pg_stat_replication.replay_location) AS byte_lag 
                FROM pg_catalog.pg_stat_replication;
$$;

REVOKE ALL ON FUNCTION monitor.streaming_replica_check() FROM PUBLIC;


CREATE OR REPLACE FUNCTION monitor.pg_stat_statements() RETURNS SETOF public.pg_stat_statements
    LANGUAGE SQL SECURITY DEFINER
AS $$
    SELECT * FROM public.pg_stat_statements;
$$;
REVOKE ALL ON FUNCTION monitor.pg_stat_statements () FROM PUBLIC;

/* this shouldn't be needed, but leaving here for reference/testing 
eREATE OR REPLACE FUNCTION monitor.replica_replay_time_lag() RETURNS TABLE (last_replay_time int) 
    LANGUAGE SQL SECURITY DEFINER
AS $$
    SELECT extract(epoch from now() - pg_last_xact_replay_timestamp())::int AS last_replay_time
    $$;

REVOKE ALL ON FUNCTION monitor.replica_replay_time_lag() FROM PUBLIC;
*/

CREATE OR REPLACE FUNCTION monitor.pg_ls_wal_dir(text) RETURNS SETOF TEXT 
    LANGUAGE plpgsql SECURITY DEFINER
as $$
BEGIN 
    IF current_setting('server_version_num')::int >= 100000 THEN
        RETURN query(SELECT pg_catalog.pg_ls_dir('pg_wal')); 
    ELSE
        RETURN query(SELECT pg_catalog.pg_ls_dir('pg_xlog')); 
    END IF;
END
$$;
REVOKE ALL ON FUNCTION monitor.pg_ls_wal_dir(text) FROM PUBLIC;


GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO monitor;
