DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccp_monitoring') THEN
        CREATE ROLE ccp_monitoring WITH LOGIN;
    END IF;
END
$$;
 
GRANT pg_monitor to ccp_monitoring;

CREATE SCHEMA IF NOT EXISTS monitor AUTHORIZATION ccp_monitoring;

CREATE OR REPLACE FUNCTION monitor.pgbackrest_info() returns jsonb 
    LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    data jsonb;
BEGIN
    -- Get pgBackRest info in JSON format

    -- Create a temp table to hold the JSON data
    CREATE TEMP TABLE temp_pgbackrest_data (data jsonb);

    -- Copy data into the table directory from the pgBackRest into command
    COPY temp_pgbackrest_data (data)
        FROM program
            'pgbackrest --output=json info | tr ''\n'' '' ''' (format text);

    SELECT temp_pgbackrest_data.data
      INTO data
      FROM temp_pgbackrest_data;

    DROP TABLE temp_pgbackrest_data;

    RETURN data;
END $$; 

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA monitor TO ccp_monitoring;
