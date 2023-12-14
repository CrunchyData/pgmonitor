# pgMonitor Extension

## Overview

This extension provides a means to collect metrics within a PostgreSQL database to be used by an external collection source (Prometheus exporter, Icinga/Nagios scraper, etc). Certain metrics are collected, their results stored as materialized views and refreshed on a per-query configurable timer. This allows the metric scraper to not have to be concerned about the underlying runtime of some queries that can be more expensive, especially as the size of the database grows (object size, table statistics, etc). A background worker is provided to refresh the materialized views automatically without the need for any third-party schedulers. 

## INSTALLATION

Requirement: 

 * PostgreSQL >= 12

### From Source
In the directory where you downloaded pgmonitor, run

    make install

If you do not want the background worker compiled and just want the plain SQL install, you can run this instead:

    make NO_BGW=1 install

Note that without the BGW, refreshing of the materialized views and tables will require manual management outside of the pgMonitor extension.


## CONFIGURATION

### PostgreSQL Setup

The background worker must be loaded on database start by adding the library to shared_preload_libraries in postgresql.conf

    shared_preload_libraries = 'pgmonitor_bgw'     # (change requires restart)

You can also set other control variables for the BGW in postgresql.conf. These can be added/changed at anytime with a simple reload. See the documentation for more details. 

`pgmonitor_bgw.dbname` is required at a minimum for maintenance to run on the given database(s). This can be a comma separated list if pgMonitor is installed on more than one database to collect per-database metrics.

    pgmonitor_bgw.dbname = 'proddb'

At this time `pgmonitor_bgw.role` must be a superuser due to elevated privileges that are required to gather all metrics as well as refresh the materialized views. Work is underway to see if this can be run as a non-supuseruser. It currently defaults to `postgres` if not set manually.

    pgmonitor_bgw.role = 'postgres'

The interval defaults to 30 seconds and generally doesn't need to be changed. If you're trying to adjust materialized view refresh timing, see the `metric_views` configuration table below.

    pgmonitor_bgw.interval = 30

Log into PostgreSQL and run the following commands. Schema is optional (but recommended) and can be whatever you wish, but it cannot be changed after installation. If you're using the BGW, the database cluster can be safely started without having the extension first created in the configured database(s). You can create the extension at any time and the BGW will automatically pick up that it exists without restarting the cluster (as long as shared_preload_libraries was set) and begin running maintenance as configured.

    CREATE SCHEMA monitor;
    CREATE EXTENSION pgmonitor SCHEMA partman;

### Metric configuration

The names of all views and materialized views are stored in the `metric_views` configuration table. The extension itself does not touch normal views as part of any maintenance; they are stored together with the materialized views so that external scrape tools can more easily find all view based metrics in one table.
```
                                Table "metric_views"
       Column       |           Type           | Collation | Nullable |       Default        
--------------------+--------------------------+-----------+----------+----------------------
 view_schema        | text                     |           | not null | 'monitor'::text
 view_name          | text                     |           | not null | 
 materialized_view  | boolean                  |           | not null | true
 concurrent_refresh | boolean                  |           | not null | true
 run_interval       | interval                 |           | not null | '00:10:00'::interval
 last_run           | timestamp with time zone |           |          | 
 active             | boolean                  |           | not null | true
 scope              | text                     |           | not null | 'global'::text
```

 - `view_schema`
    - Schema containing the view_name
 - `view_name`
    - Name of the view or materialized view in system catalogs
 - `materialized_view`
    - Boolean to set whether the view is materalized. Defaults to true. If false, this is a normal view and it is not touched as part of any refresh operations by this extension
 - `concurrent_refresh`
    - Boolean to set whether the materalized view can be refreshed concurrently. It is highly recommended that all matviews be written in a manner to support a unique key. Concurrent refreshes avoid any contention while metrics are being scraped by external tools.
 - `run_interval`
    - How often the materalized view should be refreshed. Must be a valid value of the PostgreSQL interval type
 - `last_run`
    - Timestamp of the last time this materalized view was refreshed
 - `active`
    - If a materalized view, determines whether it should be refreshed as part of automatic maintainance
    - Both matviews and normal views can also set this to be false as a means of allowing external scrape tools to ignore them
 - `scope`
    - Valid values are "global" or "database"
    - "global" means the values of this metric are the same on every database in the instance (ex. connections, replication, etc)
    - "database" means the values of this metric are only defined on a per database basis (database and table statisics, bloat, etc)
    - Can be used by external scrape tools to be able to determine whether to collect these metrics only once per PostgreSQL instance or once per database inside that instance

For metrics that still require storage of results for fast scraping but cannot use a materialized view, it is also possible to use a table and give pgMonitor an SQL statement to run to refresh that table. For example, the included pgBackRest metrics need to use a function that uses a COPY statement.
```
                             Table "metric_tables"
      Column       |           Type           | Collation | Nullable |        Default        
-------------------+--------------------------+-----------+----------+-----------------------
 table_schema      | text                     |           | not null | 'pgmonitor_ext'::text
 table_name        | text                     |           | not null | 
 refresh_statement | text                     |           | not null | 
 run_interval      | interval                 |           | not null | '00:10:00'::interval
 last_run          | timestamp with time zone |           |          | 
 active            | boolean                  |           | not null | true
 scope             | text                     |           | not null | 'global'::text
```

 - `table_schema`
    - Schema containing the table_name
 - `table_name`
    - Name of the table in system catalogs
 - `refresh_statement`
    - The full SQL statement that is run to refresh the data in `table_name`. Ex: `SELECT pgmonitor_ext.pgbackrest_info()`
 - See `metric_views` for purpose of remaining columns

TODO:

- Add matview refresh last runtime to config table
- Document other objects

NORMAL VIEWS:
```
ccp_is_in_recovery
ccp_postgresql_version
ccp_postmaster_runtime
ccp_transaction_wraparound
ccp_archive_command_status
ccp_postmaster_uptime
ccp_settings_pending_restart
ccp_replication_lag
ccp_connection_stats
ccp_replication_lag_size
ccp_replication_slots
ccp_data_checksum_failure
```

MAT VIEWS:
```
ccp_stat_user_tables
ccp_table_size
ccp_database_size
ccp_locks
ccp_stat_bgwriter
ccp_stat_database
ccp_sequence_exhaustion
ccp_pg_settings_checksum
ccp_pg_hba_checksum
ccp_wal_activity
```

TABLES:
```
pg_settings_checksum
pg_hba_checksum
pg_stat_statements_reset_info 
```

FUNCTIONS:
```
sequence_status() RETURNS TABLE (sequence_name text, last_value bigint, slots numeric, used numeric, percent int, cycle boolean, numleft numeric, table_usage text)  
sequence_exhaustion(p_percent integer DEFAULT 75, OUT count bigint)
pg_settings_checksum(p_known_settings_hash text DEFAULT NULL) 
pg_hba_checksum(p_known_hba_hash text DEFAULT NULL) 
pg_settings_checksum_set_valid() RETURNS smallint
pg_hba_checksum_set_valid() RETURNS smallint
pg_stat_statements_reset_info(p_throttle_minutes integer DEFAULT 1440)
```
PROCEDURE:
```
refresh_metric_views (p_view_schema text DEFAULT 'monitor', p_view_name text DEFAULT NULL)
```
