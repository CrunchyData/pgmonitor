DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN;
    END IF;
END
$$;
 
GRANT pg_monitor to ccp_monitoring;

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

DROP TABLE IF EXISTS monitor.pgbackrest_info;
CREATE TABLE IF NOT EXISTS monitor.pgbackrest_info (data jsonb NOT NULL);

CREATE OR REPLACE FUNCTION monitor.pgbackrest_info() returns jsonb 
    LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_data jsonb;
BEGIN
    -- Get pgBackRest info in JSON format

    -- Ensure table is empty 
    TRUNCATE monitor.pgbackrest_info;

    -- Copy data into the table directory from the pgBackRest into command
    COPY monitor.pgbackrest_info (data)
        FROM program
            'pgbackrest --output=json info | tr ''\n'' '' ''' (format text);

    SELECT data
      INTO v_data
      FROM monitor.pgbackrest_info;

    TRUNCATE monitor.pgbackrest_info;

    IF v_data IS NULL THEN
        RAISE EXCEPTION 'No backups being returned from pgbackrest info command';
    END IF;

    RETURN v_data;

END $$; 

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
