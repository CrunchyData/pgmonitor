CREATE ROLE monitor WITH LOGIN;
 
GRANT pg_monitor to monitor;

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION monitor;

CREATE OR REPLACE FUNCTION monitor.streaming_replica_check() RETURNS TABLE (replica_hostname text, replica_addr inet, byte_lag numeric)
    LANGUAGE SQL SECURITY DEFINER
AS $$
    SELECT client_hostname as replica_hostname
        , client_addr as replica_addr
            , pg_xlog_location_diff(pg_stat_replication.sent_location, pg_stat_replication.replay_location) AS byte_lag 
                FROM pg_catalog.pg_stat_replication;
                $$;

REVOKE ALL ON FUNCTION monitor.streaming_replica_check() FROM PUBLIC;

-- pg_monitor does not grant this access
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
