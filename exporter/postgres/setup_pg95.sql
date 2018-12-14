DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN;
    END IF;
END
$$;
 
CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

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


-- Drop previously unused version of this function if it exists from older pgmonitor installs
DROP FUNCTION IF EXISTS monitor.pg_ls_wal_dir(text);

CREATE OR REPLACE FUNCTION monitor.pg_ls_waldir() RETURNS SETOF TEXT 
    LANGUAGE plpgsql SECURITY DEFINER
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


GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
