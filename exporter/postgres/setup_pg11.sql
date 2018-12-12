DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN;
    END IF;
END
$$;
 
GRANT pg_monitor to ccp_monitoring;

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

-- There are currently no SECURITY DEFINER functions required as long as the "pg_monitor" role is granted to ccp_monitoring.

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
