---
title: "Changelog"
draft: false
weight: 5
---
## 4.2

### New Features

  * Add support for PostgreSQL 12
  * Added new metrics (all PG versions):
    * ccp_postmaster_uptime - time in seconds since last restart of PG instance. Useful for monitoring for unexpected restarts.
    * ccp_settings_checksum - monitors for changes in pg_settings and/or pg_hba.conf
        * Replica settings monitoring can be done as well, but history tracking is not possible since writing to a log table is impossible. Also, if the configuration differs from the primary, hashes must be manually set for that postgres_exporter's sysconfig to pass along to the underlying function.
        * Note that pg_hba.conf monitoring is only supported in PG10+
  * Added new metrics (PG 9.5+ only)
    *  ccp_settings_pending_restart - monitors for any settings in pg_settings in a pending_restart state
  * Added new metrics (PG 12+ only)
    * ccp_data_checksum_failure - monitors for any errors encountered for databases that have data file checksums enabled
  * (Bugfix) Use proper comparison operators in all Grafana dashboards that are using Multi-value variables. Ensures proper values in all dropdown menus are shown
  * (Bugfix) Remove changing background color of the pgBackRest panel in the PG_Details Grafana dashboard

### Non-backward Compatible Changes

  * None

### Manual Intervention Changes

 * In order to use the new metrics that are available, the setup_##.sql script must be run again for your relevant version of PostgreSQL. Then all postgres_exporters services must be restarted.
 * The only new rule that has been enabled by default in the Crunchy provided Prometheus rules file is `ccp_settings_pending_restart`. All other new metrics have example rules in the same file but they are commented out. Please adjust them as needed before uncommenting and using them.


## 4.1

 * Fixed bug in PGBouncer Grafana dashboard for the Server Connection Counts Per Pool showing zero data
 * Fixed Windows prometheus config file to use proper wildcard to pick up .yml files.
 * Renamed Prometheus target example file to include yml extention to better ensure it is not missed. ReplicaOS.example to ReplicaOS.yml.example
 * Fixed documentation to display pictures properly.

## 4.0

### New Features

 * Add pgbouncer monitoring support 
    * Requires new `pgbouncer_fdw` extension provided by Crunchy Data: https://github.com/CrunchyData/pgbouncer_fdw
    * New query file can be included in QUERY_FILE_LIST: queries_pgbouncer.yml
    * New Grafana dashboard: PGBouncer.json

 * Minimum version of postgres_exporter required is now 0.5.1
    * Allows connecting to multiple databases from a single exporter, however only one query file can be set per exporter service
    * If statistics are needed for per-database metrics on more than one database, recommend running a second exporter (example included as `sysconfig.postgres_exporter_pg##_per_db`) that connects to all dbs where such stats are required using separate custom query file. Leave the main exporter service to only collect global metrics from one database (preferably `postgres`).
    * DO NOT yet recommend using new `--auto-database-discovery` feature. Currently tries to connect to template databases which is never recommended.

 * Added backup sizes to pgBackRest metrics that are collected by default
    * Updated pgBackRest grafana dashboard to include size graphs. Also added per-stanza dropdown filter to the top of dashboard for better readability when there are many backups.

 * Added new metric to check what version of PostgreSQL the exporter is currently running on (`ccp_postgresql_version_current`). 

### Non-backward Compatible Changes

 * Version 0.5x of postgres_exporter adds a new "server" label to all custom query output metrics. This breaks several single panel graphs that pgmonitor uses in Grafana (PG Overview, PGBackrest). 
    * If upgrading, the update for the prometheus extras package must be done before upgrading to the new version of postgres_exporter. Otherwise the "server" label can cause duplication of some metrics.
    * Added a metric_relabel_configs line to the crunchy-prometheus.yml file to filter out this new label. If you are upgrading, you may have to manually add this to your own prometheus config. The package update will only automatically add this if you haven't changed the default file. Otherwise the new settings will be contained in a crunchy-prometheus.yml.rpmnew file in the package install location.

### Manual Intervention Changes

 * See Non-backward Compatible Changes section for update that may need to be done to prometheus config.

 * Changed default DATA_SOURCE_NAME value for postgres_exporter to use the local socket for the ccp_monitoring role. This should allow the exporter to work using peer authentication, which is the default authentication method allowed by most rpm/deb provided postgres packages. This should not change any existing installations, but may affect new deployments due to new default behavior.

 * Split Prometheus crunchy-alert-rules.yml file into separate node & postgres alert files to allow for more flexible rule management.
    * By default alert rules files are now looked for in `/etc/prometheus/alert-rules.d/`. Any alert files located in this folder upon restart/reload will then be picked up automatically.
    * Renamed alert files in repository to have additional .example file extension.
    * IMPORTANT UPGRADE NOTE: If upgrading with packages, prometheus may change and point to the new rules location causing your active alerts to change. Your custom alert rules have not been lost, just ensure your desired rules file(s) are moved to the new location for future compatability.

    * Changed metric name `ccp_backrest_last_runtime` to `ccp_backrest_last_info` to reflect that it is no longer only collecting runtime stats. Note that due to metric name change, you will appear to have lost runtime history in the new grafana dashboard. The data is still there under the old metric name and can be added back as an additional data point if needed.

    * Fixed prometheus disk sizing rules to properly include ext filesystems (ext[234]). The correct syntax for the sizing-based rules is contained in the example rule files that the package provides. You will need to copy them to your current rule files if applicable.

### Bug Fixes

 * Disable pg_settings values that are exported by default with postgres_exporter. Fixes issue with multi-dsn support in 0.5.1 of postgres_exporter. If settings are desired as output from exporter, it is recommended to add a custom query.

 * Fixed postgres_exporter service file to better parse out the destination query file name (exporter/postgres/crunchy-postgres-exporter@.service or exporter/postgres/crunchy-postgres-exporter-pg##-el6.service). Previously if any additional options were added to the OPT variable in the sysconfig, the service could throw errors on start. If you've customized your service file, please make note of changes for future compatability.

 * Update Grafana Overview dashboard to be compatible with Grafana 6.4+


## 3.2

 * Fixed postgres_exporter service in EL6 (Redhat/CentOS) to properly use the backrest throttle environment variable in sysconfig (Github Issue #107).


## 3.1

 * Fix broken links in Grafana OS & PG Overview Dashboards
 * Updated UPGRADE steps in 3.0 release notes for new exporter service name setup. Need to re-enable service with new name and manually remove old symlink files.
 * Update documentation for exporter setup to use new service names


## 3.0
  
 * New minimum version requirements for software that is part of pgmonitor are as follows, including links to release notes:
    * Prometheus: 2.9.2 - https://github.com/prometheus/prometheus/releases
    * Alertmanager: 0.17.0 - https://github.com/prometheus/alertmanager/releases
    * Grafana: 6.1.6 (major version change from 5.x) - https://community.grafana.com/t/release-notes-v6-1-x/15772
    * node_exporter: 0.18.0 - https://github.com/prometheus/node_exporter (Note breaking changes for some metrics. None of those broken are used by default in pgmonitor).

* The service file for postgres_exporter provided by pgmonitor has been renamed to make it more consistent with typical systemd service names. 
    * IMPORTANT: See upgrade notes below about changes to sysconfig file before restarting service!
    * Only applies to systemd file for RHEL/CentOS 7
    * Changed crunchy_postgres_exporter@.service to crunchy-postgres-exporter@.service (underscores to dashes).
    * Note that you will need to use the new service name to interact with it from now on. This requires enabling the new service name and restarting it:
        * `systemctl enable crunchy-postgres-exporter@postgres_exporter_pg11`
        * `systemctl restart crunchy-postgres-exporter@postgres_exporter_pg11`
    * Due to the removal of the old service file, you cannot use systemctl to disable the old service. Instead just remove the symlinks manually:
        * `rm /etc/systemd/system/multi-user.target.wants/crunchy_postgres_exporter@*

 * The single query.yml file used by postgres_exporter to use Crunchy's custom queries is now dynamically generated automatically upon service start/restart.
    * A new variable, QUERY_FILE_LIST, is now set in the sysconfig file for the service. It is a space delimited list of the full paths to all query files that will be concatenated together. See sysconfig file for several examples and a recommended default to set.
    * This now ensures that any updates to desired query files will be automatically applied when the package is updated and the service is restarted without having to manually rebuild the query.yml file.
    * This new variable is not required and you can continue to manually manage your queries.yml file. Ensure that the QUERY_FILE_LIST variable is not set if this is desired.
    * UPGRADE NOTES: 
        * Backup your current queries.yml file.
        * If you have not modified the default sysconfig file for your postgres_exporter service (/etc/sysconfig/postgres_exporter_pg##), updating to 3.0 will overwrite your current sysconfig file and put the default QUERY_FILE_LIST value in place, possibly overwriting your current queries.yml file. Again, please ensure you backup your current queries.yml file and then set the QUERY_FILE_LIST variable appropriately to dynamically generate your queries file for you in the future. Or unset the variable and continue managing it manually.
        * If you have modified your sysconfig file from what the package provides, it will not be overwritten and a new sysconfig file with an `.rpmnew` extension will be created. You can reference this .rpmnew file for how to update your sysconfig file to take advantage of the new QUERY_FILE_LIST option.
        * Ensure all postgres_exporters you have running set the QUERY_FILE_LIST properly if using it. Especially if multiple exporters are using the same query file.

 * Prometheus targets for pgmonitor provided exporters (postgres_exporter & node_exporter) have had labels added to them for use in pgmonitor provided Grafana Dashboards. 
    * Added new label `exp_type` (export type) in prometheus targets to better distinguish OS and Postgres metrics in Prometheus. Possible current values are `pg` or `node`.
    * UPGRADE NOTES: This new label must be applied to your Prometheus target files if you are using the Grafana dashboards provided by pgmonitor. Note that if you previously defined node and postgres_exporter targets under a single target, you will now need to separate them, keeping the same job name for both. See example target files provided in package/repo for how to apply new label (Ex. ProductionDB.yml.example & ProductionOS.yml.example).
    * If you are not using the pgmonitor provided Grafana dashboards, these new labels are optional.

 * Grafana Dashboards Updates
    * New dashboards require at least Grafana 6.x.
    * UPGRADE NOTES: Once new Prometheus label (mentioned above) is applied, dashboard provisioning should take care of updating all dashboards once the new ones are in place. Note that all dashboards provided by pgmonitor 3.0+ now assume this new label and will not work until the Prometheus exp_type label is added.
    * Renamed dashboard files for better naming consistency. Dashboard titles also updated accordingly.
        * UPGRADE NOTES: If installing from package, it will take care of care of renaming dashboard files. Otherwise, dashboards have been renamed as follows below. Ensure old files are renamed/removed to avoid duplicating/breaking current dashboards. Easiest manual update method is to remove all dashboards provided by pgmonitor and copy all new ones back. Provisioning will then take care of updating things for you.
        * renamed:  BloatDetails.json -> Bloat_Details.json
        * renamed:  FilesystemDetails.json -> Filesystem_Details.json
        * renamed:  PostgreSQLDetails.json -> PG_Details.json
        * renamed:  PostgreSQL.json -> PG_Overview.json
        * renamed:  TableSize_Detail.json -> TableSize_Details.json
    * Dashboard names have been updated to match with new naming consistency. If you had direct links to dashboards, these may need to be updated.
    * Split OS Metrics into their own dashboard separate from PG Metrics. 
    * Added link to PGbackrest dashboard to top of Postgres Details Dashboard. Link shows time since last successful backup (any type) for that target system.
    * Added new OS Details dashboard
    * Added new etcd dashboard
    * Add new Top Level Overview dashboard that links to all other Overview dashboards
    * Set default refresh rate for most dashboards to 15 minutes.
    * Obsolete "jobname" grafana variable in all dashboards. Add new grafana variables pgnodes, osnodes that use the new labels added in prometheus targets notded above.

* New configuration option for postgres_exporter sysconfig file to control PGBackrest refresh rate
    * PGBACKREST_INFO_THROTTLE_MINUTES
    * This is the value, in minutes, passed along to the monitor.pgbackrest_info() function in all backrest checks
    * Default is 10 minutes


## 2.4

* UPGRADE NOTE: All exporter issues below can be fixed by re-running the setup_pg##.sql file for your major version of postgres. For the pgbackrest fix, you will also need to update the queries.yml file for the exporter to include the new queries found in the queries_backrest.yml file.
 * Fixed several issues with pgbackrest monitor in postgres_exporter that was included in pgmonitor v2.3
   * Fixed incorrect data being returned by monitor query on PostgreSQL 9.6 and earlier. The same, latest backup time was being returned for all stanzas instead of returning the time per stanza.
   * Fixed backrest query causing the postgres_exporter to hang and cause all metric output to stop.
   * Fixed backrest monitor to work with larger amount of data being returned by the "pgbackrest info" command. Previously, once returned data size reached a certain point, would cause a "missing chunk" error.
   * Added a parameter to the function that is called to control how often the underlying info command is actually run. On systems with high backup counts, info can be a slightly more expensive call. This helps to control that, no matter what the scrape interval of prometheus is set to. Default is to get new data every 10 minutes, otherwise just queries from an internal table that stores the last info run. 
   * Backrest monitoring can now be run on replicas as well, but cannot update the current backup status since that requires writing to the database. This is mostly to enable monitoring setups to be consistent between primary/replica in case of failover.
 * Fixed issue with ccp_sequence_exhaustion metric that would cause postgres_exporter output to hang if any table that contained a sequence was dropped during a long running transaction.
 * Added new metric (ccp_replication_slots) and alert (PGReplicationSlotsInactive) for monitoring replication slot status. New metric and alert can be found in queries_pg##.yml and crunchy-alert-rules.yml respectively.
 * Added lock_timeout of 2 minutes to the ccp_monitoring role. Avoids monitoring causing any extensive lock interference with normal database operations.
 * Added Grafana Dashboard for PGBackrest status information.
 * Fixed lines being hidden in the "Total Bloat %" graph in BloatDetails Grafana dashboard.
 * Removed unnecessary drilldown link in Total Bloat % graph in BloatDetails Grafana dashboard.


## 2.3

 * Fixed bug in Prometheus alerts that was causing some of them to be stuck in PENDING mode indefinitely and never firing. This unfortunately removes the current alert value from the Grafana Prometheus Alerts dashboard.
   * If you can't simply overwrite your current alerts configuration file with the one provided, remove the following option from every alert: `alert_value: '{{ $value }}'`
 * Added feature to monitor pgbackrest backups (https://pgbackrest.org)
   * Separate metrics exist to monitor for the latest full, incremental and/or differential backups. Note that a full will always count as both an incremnetal and diff and a diff will always count as an incremental.
   * Another metric can monitor the runtime of the latest backup of each type per stanza.
   * Run the setup_pg##.sql file again in the database that your exporter(s) connect to to install the new, required function: "monitor.pgbackrest_info()". It has security definer so execution privileges can be granted as needed, but it must be owned by a superuser.
   * New metrics are located in the exporter/postgres/queries_backrest.yml file. Add the one(s) you want to the main queries file being used by your currently running exporter(s) and restart.
   * Example alert rules for different backup scenarios have been added to the prometheus/crunchy-alert-rules.yml file. They are commented out to avoid false alarms until valid backup settings for your environment are in place. 

 * Added new feature to monitor for failing archive_command calls.
    * New metric "ccp_archive_command_status" is located in exporter/postgres/queries_common.yml. Add this to the main queries file being used by your currently running exporter(s) and restart.
    * A new alert rule "PGArchiveCommandStatus" has been added to the prometheus/crunchy-alert-rules.yml file.

* Added new feature to monitor for sequence exhaustion
    * Requires installation of a new function located in the setup_pg##.yml file for your relevant major version of PostgreSQL. Must be installed by a superuser.
    * New metric "ccp_sequence_exhaustion" located in exporter/postgres/queries_common.yml. Add this to the main queries file being used by your currently running exporter(s) and restart.
    A new alert rule "PGSequenceExhaustion" has been added to the prometheus/crunchy-alert-rules.yml file.

 * The setup_pg##.sql file now has logic to avoid throwing errors when the ccp_monitoring role already exists. Also always attempts to drop the functions it manages first to account for when the function signature changes in ways that OR REPLACE doesn't handle. All this allows easier re-running of the script when new features are added or used in automation systems. Thanks to Jason O'Donnell for role logic.


## 2.2

 * Fixed broken ccp_wal_activity check for PostgreSQL 9.4 & 9.5. Updated check is located in the relevant exporter/postgres/queries_pg##.yml file
 * Fixed broken service files for postgres_exporter on RHEL6 systems.
 * Removed explicit "public" schema in ccp_bloat_check query so that it will properly use the search_path in case bloat tables were installed in another schema
 * Removed query files for PostgreSQL versions no longer supported by pgmonitor (9.2 & 9.3)


## 2.1
 * **IMPORTANT UPGRADE NOTE FOR CRUNCHY PACKAGE USERS**: In version 2.0, the Crunchy provided extras for node_exporter were split out from the pgmonitor-pg##-extras package. A dependency was kept between these packages to make upgrading easier. For 2.1, the dependency between these packages has been removed. When upgrading from 1.7 or earlier, if you have node_exporter and postgres_exporter running on the same systems, ensure that you install the separate pgmonitor-node_exporters_extras package after the update. See the README for the full package name(s).

 * Minimum required versions of software used in pgmonitor have been updated to:
   * Prometheus 2.5.0
   * Prometheus Alertmanager 0.15.3
   * postgres_exporter 0.4.7 (enables full PG11 support)
   * Grafana 5.3.4.
 * Fixed Grafana data source to use the "proxy" mode instead of "direct" with default install. Should fix connection issues encountered during default setup between Grafana & Prometheus.
 * Renamed functions_pg##.sql file to setup_pg##.sql to better clarify what it's for (and because it's not just functions).
 * Added ccp_wal_activity metric to help monitor WAL generation rate.
   * For all PG versions, provides total current size of WAL directory. For PG10+, it also provides the size of WAL generated in the last 5 minutes
   * Note that for PG96 and lower, a new security definer function must be added (can just run setup_pg##.sql again).
   * New metric definition is located in the queries_pg##.yml file.
   * No default rules have been added since this is very use-case dependent.
 * Improved accuracy of "Idle In Transaction" monitoring times in PostgreSQL. Base the time measured on the state change of the session vs the total transaction runtime.
 * Split setup_pg92-96.sql and queries_pg92-96.sql into individual files per major version.
 * Added commented out example prometheus alert rule for checking if a postgres database has changed from replica to primary or vice versa. Must be set on a per system basis since you have to tell it if a system is supposed to be a primary or replica.
 * Removed pg_stat_statements prometheus metric and security definer function from setup script. We highly recommend having pg_stat_statements installed on a database, and we still include its installation in the documentation, but we currently don't have any useful metric recommendations from it to collect in prometheus.
 * Added some default filters for the bloat check cronjob to avoid unnecessary waste in the prometheus storage of bloat metrics.
 * Update documentation.


## 2.0
 * Recommended version of Prometheus is now 2.3.2. Recommended version of Alertmanager is 0.15.1. Recommended version of postgres_exporter is 0.4.6.
 * Upgrade required version of node_exporter to minimum of 0.16.0. Note that many of the metrics that are used in Grafana and Prometheus alerting have had their names changed.
   * This version adds these new metrics into Grafana graphs without removing the old metric names on most, but not all, graphs. This allows trending history to be kept. Note that line colors will change in graphs and legend names will be duplicated until the old metric data is expired out.
   * Prometheus alerts have been set to use the new metric names since the alerts are based only on recent values.
   * IMPORTANT: A future pgmonitor update will remove these old metric names from Grafana graphs, so please ensure these changes are accounted for in your architecture.
   * See full release notes for 0.16.0 - https://github.com/prometheus/node_exporter/releases/tag/v0.16.0
 * The postgres_exporter service no longer uses a symlink in /etc/sysconfig to point to a default "postgres_exporter" file. This was causing issues with several upgrade scenarios. New installation instructions now have the service pointing directly to the relevant sysconfig file for the major PostgreSQL version.
   * **IMPORTANT**: If you are using the default postgres_exporter service, you will need to update your service name so it uses the proper sysconfig file. See the README file for the new default service name in the "Enable Services" section and run the "enable" command found there. You should then also disable/remove the old service so it doesn't try to start again in the future.
 * The additional Crunchy provided configurations for node_exporter have been split out from the pgmonitor-pg##-extras package to the pgmonitor-node_exporter-extras package. This was done to allow multiple versions of the pg##-extras package to be installed with different major versions of Postgres. There is still currently a dependency that the node extras packages must be installed with the pg##-extras so that upgrading doesn't break existing systems. This dependency will be revisited in the future.
 * Removed the requirement for a shell script to monitor if the database is up and its status as either a primary or replica. Up status is now using the native "pg_up" metric from postgres_exporter and a new metric query was written for checking the recovery status of a system (ccp_is_in_recovery).
   * The PostgreSQL.json overview dashboard that used this metric has been redesigned. Unfortunately it can no longer be colored RED for down systems, only go colorless and say "DOWN". This is a known limitation of handling null metric values in Grafana and part of a larger fix coming in future versions - https://github.com/grafana/grafana/issues/11418
 * Upgrade required version of Grafana to minimum of 5.2.1.
   * All provided dashboards require this minimum version to work.
   * If you notice that links between the dashboards are broken after the upgrade, clear your browser's cache. The 301 redirects used between dashboards can get cached and they have changed in the new major version.
   * See extensive release notes for major version changes in Grafana - https://community.grafana.com/t/release-notes-v-5-1-x
 * Change Grafana datasource and dashboard installation to use provisioning vs manual setup via the web interface. Note this means that future updates to the provided datasources and dashboards must be done through config files as well. Or they can be saved as a new dashboard for more extensive customization.
 * Change recommended configuration for Grafana to use PostgreSQL as database backend. Updated installation documentation.
 * Added Prometheus Alerts Dashboard. Shows both active alerts and 1 week history in table format.
 * Removed Gauges from PostgreSQLDetails Dashboard. "Current" value was not being shown properly and gauges were misleading in their values depending on the time range chosen. For a quick glance to see if there are any problems, be sure to set your alert thresholds properly and use the new Prometheus Alerts Dashboard.
 * Added max_query_time metric to track long running queries in general. Also added an alert for that metric to crunchy prometheus alerts.
 * Added "IO Time Per Device in Seconds" graph to Filesystems dashboard.
 * Fixed Memory and Swap Graphs on PostgreSQLDetails dashboard to more accurately show used resources. History for these graphs before this upgrade is not being shown since it is no longer graphing the same data.
 * Crontabs are no longer PostgreSQL major version dependent at this time. Consolidated down to a single crontab file for all versions.
 * Removed unnecessary functions from functions_pg10.sql. All queries in queries_pg10.yml currently only require the pg_monitor system role to be granted and have been updated with this assumption.
 * Changed default cron runtime of pg_bloat_check to once a week on early morning weekend.
 * Change PostgreSQL overview dashboard to use background colors instead of gauges for better visibility.
 * Fixed permission issues with /etc/postgres_exporter folder to allow ccp_monitoring system user better control.


## 1.7
 * Fixed duplicate and incorrect replication byte lag queries. The one contained in queries_common.yml should not have been there. It should be in queries_pg92-96.yml, but there was also one already there. However, the one already in pg92-96 was incorrect since prior to PG10, it requires superuser/security definer to fully access replication statistics. Corrected the version specific file to have the correct query. Made the query in the pg10 file consistent. Ensure you update your generated queries.yml file with he new queries.
 * Fixed the PostgreSQLDetails.json dashboard to use the correct replication byte lag metric (referencing above fix). The easiest way to fix this is to delete this dashboard and re-import it. Otherwise, if you've made customizations you don't want to lose, you can grab the correct metric query from the updated dashboard gauge and edit your existing dashboard to use it.
 * The combination of the above two fixes corrects the pgmonitor setup being able to properly handle there being multiple replicas from a single primary. Previously this would cause postgres_exporter to throw duplicate metric errors.
 * Fixed the query in queries_bloat.yml to be able to properly handle if there was a bloat amount larger than max int4 bytes. Ensure you update your generated queries.yml file with the new query.


## 1.6
 * Fixed formatting bug in crunchy-prometheus.yml. Thanks to Doug Hunley for reporting the issue.


## 1.5
 * Add support for disabling built in queries in postgres_exporter 0.4.5. Also explicitly ignore these metrics via a prometheus filter so they're not ingested even if new option isn't used. This means that v1.5 of pgmonitor now requires 0.4.5 of postgres_exporter by default.
 * Improved exporter down alert to avoid unnecessary alerts for brief outages that resolve themselves quickly.
 *  Added new FilesystemDetails dashboard for grafana that is linked to from the Filesystem graph on PostgreSQLDetails.
 * Top level PostgreSQL grafana dashboard now identifies whether a system is read/write or readonly to better distinguish primary/replica systems.
 * Added instructions for non-packaged installation using pgmonitor configuration files.
 * Revised and better formatted README documentation


## 1.4
 * Fixed filesystem graphs in PostgreSQLDetails dashboard
 * Cosmetic changes to PostgreSQLDetails dashboard
 * Added instructions for importing dashboards via Grafana API


## 1.3
 * Fixed error in PG10 queries file.
 * Fixed disk usage alert for prometheus to work better when there are many jobs with similar mountpoints. Also fixed syntax error in warning alert.
 * Moved connection stats query from common to version specific queries due to PG10 differences. Clarified naming of files for which versions they work for.
 * Added dropdown for the Job to the lower level drill down dashboards in Grafana. Allows selecting of a specific system from the dashboard itself without having to click through on a higher level.
 * Removed pg_stat_statements graph from PostgreSQLDetails dashboard. Needs refinement to make it more useful.


## 1.2
 * Change service and sysconfig files to use single OPT environment variable instead of one variable per cmd option
 * Fix error in PG10 monitoring functions file
 * Initial version of Prometheus 2.0 job deletion script. Requires API call not available yet in 2.0.0 for full functionality


## 1.1
 * Implement rpmnew/rpmsave feature instead of using .example files to prevent package overwriting user changes to configs


## 1.0
 * Initial stable release
