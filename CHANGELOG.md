### 2.2

 * Fixed broken ccp_wal_activity check for PostgreSQL 9.4 & 9.5. Updated check is located in the relevant exporter/postgres/queries_pg##.yml file
 * Fixed broken service files for postgres_exporter on RHEL6 systems.
 * Removed explicit "public" schema in ccp_bloat_check query so that it will properly use the search_path in case bloat tables were installed in another schema 
 * Removed query files for PostgreSQL versions no longer supported by pgmonitor (9.2 & 9.3)


### 2.1 
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


### 2.0
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


### 1.7
 * Fixed duplicate and incorrect replication byte lag queries. The one contained in queries_common.yml should not have been there. It should be in queries_pg92-96.yml, but there was also one already there. However, the one already in pg92-96 was incorrect since prior to PG10, it requires superuser/security definer to fully access replication statistics. Corrected the version specific file to have the correct query. Made the query in the pg10 file consistent. Ensure you update your generated queries.yml file with he new queries.
 * Fixed the PostgreSQLDetails.json dashboard to use the correct replication byte lag metric (referencing above fix). The easiest way to fix this is to delete this dashboard and re-import it. Otherwise, if you've made customizations you don't want to lose, you can grab the correct metric query from the updated dashboard gauge and edit your existing dashboard to use it.
 * The combination of the above two fixes corrects the pgmonitor setup being able to properly handle there being multiple replicas from a single primary. Previously this would cause postgres_exporter to throw duplicate metric errors.
 * Fixed the query in queries_bloat.yml to be able to properly handle if there was a bloat amount larger than max int4 bytes. Ensure you update your generated queries.yml file with the new query.

 
### 1.6
 * Fixed formatting bug in crunchy-prometheus.yml. Thanks to Doug Hunley for reporting the issue.


### 1.5
 * Add support for disabling built in queries in postgres_exporter 0.4.5. Also explicitly ignore these metrics via a prometheus filter so they're not ingested even if new option isn't used. This means that v1.5 of pgmonitor now requires 0.4.5 of postgres_exporter by default.
 * Improved exporter down alert to avoid unnecessary alerts for brief outages that resolve themselves quickly.
 *  Added new FilesystemDetails dashboard for grafana that is linked to from the Filesystem graph on PostgreSQLDetails.
 * Top level PostgreSQL grafana dashboard now identifies whether a system is read/write or readonly to better distinguish primary/replica systems.
 * Added instructions for non-packaged installation using pgmonitor configuration files.
 * Revised and better formatted README documentation


### 1.4
 * Fixed filesystem graphs in PostgreSQLDetails dashboard
 * Cosmetic changes to PostgreSQLDetails dashboard
 * Added instructions for importing dashboards via Grafana API


### 1.3
 * Fixed error in PG10 queries file. 
 * Fixed disk usage alert for prometheus to work better when there are many jobs with similar mountpoints. Also fixed syntax error in warning alert.
 * Moved connection stats query from common to version specific queries due to PG10 differences. Clarified naming of files for which versions they work for.
 * Added dropdown for the Job to the lower level drill down dashboards in Grafana. Allows selecting of a specific system from the dashboard itself without having to click through on a higher level.
 * Removed pg_stat_statements graph from PostgreSQLDetails dashboard. Needs refinement to make it more useful.


### 1.2
 * Change service and sysconfig files to use single OPT environment variable instead of one variable per cmd option
 * Fix error in PG10 monitoring functions file
 * Initial version of Prometheus 2.0 job deletion script. Requires API call not available yet in 2.0.0 for full functionality


### 1.1
 * Implement rpmnew/rpmsave feature instead of using .example files to prevent package overwriting user changes to configs


### 1.0
 * Initial stable release
