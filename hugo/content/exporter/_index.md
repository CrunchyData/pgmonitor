---
title: "Setting up Exporters"
draft: false
weight: 1
---

The Linux instructions below use RHEL, but any Linux-based system should work. [Crunchy Data](https://www.crunchydata.com) customers can obtain Linux packages through the [Crunchy Customer Portal](https://access.crunchydata.com/).


- [Installation](#installation)
   - [RPM installs](#rpm-installs)
   - [Non-RPMs installs](#non-rpm-installs)
- [Upgrading](#upgrading)
- [Setup](#setup)
   - [RHEL or CentOS](#setup-on-rhel-or-centos)
- [Metrics Collected](#metrics-collected)
   - [PostgreSQL](#postgresql)
   - [System](#system)
- [Legacy postgres_exporter Setup](#postgres-exporter)


IMPORTANT NOTE: As of pgMonitor version 5.0.0, postgres_exporter has been deprecated in favor of sql_exporter. Support for postgres_exporter is still possible with 5.0, but only for bug fixes while custom queries are still supported. No new features will be added using postgres_exporter and it will be fully obsoleted in a future version of pgMonitor. We recommend migrating to sql_exporter as soon as possible.

## Installation {#installation}


### RPM installs {#rpm-installs}

The following RPM packages are available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/). To access the pgMonitor packages, please follow the same instructions for setting up access to the Crunchy Postgres packages.

After installing via these packages, continue reading at the [Setup](#setup) section.

##### Available Packages

| Package Name                   | Description                                                               |
|--------------------------------|---------------------------------------------------------------------------|
| blackbox-exporter              | Package for the blackbox_exporter                                         |
| node-exporter                  | Base package for node_exporter                                            |
| pg-bloat-check                 | Package for pg_bloat_check script                                         |
| pgmonitor-node_exporter-extras | Crunchy-optimized configurations for node_exporter                        |
| pgmonitor-pg##-extension       | Crunchy monitoring PostgreSQL extension used by sql_exporter              |
| sql-exporter                   | Base package for sql_exporter                                             |
| sql-exporter-extras            | Crunchy-optimized configurations for sql_exporter                         |



### Non-RPM installs {#non-rpm-installs}

For non-package installations on Linux, applications can be downloaded from their respective repositories:

| Application                   | Source Repository                                         |
|-------------------------------|-----------------------------------------------------------|
| blackbox_exporter             | https://github.com/prometheus/blackbox_exporter           |
| node_exporter                 | https://github.com/prometheus/node_exporter               |
| pg_bloat_check                | https://github.com/keithf4/pg_bloat_check                 |
| pgmonitor-extension           | https://github.com/CrunchyData/pgmonitor-extension        |
| sql_exporter                  | https://github.com/burningalchemist/sql_exporter          |

#### User and Configuration Directory Installation

You will need to create a user named {{< shell >}}ccp_monitoring{{< /shell >}} which you can do with the following command:

```bash
sudo useradd -m -d /var/lib/ccp_monitoring ccp_monitoring
```

#### Configuration File Installation

All executables installed via the above releases are expected to be in the {{< shell >}}/usr/bin{{< /shell >}} directory. A base node_exporter systemd file is expected to be in place already. An example one can be found here:

https://github.com/prometheus/node_exporter/tree/master/examples/systemd

A base blackbox_exporter systemd file is also expected to be in place. No examples are currently available.

The files contained in this repository are assumed to be installed in the following locations with the following names. In the instructions below, you should replace a double-hash (`##`) with the two-digit major version of PostgreSQL you are running (ex: 12, 13, 14, etc.).

##### node_exporter

The {{< shell >}}node_exporter{{< /shell >}} data directory should be {{< shell >}}/var/lib/ccp_monitoring/node_exporter{{< /shell >}} and owned by the {{< shell >}}ccp_monitoring{{< /shell >}} user.  You can set it up with:

```bash
sudo install -m 0700 -o ccp_monitoring -g ccp_monitoring -d /var/lib/ccp_monitoring/node_exporter
```

The following pgMonitor configuration files should be placed according to the following mapping:

| pgmonitor Configuration File | System Location |
|------------------------------|-----------------|
| node_exporter/linux/crunchy-node-exporter-service-rhel.conf | /etc/systemd/system/node_exporter.service.d/crunchy-node-exporter-service-rhel.conf  |
| node_exporter/linux/sysconfig.node_exporter | /etc/sysconfig/node_exporter |

##### sql_exporter

sql_exporter takes advantage of the Crunchy Data pgmonitor-extension (https://github.com/CrunchyData/pgmonitor-extension) to provide a much easier configuration and setup. The extension takes care of creating all the necessary objects inside the database.

The minimum required version of pgmonitor-extension is currently 1.0.0.

The following pgMonitor configuration files should be placed according to the following mapping:

| pgMonitor Configuration File | System Location |
|------------------------------|-----------------|
| sql_exporter/common/*.yml | /etc/sql_exporter/*.yml |
| sql_exporter/common/*.sql | /etc/sql_exporter/*.sql |
| sql_exporter/linux/crunchy-sql-exporter@.service | /usr/lib/systemd/system/crunchy-sql-exporter@.service |
| sql_exporter/linux/sql_exporter.sysconfig | /etc/sysconfig/sql_exporter |
| sql_exporter/linux/crontab.txt | /etc/sysconfig/crontab.txt |
| postgres_exporter/linux/pgbackrest-info.sh | /usr/bin/pgbackrest-info.sh |
| postgres_exporter/linux/pgmonitor.conf | /etc/pgmonitor.conf (multi-backrest-repository/container environment only) |
| sql_exporter/common/sql_exporter.yml.example | /etc/sql_exporter/sql_exporter.yml |


##### blackbox_exporter

The following pgMonitor configuration files should be placed according to the following mapping:

| pgMonitor Configuration File | System Location |
|------------------------------|-----------------|
| blackbox_exporter/common/blackbox_exporter.sysconfig  | /etc/sysconfig/blackbox_exporter   |
| blackbox_exporter/common/crunchy-blackbox.yml| /etc/blackbox_exporter/crunchy-blackbox.yml |


## Upgrading {#upgrading}

* If you are upgrading to version 5.0 and transitioning to using the new sql_exporter, please see the documentation in [Upgrading to pgMonitor v5.0.0](/changelog/v5_upgrade/)
* See the [CHANGELOG ](/changelog) for full details on both major & minor version upgrades.

## Setup {#setup}

### Setup on RHEL or CentOS {#setup-on-rhel-or-centos}

#### Service Configuration

The following files contain defaults that should enable the exporters to run effectively on your system for the purposes of using pgMonitor.  Please take some time to review them.

If you need to modify them, see the notes in the files for more details and recommendations:
- {{< shell >}}/etc/systemd/system/node_exporter.service.d/crunchy-node-exporter-service-rhel.conf{{< /shell >}}
- {{< shell >}}/etc/sysconfig/node_exporter{{< /shell >}}
- {{< shell >}}/etc/sysconfig/sql_exporter{{< /shell >}}

#### Database Configuration

##### General Configuration

First, make sure you have installed the PostgreSQL contrib modules.  An example of installing this on a RHEL system would be:

```bash
sudo yum install postgresql##-contrib
```

Where `##` corresponds to your current PostgreSQL version.

You will need to modify your {{< shell >}}postgresql.conf{{< /shell >}} configuration file to tell PostgreSQL to load the following shared libraries:
```
shared_preload_libraries = 'pg_stat_statements,auto_explain,pgmonitor_bgw'
```

You will need to restart your PostgreSQL instance for the change to take effect. pgMonitor has optional metrics that can be collected via pg_stat_statements. auto_explain does not do anything to your database without further configuration. But even if neither of these extensions are initially used, they are very good to have enabled here by default for when they may be needed in the future.

The pgmonitor-extension uses its own background worker to refresh metric data.

The following statement only needs to be run on the "global" database, typically the "postgres" database. If you want the pg_stat_statements view to be visible in other databases, this statement must be run there as well.

```sql
CREATE EXTENSION pg_stat_statements;
```

##### Monitoring Setup

| Configuration File                                     | Description                                                                                              |
|------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| setup_db.sql                                   | Creates `ccp_monitoring` role with all necessary grants. Creates the pgmonitor-extension and sets proper privileges  |
| sql_exporter.yml.example                       | Example configuration file for configuring sql_exporter to connect to PostgreSQL and setting collection files to use |
| crunchy_backrest_collector.yml                 | Collection file with pgBackRest queries and metrics |
| crunchy_bloat_check_collector.yml              | Collection file with pg_bloat_check queries and metrics |
| crunchy_global_collector.yml                   | Collection file with global level queries and metrics |
| crunchy_per_db_collector.yml                   | Collection file with general per-database level queries and metrics |
| crunchy_pgbouncer_collector_121.yml            | Collection file with pgBouncer queries and metrics for a minimum version of 1.21 |
| crunchy_pg_stat_statements_collector.yml       | Collection file with pg_stat_statements queries and metrics
| crunchy_pg_stat_statements_reset_collector.yml | Collection file with options to allow resetting of pg_stat_statements metrics |


Run the setup_db.sql file on all databases that will be monitored by pgMonitor. At minimum this must be at least the global database so the necessary database objects are created. The `pgmonitor-extension` is expected to be available to be installed in the target database(s) when running this file. Note the setup.sql file is a convenience file and the steps contained within it can be done manually and customized as needed.

The `sql_exporter.yml.example` file should be copied and renamed to `sql_exporter.yml` since this is what the sysconfig file is expecting to find. This file contains settings for sql_exporter, the list of collection files to use, and the configuration for which databases to connect to and which collections to run on each database. Please see the examples inside the file and refer to the upstream project for all of the configuration options available. The example shows how to run both the global and per-db collections on the default 'postgres' database. It also shows how you can connect to PgBouncer to collect metrics directly from it as well. The collector names that can be used can be found inside the collection files at the top. For additional information on setting up the sql_exporter, please see the (upstream documentation)[#non-rpm-installs]

Note that your pg_hba.conf will have to be configured to allow the {{< shell >}}ccp_monitoring{{< /shell >}} system user to connect as the {{< shell >}}ccp_monitoring{{< /shell >}} role to any database in the instance. sql_exporter is set to connect via the local TCP loopback by default. If passwordless login is desired, a .pgpass file can be created for the ccp_monitoring user or the connection configuration can be changed to use a local socket and peer-based authentication can be done instead.

For replica servers, the setup is the same except that the setup_db.sql file does not need to be run since writes cannot be done there and it was already run on the primary.

##### Access Control: GRANT statements

The {{< shell >}}ccp_monitoring{{< /shell >}} database role (created by running the "setup_db.sql" file above) must be allowed to connect to all databases in the cluster. Note that by default, all users are granted CONNECT on all new databases, so this step can likely be skipped. Otherwise, run the following command to generate the necessary GRANT statements:

```sql
SELECT 'GRANT CONNECT ON DATABASE "' || datname || '" TO ccp_monitoring;'
FROM pg_database
WHERE datallowconn = true;
```
This should generate one or more statements similar to the following:

```sql
GRANT CONNECT ON DATABASE "postgres" TO ccp_monitoring;
```
Run these grant statements to then allow monitoring to connect.


##### Bloat setup

Run the script on the specific database(s) you will be monitoring for bloat in the cluster. See the note below, or in crontab.txt, concerning special privilege requirements for using this script.

```bash
psql -d postgres -c "CREATE EXTENSION pgstattuple;"
/usr/bin/pg_bloat_check.py -c "host=localhost dbname=postgres user=postgres" --create_stats_table
psql -d postgres -c "GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON bloat_indexes, bloat_stats, bloat_tables TO ccp_monitoring;"
```
The {{< shell >}}/etc/sql_exporter/##/crontab.txt{{< /shell >}} file has an example bloat check crontab entry. Modify this example to schedule bloat checking weekly during your 'off-peak' hours; alternatively, scheduling it monthly is usually good enough for most databases as long as the results are acted upon quickly.

{{< note >}}Bloat monitoring requires the user running the check to be able to read all possible tables that will ever exist. PostgreSQL 14 introduced the built-in role {{< shell >}}pg_read_all_data{{< /shell >}} that can be granted to any role to allow it to read all possible data for the entire cluster. It is recommended to grant this role vs running the bloat check as a superuser. If you are running a version of PostgreSQL less than 14, a superuser is required and you will have to adjust the crontab accordingly to run as that user.
```
GRANT pg_read_all_data TO ccp_monitoring;
```
{{< /note >}}

##### Blackbox Exporter

The configuration file for the blackbox_exporter provided by pgMonitor ({{< shell >}}/etc/blackbox_exporter/crunchy-blackbox.yml{{< /shell >}}) provides a probe for monitoring any IPv4 TCP port status. The actual target and port being monitored are controlled via the Prometheus target configuration system. Please see the pgMonitor Prometheus documentation for further details. If any additional Blackbox probes are desired, please see the upstream documentation.

##### PGBouncer

It is possible for sql_exporter to connect directly to pgBouncer to collect metrics. Specific settings must be used and the example sql_exporter configuration and relevant collection file(s) have these settings enabled. Please refer to those files.

#### Enable Services

```bash
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

If you've installed the blackbox exporter:
```bash
sudo systemctl enable blackbox_exporter
sudo systemctl start blackbox_exporter
sudo systemctl status blackbox_exporter
```

```bash
sudo systemctl enable crunchy-sql-exporter@sql_exporter
sudo systemctl start crunchy-sql-exporter@sql_exporter
sudo systemctl status crunchy-sql-exporter@sql_exporter
```

To allow the possible use of multiple sql_exporters running on a single system, and to avoid maintaining many similar service files, a systemd template service file is used. The name of the sysconfig EnvironmentFile to be used by the service is passed as the value after the "@" and before ".service" in the service name. The default exporter's sysconfig file is named "sql_exporter".  If you need to run multiple sql_exporters on a single system, simply make a new copy of the sysconfig file and pass that to the service name.

```bash
sudo systemctl enable crunchy-sql-exporter@sql_exporter_cluster2
sudo systemctl start crunchy-sql-exporter@sql_exporter_cluster2
sudo systemctl status crunchy-sql-exporter@sql_exporter_cluster2

```

### Monitoring multiple databases

sql_exporter can connect to as many databases as you need. Simply add another connection configuration to the `job_name` in the sql_exporter configuration file for the other databases you wish to monitor. If making use of pgMonitor's metrics, ensure that the pgmonitor-extension is also installed on those target databases.

IMPORTANT NOTE: If you are collecting metrics on multiple databases with the same exporter, you must ensure the results of the queries for those metrics are unique for each row. For example, you should add the database name to all queries and set that as a label to ensure the metrics are unique for each database. Otherwise you will get duplicate metric errors or confusing results. All per-database metrics provided by pgMonitor have been set to ensure unique values.

```
jobs:
  - job_name: global_targets
    collectors: [crunchy_global]
    static_configs:
        - targets:
            pg1: 'pg://ccp_monitoring@127.0.0.1:5432/postgres?sslmode=disable'
  - job_name: per_db_targets
    collectors: [crunchy_per_db]
    static_configs:
        - targets:
            postgres: 'pg://ccp_monitoring@127.0.0.1:5432/postgres?sslmode=disable'
            alpha: 'pg://ccp_monitoring@127.0.0.1:5432/alpha?sslmode=disable'
            beta: 'pg://ccp_monitoring@127.0.0.1:5432/beta?sslmode=disable'
            charlie: 'pg://ccp_monitoring@127.0.0.1:5432/charlie?sslmode=disable'
```


## Metrics Collected {#metrics-collected}

The metrics collected by our exporters are outlined below.

### PostgreSQL {#postgresql}

PostgreSQL metrics are collected by [sql_exporter](https://github.com/burningalchemist/sql_exporter). pgMonitor uses custom queries for its PG metrics.


#### Common Metrics

Metrics contained in the `queries_global.yml` file. These metrics are common to all versions of PostgreSQL and are recommended as a minimum default for the global exporter.

 * *ccp_archive_command_status_seconds_since_last_fail* - Seconds since the last `archive_command` run failed. If zero, the `archive_command` is succeeding without error.

 * *ccp_database_size_bytes* - Total size of each database in PostgreSQL instance

 * *ccp_is_in_recovery_status* - Current value of the pg_is_in_recovery() function expressed as 1 for true (instance is a replica) and 2 for false (instance is a primary)

 * *ccp_connection_stats_active* - Count of active connections

 * *ccp_connection_stats_idle* - Count of idle connections

 * *ccp_connection_stats_idle_in_txn* - Count of idle in transaction connections

 * *ccp_connection_stats_max_blocked_query_time* - Runtime of longest running query that has been blocked by a heavyweight lock

 * *ccp_connection_stats_max_connections* - Current value of max_connections for reference

 * *ccp_connection_stats_max_idle_in_txn_time* - Runtime of longest idle in transaction (IIT) session.

 * *ccp_connection_stats_max_query_time* - Runtime of longest general query (inclusive of IIT).

 * *ccp_connection_stats_max_blocked_query_time* - Runtime of the longest running query that has been blocked by a heavyweight lock

 * *ccp_locks_count* - Count of active lock types per database

 * *ccp_pg_hba_checksum_status* - Value of checksum monitioring status for pg_catalog.pg_hba_file_rules (pg_hba.conf). 0 = valid config. 1 = settings changed. Settings history is available for review in the table `monitor.pg_hba_checksum`. To reset current config to valid after alert, run monitor.pg_hba_checksum_set_valid(). Note this will clear the history table.

 * *ccp_pg_settings_checksum_status* -  Value of checksum monitioring status for pg_catalog.pg_settings (postgresql.conf). 0 = valid config. 1 = settings changed. Settings history is available for review in the table `monitor.pg_settings_checksum`. To reset current config to valid after alert, run monitor.pg_settings_checksum_set_valid(). Note this will clear the history table.

 * *ccp_postmaster_uptime_seconds* - Time interval in seconds since PostgreSQL database was last restarted

 * *ccp_postgresql_version_current* - Version of PostgreSQL that this exporter is monitoring. Value is the 6 digit integer returned by the `server_version_num` PostgreSQL configuration variable to allow easy monitoring for version changes.

 * *ccp_replication_lag_replay_time* - Time since a replica received and replayed a WAL file; only shown on replica instances. Note that this is not the main way to determine if a replica is behind its primary. This metric only monitors the time since the replica replayed the WAL vs when it was received. It also does not monitor when a WAL replay replica completely stops receiving WAL (see received_time metric). It is a secondary metric for monitoring WAL replay on the replica itself. This metric always returns zero on a primary.

 * *ccp_replication_lag_received_time* - Similar to *ccp_replication_lag_replay_time*, however this value always increases between replay of WAL files. Effective for monitoring that a WAL replay replica has actually received WAL files. Note this will cause false positives when used as an alert for replica lag if the primary receives little to no writes (which means there is no WAL to send). This metric always returns zero on a primary.

 * *ccp_replication_lag_size_bytes* - Only provides values on instances that have attached replicas (primary, cascading replica). Tracks byte lag of every streaming replica connected to this database instance. This is the main way that replication lag is monitored. Note that if you have WAL replay only replicas, this will not be reflected here.

 * *ccp_replication_slots_active* - Active state of given replication slot. 1 = true. 0 = false.

 * *ccp_replication_slots_retained_bytes* - The amount of WAL (in bytes) being retained for given slot.

 * *ccp_sequence_exhaustion_count* - Checks for any sequences that may be close to exhaustion (by default greater than 75% usage). Note this checks the sequences themselves, not the values contained in the columns that use said sequences. Function `monitor.sequence_status()` can provide more details if run directly on database instance.

 * *ccp_settings_pending_restart_count* - Number of settings from pg_settings catalog in a pending_restart state. This value is from the similarly named column found in pg_catalog.pg_settings.

 * *ccp_wal_activity_total_size_bytes* - Current size in bytes of the WAL directory

 * *ccp_wal_activity_last_5_min_size_bytes* - Current size in bytes of the last 5 minutes of WAL generation. Includes recycled WALs.

The meaning of the following `ccp_transaction_wraparound` metrics, and how to manage when they are triggered, is covered more extensively in this blog post: https://info.crunchydata.com/blog/managing-transaction-id-wraparound-in-postgresql

 * *ccp_transaction_wraparound_percent_towards_emergency_autovac* - Recommended thresholds set to 75%/95% when first evaluating vacuum settings on new systems. Once those have been reviewed and at least one instance-wide vacuum has been run, recommend thresholds of 110%/125%. Reaching 100% is not a cause for immediate concern, but alerting above 100% for extended periods of time means that autovacuum is not able to keep up with current transaction rate and needs further tuning.

 * *ccp_transaction_wraparound_percent_towards_wraparound* - Recommend thresholds set to 50%/75%. If any of these thresholds is tripped, current vacuum settings must be evaluated and tuned ASAP. If critical threshold is reached, it is vitally important that vacuum be run on tables with old transaction IDs to avoid the cluster being forced to shut down for extended offline maintenance.


The following `ccp_stat_bgwriter` metrics are statistics collected from the [pg_stat_bgwriter](https://www.postgresql.org/docs/current/monitoring-stats.html#PG-STAT-BGWRITER-VIEW) view for monitoring performance. These metrics cover important performance information about flushing data out to disk. Please see the documentation for further details on these metrics.

 * *ccp_stat_bgwriter_buffers_alloc*

 * *ccp_stat_bgwriter_buffers_backend*

 * *ccp_stat_bgwriter_buffers_backend_fsync*

 * *ccp_stat_bgwriter_buffers_checkpoint*

 * *ccp_stat_bgwriter_buffers_clean*

The following `ccp_stat_database_*` metrics are statistics collected from the [pg_stat_database](https://www.postgresql.org/docs/current/monitoring-stats.html#PG-STAT-DATABASE-VIEW) view.

 * *ccp_stat_database_blks_hit*

 * *ccp_stat_database_blks_read*

 * *ccp_stat_database_conflicts*

 * *ccp_stat_database_deadlocks*

 * *ccp_stat_database_tup_deleted*

 * *ccp_stat_database_tup_fetched*

 * *ccp_stat_database_tup_inserted*

 * *ccp_stat_database_tup_returned*

 * *ccp_stat_database_tup_updated*

 * *ccp_stat_database_xact_commit*

 * *ccp_stat_database_xact_rollback*

#### PostgreSQL Version Specific Metrics

The following metrics either require special considerations when monitoring specific versions of PostgreSQL, or are only available for specific versions. These metrics are found in the `queries_pg##.yml` files, where ## is the major version of PG. Unless otherwise noted, the below metrics are available for all versions of PG. These metrics are recommend as a minimum default for the global exporter.

 * *ccp_data_checksum_failure_count* - PostgreSQL 12 and later only. Total number of checksum failures on this database.

 * *ccp_data_checksum_failure_time_since_last_failure_seconds* - PostgreSQL 12 and later only. Time interval in seconds since the last checksum failure was encountered.

#### Backup Metrics

Backup monitoring only covers pgBackRest at this time. These metrics are found in the `queries_backrest.yml` file. These metrics only need to be collected once per database instance so should be collected by the global postgres_exporter.

 * *ccp_backrest_last_full_backup_time_since_completion_seconds* - Time since completion of last pgBackRest FULL backup

 * *ccp_backrest_last_diff_backup_time_since_completion_seconds* - Time since completion of last pgBackRest DIFFERENTIAL backup. Note that FULL backup counts as a successful DIFFERENTIAL for the given stanza.

 * *ccp_backrest_last_incr_backup_time_since_completion_seconds* - Time since completion of last pgBackRest INCREMENTAL backup. Note that both FULL and DIFFERENTIAL backups count as a successful INCREMENTAL for the given stanza.

 * *ccp_backrest_last_info_runtime_backup_runtime_seconds* - Last successful runtime of each backup type (full/diff/incr).

 * *ccp_backrest_last_info_repo_backup_size_bytes* - Actual size of only this individual backup in the pgbackrest repository

 * *ccp_backrest_last_info_repo_total_size_bytes* - Total size of this backup in the pgbackrest repository, including all required previous backups and WAL

 * *ccp_backrest_last_info_backup_error* - Count of errors tracked for this backup. Note this does not track incomplete backups, only errors encountered during the backup (checksum errors, file truncation, invalid headers, etc)

#### Per-Database Metrics

These are metrics that are only available on a per-database level. These metrics are found in the `queries_per_db.yml` file. These metrics are optional and recommended for the non-global, per-db postgres_exporter. They can be included in the global exporter as well if the global database needs per-database metrics monitored. Please note that depending on the number of objects in your database, collecting these metrics can greatly increase the storage requirements for Prometheus since all of these metrics are being collected for each individual object.

 * *ccp_table_size_size_bytes* - Table size inclusive of all indexes in that table

The following `ccp_stat_user_tables_*` metrics are statistics collected from the [pg_stat_user_tables](https://www.postgresql.org/docs/current/monitoring-stats.html#PG-STAT-ALL-TABLES-VIEW). Please see the PG documentation for descriptions of these metrics.

 * *ccp_stat_user_tables_analyze_count*

 * *ccp_stat_user_tables_autoanalyze_count*

 * *ccp_stat_user_tables_autovacuum_count*

 * *ccp_stat_user_tables_n_tup_del*

 * *ccp_stat_user_tables_n_tup_ins*

 * *ccp_stat_user_tables_n_tup_upd*

 * *ccp_stat_user_tables_vacuum_count*

#### Bloat Metrics

Bloat metrics are only available if the `pg_bloat_check` script has been setup to run. See instructions above. These metrics are found in the `queries_bloat.yml` file. These metrics are per-database so, should be used by the per-db postgres_exporter.

 * *ccp_bloat_check_size_bytes* - Size of object in bytes

 * *ccp_bloat_check_total_wasted_space_bytes* - Total wasted space in bytes of given object

#### pgBouncer Metrics

The following metric prefixes correspond to the SHOW command views found in the [pgBouncer documentation](https://www.pgbouncer.org/usage.html). Each column found in the SHOW view is a separate metric under the respective prefix. Ex: `ccp_pgbouncer_pools_client_active` corresponds to the `SHOW POOLS` view's `client_active` column.

sql_exporter can connect directly to pgBouncer with some specific configuration options set. See the example `sql_exporter.yml` and the `crunchy_pgbouncer_collector_###.yml` file.

 * *ccp_pgbouncer_pools* - SHOW POOLS

 * *ccp_pgbouncer_databases* - SHOW DATABASES

 * *ccp_pgbouncer_clients* - SHOW CLIENTS

 * *ccp_pgbouncer_servers* - SHOW SERVERS

 * *ccp_pgbouncer_lists* - SHOW LISTS

#### pg_stat_statements Metrics

Collecting all per-query metrics into Prometheus could greatly increase storage requirements and heavily impact performance. Therefore, the metrics below give simplified numeric metrics on overall statistics and Top N queries. N is set as the LIMIT value in the `crunchy_pg_stat_statements_collector.yml` collections file. If you would like to adjust this number, it is recommended to make a copy of this collection file and use that modified file in your sql_exporter collector file config instead.

Note that the statistics for individual queries can only be reset on PG12+. Prior to that, pg_stat_statements must have all statistics reset to redo the top N queries.

 * *ccp_pg_stat_statements_top_max_time_ms* -  Maximum time spent in the statement in milliseconds per database/user/query for the top N queries

 * *ccp_pg_stat_statements_top_mean_time_ms* - Average query runtime in milliseconds per database/user/query for the top N queries

 * *ccp_pg_stat_statements_top_total_time_ms* - Total time spent in the statement in milliseconds per database/user/query for the top N queries

 * *ccp_pg_stat_statements_total_calls_count* - Total number of queries run per user/database

 * *ccp_pg_stat_statements_total_mean_time_ms* - Mean runtime of all queries per user/database

 * *ccp_pg_stat_statements_total_row_count* - Total rows returned from all queries per user/database

 * *ccp_pg_stat_statements_total_time_ms* - Total runtime of all queries per user/database

### System {#system}

\*NIX Operating System metrics (Linux, BSD, etc) are collected using the [node_exporter](https://github.com/prometheus/node_exporter) provided by the Prometheus team. pgMonitor only collects the default metrics provided by node_exporter, but many additional metrics are available if needed.

### Suggested Optional Metrics

There are many other suggestions, projects, and exporters out there that can provide additional metrics not included by default with pgMonitor. Some recommendations are below

[https://docs.percona.com/pg-stat-monitor/](pg_stat_monitor) - Similar to pg_stat_statements, but provides deeper analysis on individual query statistics and performance. Note that this can greatly increase the metric storage requirements, but it can be extremely useful when trying to narrow down more complex query performance issues.

[https://www.ansible.com/blog/red-hat-ansible-tower-monitoring-using-prometheus-node-exporter-grafana/](Ansible Tower metrics) - Ansible Tower has a builtin exporter that can provide related metrics

## Legacy postgres_exporter Setup {#postgres-exporter}

If you had been using pgMonitor prior to version 5.0.0, postgres_exporter was the method used to collect PostgreSQL metrics. This exporter can still be used with 5.0.0, but there are some additional steps required. It is HIGHLY recommended to switch to using sql_exporter as soon as possible. Custom query support will be dropped from postgres_exporter at some point in the future and that will break pgMonitor since it relies solely on custom queries. No new features of pgMonitor are being developed around postgres_exporter.

Most of the installation steps are the same as above with the below differences for the relevant sections.

#### Available Packages

| Package Name                   | Description                                                               |
|--------------------------------|---------------------------------------------------------------------------|
| pgbouncer_fdw                  | Package for the pgbouncer_fdw extension. Only necessary when using postgres_exporter                                  |
| pgmonitor-pg-common            | Package containing postgres_exporter items common for all versions of PostgreSQL |
| pgmonitor-pg##-extras          | Crunchy-optimized configurations for postgres_exporter. Note that each major version of PostgreSQL has its own extras package (pgmonitor-pg13-extras, pgmonitor-pg14-extras, etc). |
| postgres_exporter              | Base package for postgres_exporter                                        |


#### Configuration File Installation

The files contained in this repository are assumed to be installed in the following locations with the following names. In the instructions below, you should replace a double-hash (`##`) with the two-digit major version of PostgreSQL you are running (ex: 12, 13, 14, etc.).

| pgMonitor Configuration File | System Location |
|------------------------------|-----------------|
| postgres_exporter/common/pg##/setup.sql | /etc/postgres_exporter/##/setup.sql  |
| postgres_exporter/common/pg##/queries*.yml | /etc/postgres_exporter/##/queries*.yml  |
| postgres_exporter/common/queries*.yml | /etc/postgres_exporter/##/queries*.yml  |
| postgres_exporter/linux/crontab.txt | /etc/postgres_exporter/##/crontab.txt  |
| postgres_exporter/linux/crunchy-postgres-exporter@.service | /usr/lib/systemd/system/crunchy-postgres-exporter@.service  |
| postgres_exporter/linux/pg##/sysconfig.postgres_exporter_pg## | /etc/sysconfig/postgres_exporter_pg##  |
| postgres_exporter/linux/pg##/sysconfig.postgres_exporter_pg##_per_db | /etc/sysconfig/postgres_exporter_pg##_per_db  |
| postgres_exporter/linux/queries_*.yml | /etc/postgres_exporter/##/queries_*.yml  |
| postgres_exporter/linux/pgbackrest-info.sh | /usr/bin/pgbackrest-info.sh |
| postgres_exporter/linux/pgmonitor.conf | /etc/pgmonitor.conf (multi-backrest-repository/container environment only) |

#### Service Configuration

The following files contain defaults that should enable the exporters to run effectively on your system for the purposes of using pgMonitor.  Please take some time to review them.

- {{< shell >}}/etc/sysconfig/postgres_exporter_pg##{{< /shell >}}
- {{< shell >}}/etc/sysconfig/postgres_exporter_pg##_per_db{{< /shell >}}

Note that {{< shell >}}/etc/sysconfig/postgres_exporter_pg##{{< /shell >}} & {{< shell >}}postgres_exporter_pg##_per_db{{< /shell >}} are the default sysconfig files for monitoring the database running on the local socket at /var/run/postgresql and connect to the "postgres" database. If you've installed the pgMonitor setup to a different database, modify these files accordingly or make new ones. If you make new ones, ensure the service name you enable references this file (see the Enable Services section below ).



#### Monitoring Setup

| Query File            | Description                                                                                              |
|-----------------------|----------------------------------------------------------------------------------------------------------|
| setup.sql    | Creates `ccp_monitoring` role with all necessary grants. Creates all necessary database objects (functions, tables, etc) required for monitoring.  |
| setup_metric_views.sql | Creates materialized views and maintenance objects for them. This feature is optional. See [Materialized View Metrics](#mat-view-metrics). |
| queries_bloat.yml     | postgres_exporter query file to allow bloat monitoring.                                                  |
| queries_global.yml    | postgres_exporter query file with minimal recommended queries that are common across all PG versions and only need to be run once per database instance.    |
| queries_global_dbsize.yml | postgres_exporter query file that contains metrics for monitoring database size. This is a separate file to allow the option to use a materialized view for very large databases |
| queries_global_matview.yml | postgres_exporter query file that contains alternative metrics that use materialized views of common metrics across all PG versions |
| queries_per_db.yml    | postgres_exporter query file with queries that gather per database stats. WARNING: If your database has many tables this can greatly increase the storage requirements for your prometheus database. If necessary, edit the query to only gather tables you are interested in statistics for. The "PostgreSQL Details" and the "CRUD Details" Dashboards use these statistics.                                                   |
| queries_per_db_matview.yml | postgres_exporter query files that contains alternative metrics that use materialized views of per database stats |
| queries_general.yml      | postgres_exporter query file for queries that are specific to the version of PostgreSQL that is being monitored.   |
| queries_backrest.yml | postgres_exporter query file for monitoring pgBackRest backup status. By default, new backrest data is only collected every 10 minutes to avoid excessive load when there are large backup lists. See sysconfig file for exporter service to adjust this throttling. |
| queries_pgbouncer.yml | postgres_exporter query file for monitoring pgbouncer. |
| queries_pg_stat_statements.yml | postgres_exporter query file for specific pg_stat_statements metrics that are most useful for monitoring and trending. |


By default, there are two postgres_exporter services expected to be running. One connects to the default {{< shell >}}postgres{{< /shell >}} database that most PostgreSQL instances come with and is meant for collecting global metrics that are the same on all databases in the instance (connection/replication statistics, etc). This service uses the sysconfig file {{< shell >}}postgres_exporter_pg##{{< /shell >}}. Connect to this database and run the setup.sql script to install the required database objects for pgMonitor.

The second postgres_exporter service is used to collect per-database metrics and uses the sysconfig file {{< shell >}}postgres_exporter_pg##_per_db{{< /shell >}}. By default it is set to also connect to the {{< shell >}}postgres{{< /shell >}} database, but you can add as many additional connection strings to this service for each individual database that you want metrics for. Per-db metrics include things like table/index statistics and bloat. See the section below for monitorig multiple databases for how to do this.

Note that your pg_hba.conf will have to be configured to allow the {{< shell >}}ccp_monitoring{{< /shell >}} system user to connect as the {{< shell >}}ccp_monitoring{{< /shell >}} role to any database in the instance. As of version 4.0 of pg_monitor, the postgres_exporter service is set by default to connect via local socket, so passwordless local peer authentication is the expected default. If password-based authentication is required, we recommend using SCRAM authentication, which is supported as of version 0.7.x of postgres_exporter. See our blog post for more information on SCRAM - https://info.crunchydata.com/blog/how-to-upgrade-postgresql-passwords-to-scram

postgres_exporter only takes a single yaml file as an argument for custom queries, so this requires concatenating the relevant files together. The sysconfig files for the service help with this concatenation task and define the variable {{< yaml >}}QUERY_FILE_LIST{{< /yaml >}}. Set this variable to a space delimited list of the full path names to all files that contain queries you want to be in the single file that postgres_exporter uses.

For example, to use just the common queries for PostgreSQL 12 modify the relevant sysconfig file as follows:

```bash
QUERY_FILE_LIST="/etc/postgres_exporter/12/queries_global.yml /etc/postgres_exporter/12/queries_general.yml"
```

As an another example, to include queries for PostgreSQL 13 as well as pgBackRest, modify the relevant sysconfig file as follows:

```bash
QUERY_FILE_LIST="/etc/postgres_exporter/13/queries_global.yml /etc/postgres_exporter/13/queries_general.yml /etc/postgres_exporter/13/queries_backrest.yml"
```

For replica servers, the setup is the same except that the setup.sql file does not need to be run since writes cannot be done there and it was already run on the primary.

#### Materialized View Metrics {#mat-view-metrics}

With large databases/tables and some other conditions, certain metrics can cause excessive load. For those cases, materialized views and alternative metric queries have been made available. The materialized views are refreshed on their own schedule independent of the Prometheus data scrape, so any load that may be associated with gathering the underlying data is mitigated. A configuration table, seen below, contains options for how often these materialized views should be refreshed. And a single procedure can be called to refresh all materialized views relevant to monitoring.

For every database that will be collecting materialized view metrics, you will have to run the {{< shell >}}setup_metric_views.sql{{< /shell >}} file against that database. This will likely need to be run as a superuser and must be run after running the base setup file mentioned above to create the necessary monitoring user first.
```
psql -U postgres -d alphadb -f setup_metric_views.sql
psql -U postgres -d betadb -f setup_metric_views.sql
```
The {{< shell >}}/etc/postgres_exporter/##/crontab.txt{{< /shell >}} file has an example entry for how to call the refresh procedure. You should modify this to run as often as you need depending on how recent you need your metric data to be. This procedure is safe to run on the primary or replicas and will safely exit if the database is in recovery mode.

Configuration table {{< shell >}}monitor.metric_views{{< /shell >}}:

|       Column       |       Description                                                |
|--------------------|------------------------------------------------------------------|
| view_schema     | Schema containing the materialized view |
| view_name       | Name of the materialized view |
| concurrent_refresh | Boolean that sets whether this materialized view can be refreshed concurrently (requires a unique index) |
| run_interval       | How often this materialized view should have its data refreshed. Must be a value compatible with the PG interval type   |
| last_run           | Timestamp of the last time this view was refreshed |
| active             | Boolean that sets whether this view should be refreshed when the procedure is called |
| scope              | Whether the data contained in the view is per-database or instance-wide. Currently unused |

You are also free to use this materialized view system for your own custom metrics as well. Simply make a materialized view, add its name to the configuration table and ensure the user running the refresh has permissions to do so for your view(s).

##### PGBouncer

In order to monitor pgbouncer with postgres_exporter, the pgbouncer_fdw maintained by CrunchyData is required. Please see its repository for full installation instructions. A package for this is available for Crunchy Data customers.

https://github.com/CrunchyData/pgbouncer_fdw

Once that is working, you should be able to add the {{< shell >}}queries_pgbouncer.yml{{< /shell >}} file to the {{< yaml >}}QUERY_FILE_LIST{{< /shell >}} for the exporter that is monitoring the database where the FDW was installed.

#### Enable Services

To most easily allow the use of multiple postgres exporters, running multiple major versions of PostgreSQL, and to avoid maintaining many similar service files, a systemd template service file is used. The name of the sysconfig EnvironmentFile to be used by the service is passed as the value after the "@" and before ".service" in the service name. The default exporter's sysconfig file is named "postgres_exporter_pg##" and tied to the major version of postgres that it was installed for. A similar EnvironmentFile exists for the per-db service. Be sure to replace the ## in the below commands first!

```bash
sudo systemctl enable crunchy-postgres-exporter@postgres_exporter_pg##
sudo systemctl start crunchy-postgres-exporter@postgres_exporter_pg##
sudo systemctl status crunchy-postgres-exporter@postgres_exporter_pg##

sudo systemctl enable crunchy-postgres-exporter@postgres_exporter_pg##_per_db
sudo systemctl start crunchy-postgres-exporter@postgres_exporter_pg##_per_db
sudo systemctl status crunchy-postgres-exporter@postgres_exporter_pg##_per_db
```
#### Monitoring multiple databases and/or running multiple postgres exporters (RHEL)

Certain metrics are not cluster-wide, so multiple exporters must be run to avoid duplication when monitoring multiple databases in a single PostgreSQL instance. To collect these per-database metrics, an additional exporter service is required and pgMonitor provides this using the following query file: ({{< shell >}}queries_per_db.yml{{< /shell >}}). In Prometheus, you can then define the global and per-db exporter targets for a single job. This will place all the metrics that are collected for a single database instance together.

{{< note >}}The "setup.sql" file does not need to be run on these additional databases if using the queries that pgMonitor comes with.{{< /note >}}

pgMonitor provides and recommends an example sysconfig file for this per-db exporter: {{< shell >}}sysconfig.postgres_exporter_pg##_per_db{{< /shell >}}. If you'd like to create additional exporter services for different query files, just copy the existing ones and modify the relevant lines, mainly the port, database name, and query file. The below example shows connecting to three databases in the same instance to collect their per-db metrics: `postgres`, `mydb1`, and `mydb2`.
```
OPT="--web.listen-address=0.0.0.0:9188 --extend.query-path=/etc/postgres_exporter/14/queries_per_db.yml"
DATA_SOURCE_NAME="postgresql:///postgres?host=/var/run/postgresql/&user=ccp_monitoring&sslmode=disable,postgresql:///mydb1?host=/var/run/postgresql/&user=ccp_monitoring&sslmode=disable,postgresql:///mydb2?host=/var/run/postgresql/&user=ccp_monitoring&sslmode=disable"
```
As was done with the exporter service that is collecting the global metrics, also modify the {{< yaml >}}QUERY_LIST_FILE{{< /yaml >}} in the new sysconfig file to only collect per-db metrics
```
QUERY_FILE_LIST="/etc/postgres_exporter/14/queries_per_db.yml"
```

Since a systemd template is used for the postgres_exporter services, all you need to do is pass the sysconfig file name as part of the new service name.
```
sudo systemctl enable crunchy-postgres-exporter@postgres_exporter_pg14_per_db
sudo systemctl start cruncy-postgres-exporter@postgres_exporter_pg14_per_db
sudo systemctl status crunchy-postgres-exporter@postgres_exporter_pg14_per_db

```
Lastly, update the Prometheus auto.d target file to include the new exporter in the same job you already had running for this system

#### General Metrics

*pg_up* -  Database is up and connectable by metric collector. This metric is only available with postgres_exporter
