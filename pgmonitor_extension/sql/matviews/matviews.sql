-- TODO Create sub-extension to add support for nodemx queries (require pgmonitor extension)
-- TODO Create sub-extension to add support for pgbouncer queries disabled by default (dependent on pgbouncer_fdw 1.0.0 and pgmonitor extension)
-- TODO make pg_stat_statements metrics function calls to allow for column differences in versions. Have parameter to function be the return limit
    -- Will let users make their own metrics with custom limits if they need them to be different
CREATE MATERIALIZED VIEW @extschema@.ccp_stat_user_tables AS 
    SELECT current_database() as dbname
    , schemaname
    , relname
    , seq_scan
    , seq_tup_read
    , idx_scan
    , idx_tup_fetch
    , n_tup_ins
    , n_tup_upd
    , n_tup_del
    , n_tup_hot_upd
    , n_live_tup
    , n_dead_tup
    , vacuum_count
    , autovacuum_count
    , analyze_count
    , autoanalyze_count 
    FROM pg_catalog.pg_stat_user_tables;
CREATE UNIQUE INDEX ccp_user_tables_db_schema_relname_idx ON @extschema@.ccp_stat_user_tables (dbname, schemaname, relname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_stat_user_tables'
    , '5 minutes'::interval
    , 'database');


CREATE MATERIALIZED VIEW @extschema@.ccp_table_size AS
    SELECT current_database() as dbname
    , n.nspname as schemaname
    , c.relname
    , pg_total_relation_size(c.oid) as size_bytes 
    FROM pg_catalog.pg_class c 
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid 
    WHERE NOT pg_is_other_temp_schema(n.oid) 
    AND relkind IN ('r', 'm', 'f');
CREATE UNIQUE INDEX ccp_table_size_idx ON @extschema@.ccp_table_size (dbname, schemaname, relname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_table_size'
    , '5 minutes'::interval
    , 'database');


CREATE MATERIALIZED VIEW @extschema@.ccp_database_size AS
    SELECT datname as dbname
    , pg_database_size(datname) as bytes 
    FROM pg_catalog.pg_database 
    WHERE datistemplate = false;
CREATE UNIQUE INDEX ccp_database_size_idx ON @extschema@.ccp_database_size (dbname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_database_size'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_locks AS 
    SELECT pg_database.datname as dbname
    , tmp.mode
    , COALESCE(count,0) as count
    FROM
    (
      VALUES ('accesssharelock'),
             ('rowsharelock'),
             ('rowexclusivelock'),
             ('shareupdateexclusivelock'),
             ('sharelock'),
             ('sharerowexclusivelock'),
             ('exclusivelock'),
             ('accessexclusivelock')
    ) AS tmp(mode) CROSS JOIN pg_catalog.pg_database
    LEFT JOIN
        (SELECT database, lower(mode) AS mode,count(*) AS count
        FROM pg_catalog.pg_locks WHERE database IS NOT NULL
        GROUP BY database, lower(mode)
    ) AS tmp2
    ON tmp.mode=tmp2.mode and pg_database.oid = tmp2.database;
CREATE UNIQUE INDEX ccp_locks_idx ON @extschema@.ccp_locks (dbname, mode);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_locks'
    , '1 minute'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_stat_bgwriter AS
    SELECT checkpoints_timed
    , checkpoints_req
    , checkpoint_write_time
    , checkpoint_sync_time
    , buffers_checkpoint
    , buffers_clean
    , maxwritten_clean
    , buffers_backend
    , buffers_backend_fsync
    , buffers_alloc
    , stats_reset 
    FROM pg_catalog.pg_stat_bgwriter;
/* According to docs, this table should only ever have 1 row */
CREATE UNIQUE INDEX ccp_stat_bgwriter_idx ON @extschema@.ccp_stat_bgwriter (stats_reset);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope 
    , concurrent_refresh )
VALUES (
   'ccp_stat_bgwriter'
    , '5 minutes'::interval
    , 'global'
    , false );


CREATE MATERIALIZED VIEW @extschema@.ccp_stat_database AS
    SELECT s.datname AS dbname
    , xact_commit
    , xact_rollback
    , blks_read
    , blks_hit
    , tup_returned
    , tup_fetched
    , tup_inserted
    , tup_updated
    , tup_deleted
    , conflicts
    , temp_files
    , temp_bytes
    , deadlocks
    FROM pg_catalog.pg_stat_database s 
    JOIN pg_catalog.pg_database d ON d.datname = s.datname
    WHERE d.datistemplate = false;
CREATE UNIQUE INDEX ccp_stat_database_idx ON @extschema@.ccp_stat_database (dbname);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_stat_database'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_sequence_exhaustion AS
    SELECT count FROM @extschema@.sequence_exhaustion(75);
CREATE UNIQUE INDEX ccp_sequence_exhaustion_idx ON @extschema@.ccp_sequence_exhaustion (count);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_sequence_exhaustion'
    , '5 minutes'::interval
    , 'database');


CREATE MATERIALIZED VIEW @extschema@.ccp_pg_settings_checksum AS
    SELECT @extschema@.pg_settings_checksum() AS status;
CREATE UNIQUE INDEX ccp_pg_settings_checksum_idx ON @extschema@.ccp_pg_settings_checksum (status);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_pg_settings_checksum'
    , '5 minutes'::interval
    , 'global');


CREATE MATERIALIZED VIEW @extschema@.ccp_pg_hba_checksum AS
    SELECT @extschema@.pg_hba_checksum() AS status;
CREATE UNIQUE INDEX ccp_pg_hba_checksum_idx ON @extschema@.ccp_pg_hba_checksum (status);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_pg_hba_checksum'
    , '5 minutes'::interval
    , 'global');

-- TODO add ccp_data_checksum_failure that calls function that returns NULL even on PG11.

CREATE MATERIALIZED VIEW @extschema@.ccp_wal_activity AS
    SELECT last_5_min_size_bytes,
      (SELECT COALESCE(sum(size),0) FROM pg_catalog.pg_ls_waldir()) AS total_size_bytes
      FROM (SELECT COALESCE(sum(size),0) AS last_5_min_size_bytes FROM pg_catalog.pg_ls_waldir() WHERE modification > CURRENT_TIMESTAMP - '5 minutes'::interval) x;
CREATE UNIQUE INDEX ccp_wal_activity_idx ON @extschema@.ccp_wal_activity (last_5_min_size_bytes, total_size_bytes);
INSERT INTO @extschema@.metric_views (
    view_name 
    , run_interval
    , scope )
VALUES (
   'ccp_wal_activity'
    , '2 minutes'::interval
    , 'global');
