CREATE ROLE ccp_monitoring WITH LOGIN;
 
GRANT pg_monitor to ccp_monitoring;

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

-- There are currently no SECURITY DEFINER functions required as long as the "pg_monitor" role is granted to ccp_monitoring.

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
