CREATE TABLE @extschema@.metric_views (
    view_schema text NOT NULL DEFAULT '@extschema@'
    , view_name text NOT NULL
    , materialized_view boolean NOT NULL DEFAULT true
    , concurrent_refresh boolean NOT NULL DEFAULT true
    , run_interval interval NOT NULL DEFAULT '10 minutes'::interval
    , last_run timestamptz
    , active boolean NOT NULL DEFAULT true
    , scope text NOT NULL default 'global'
    , CONSTRAINT metric_views_pk PRIMARY KEY (view_schema, view_name)
    , CONSTRAINT metric_views_scope_ck CHECK (scope IN ('global', 'database'))
);
CREATE INDEX metric_views_active_matview ON @extschema@.metric_views (active, materialized_view);
SELECT pg_catalog.pg_extension_config_dump('metric_views', '');
ALTER TABLE @extschema@.metric_views SET (
    autovacuum_analyze_scale_factor = 0
    , autovacuum_vacuum_scale_factor = 0
    , autovacuum_vacuum_threshold = 10
    , autovacuum_analyze_threshold = 10);

CREATE TABLE @extschema@.metric_tables (
    table_schema text NOT NULL DEFAULT '@extschema@'
    , table_name text NOT NULL
    , refresh_statement text NOT NULL
    , run_interval interval NOT NULL DEFAULT '10 minutes'::interval
    , last_run timestamptz
    , active boolean NOT NULL DEFAULT true
    , scope text NOT NULL default 'global'
    , CONSTRAINT metric_tables_pk PRIMARY KEY (table_schema, table_name)
);
CREATE INDEX metric_tables_active_refresh_idx ON @extschema@.metric_tables (active, refresh_statement);
ALTER TABLE @extschema@.metric_tables SET (
    autovacuum_analyze_scale_factor = 0
    , autovacuum_vacuum_scale_factor = 0
    , autovacuum_vacuum_threshold = 10
    , autovacuum_analyze_threshold = 10);

/*
 * Tables and functions for monitoring changes to pg_settings and pg_hba_file_rules system catalogs.
 * Tables allow recording of existing settings so they can be referred back to to see what changed
 */
CREATE TABLE @extschema@.pg_settings_checksum (
    settings_hash_generated text NOT NULL
    , settings_hash_known_provided text
    , settings_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );
COMMENT ON COLUMN @extschema@.pg_settings_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON @extschema@.pg_settings_checksum (created_at);
ALTER TABLE @extschema@.pg_settings_checksum SET (
    autovacuum_analyze_scale_factor = 0
    , autovacuum_vacuum_scale_factor = 0
    , autovacuum_vacuum_threshold = 10
    , autovacuum_analyze_threshold = 10);

CREATE TABLE @extschema@.pg_hba_checksum (
    hba_hash_generated text NOT NULL
    , hba_hash_known_provided text
    , hba_string text NOT NULL
    , created_at timestamptz DEFAULT now() NOT NULL
    , valid smallint NOT NULL );
COMMENT ON COLUMN @extschema@.pg_hba_checksum.valid IS 'Set this column to zero if this group of settings is a valid change';
CREATE INDEX ON @extschema@.pg_hba_checksum (created_at);
ALTER TABLE @extschema@.pg_hba_checksum SET (
    autovacuum_analyze_scale_factor = 0
    , autovacuum_vacuum_scale_factor = 0
    , autovacuum_vacuum_threshold = 10
    , autovacuum_analyze_threshold = 10);


CREATE TABLE @extschema@.pg_stat_statements_reset_info(
   reset_time timestamptz 
);

-- Backrest objects
CREATE TABLE @extschema@.pgbackrest_info (
    config_file text NOT NULL
    , data jsonb NOT NULL);
ALTER TABLE @extschema@.pgbackrest_info SET (
    autovacuum_analyze_scale_factor = 0
    , autovacuum_vacuum_scale_factor = 0
    , autovacuum_vacuum_threshold = 10
    , autovacuum_analyze_threshold = 10);
INSERT INTO @extschema@.metric_tables (
    table_schema
    , table_name
    , refresh_statement
    , run_interval
    , active )
VALUES (
    '@extschema@'
    , 'pgbackrest_info'
    , 'SELECT @extschema@.pgbackrest_info()'
    , '10 minutes'
    , false
);
    

--TODO create prometheus metrics table to match columns to Prometheus output formatting info. better table name?
-- Use jsonb to allow full flexiblity for whatever upstream may need to have set for metric output
/*
 CREATE TABLE @extschema@.prometheus_metric_details (
    view_schema text NOT NULL
    , view_name text NOT NULL
    , column_details jsonb NOT NULL
    , CONSTRAINT prometheus_metric_details_pk PRIMARY KEY (view_schema, view_name);

-- I know this isn't valid json. will look it up
INSERT INTO @extschema@.prometheus_metric_details (view_schema, view_name, column_details) 
VALUES ('monitor'
        , 'ccp_connection_stats'
        , '{ "active" => { "TYPE stuff", "HELP stuff" }
            , "total" =>  { "TYPE stuff", "HELP stuff" }
           }' );
 */
