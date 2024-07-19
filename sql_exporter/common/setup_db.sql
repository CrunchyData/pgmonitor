-- pgMonitor Setup
--
-- Copyright © 2017-2023 Crunchy Data Solutions, Inc. All Rights Reserved.
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN PASSWORD 'stuff';
    END IF;
END
$$;

GRANT pg_monitor to ccp_monitoring;
GRANT pg_execute_server_program TO ccp_monitoring;

ALTER ROLE ccp_monitoring SET lock_timeout TO '2min';
ALTER ROLE ccp_monitoring SET jit TO 'off';

CREATE SCHEMA IF NOT EXISTS pgmonitor_ext AUTHORIZATION ccp_monitoring;

CREATE EXTENSION pgmonitor SCHEMA pgmonitor_ext;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pgmonitor_ext TO ccp_monitoring;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA pgmonitor_ext TO ccp_monitoring;
GRANT ALL ON ALL TABLES IN SCHEMA pgmonitor_ext TO ccp_monitoring;
