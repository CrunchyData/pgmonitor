=======================
pgMonitor Release Notes
=======================

.. contents:: Topics


v5.0.0
======

Release Summary
---------------

Crunchy Data is pleased to announce the availability of pgMonitor 5.0.0. This release brings support for a new Prometheus exporter for PostgreSQL - sql_exporter. It also supports a new monitoring extension to make metric collection easier and more performant. This changelog contains all changes that have been added since the 4.11.0 release.

Major Changes
-------------

- grafana - Add new dashboards for sql_exporter support. New PostgreSQL Overview and PgBouncer direct metrics dashboards
- grafana - New Grafana minimum version is now 10.4. All dashboards have been updated to fix AngularJS deprecation warnings and re-exported from 10.4.
- grafana - Organize packages to allow better choice of available Grafana dashboards
- grafana - Remove top level general Overview dashboard
- pgmonitor-extension - Add more extensive support for materialized views and refreshed tables for expensive or custom metric queries
- pgmonitor-extension - Add support for using the PostgreSQL pgmonitor-extension to aid in metrics collection with sql_exporter
- postgres_exporter - Note that postgres_exporter is still supported but will be deprecated in a future version
- sql_exporter - Add support for directly connecting to PgBouncer to collect metrics
- sql_exporter - Add support for new PostgreSQL metrics collecting exporter (sql_exporter)

Minor Changes
-------------

- prometheus - Added OOMKiller Alert using node_exporter metrics

Bugfixes
--------

- docs - add reference links to upstream configuration docs
- exporter - fix the pgbackrest-info.sh to force the necessary console output level that it expects
- grafana - fix some queries that were searching on the wrong label (datname vs. dbname)
- sql_exporter - add new metric for n_tup_newpage_upd
- sql_exporter - use the new views from pgmonitor-extension instead of full queries

v4.11.0
=======

Release Summary
---------------

Crunchy Data is pleased to announce the availability of pgMonitor 4.11.0. This release primarily updates support for the underlying applications to more recent versions. This changelog contains all changes that have been added since the 4.10.0 release.

Minor Changes
-------------

- alertmanager - minimum version 0.23, maximum 0.26.x
- blackbox_exporter - minimum version 0.22.x, maximum 0.24.x
- grafana - minimum version 9.2.19, maximum 9.9.x
- node_exporter - minimum version 1.5.0, maximum 1.7.x
- postgres_exporter - minimum version 0.10.1, maximum 0.15.x
- prometheus - minimum version 2.38, maximum 2.49.x

v4.10.0
=======

Release Summary
---------------

Crunchy Data is pleased to announce the availability of pgMonitor 4.10.0. This release primarily adds support for PostgreSQL 16. This changelog contains all changes that have been added since the 4.9.0 release.

Major Changes
-------------

- postgres_exporter - Add support for PostgreSQL 16

Minor Changes
-------------

- containers - The datasource for containers is named PROMETHEUS. Update dashboards to use the hardcoded name.
- grafana - Adjust the cache hit graph to do a 1m rate vs lifetime ratio
- grafana - Relabel the cache hit ratio dial properly mark it as the lifetime cache hit ratio

v4.9.0
======

Release Summary
---------------

Version 4.9.0 of pgMonitor includes updates to add additional metrics and now better supports monitoring multiple pgbouncer hosts. Please see the full CHANGELOG for additional information about this release.

Major Changes
-------------

- postgres_exporter - Added options for using materialized views to collect metrics that may cause longer query runtimes (object sizing, statistics, etc)
- postgres_exporter - Moved the database size metric out of the 'queries_global.yml' file and into the 'queries_global_dbsize.yml' file to allow an optional materialized view metric. Ensure query file configuration list is updated to account for this change

Minor Changes
-------------

- blackbox_exporter -  added additional probe for TCP with TLS enabled
- grafana - Add panel to Query Statistics dashboard for top WAL stats by bytes
- grafana - Minimum version of Grafana is now 9.2.19
- grafana - Update dashboard to support multiple pgbouncer targets exported by new pgbouncer_fdw
- postgres_exporter - Add WAL statistics for pg_stat_statements
- postgres_exporter - Filter out idle-in-transaction sessions from general max query runtime metrics.
- postgres_exporter - Update query file to support pgbouncer_fdw 1.0.0
- prometheus - Add alert for cases where a PostgreSQL cluster does not have an instance that is the leader/primary
- prometheus - Allow node_exporter's load alert to be based on the CPU count. Allows lowering of default thresholds and more accurate alerting
- prometheus - Enable the PGDataChecksum alert by default for PG12+
- prometheus - Update the example files to provide better guidance on proper configuration
- prometheus - added additional job example to scan TCP probes with TLS

Bugfixes
--------

- grafana - fixed dashboard links that broke when Grafana removed support for the `/dashboard/db/:slug` endpoint in v8

v4.8.0
======

Release Summary
---------------

Version 4.8.0 of pgMonitor includes support for PostgreSQL 15. Please see the CHANGELOG for additional information about this release.

Major Changes
-------------

- pg15 - Update to support PostgreSQL 15 (https://github.com/CrunchyData/pgmonitor/issues/296)

Minor Changes
-------------

- jit - Disable JIT for the ccp_monitoring user to avoid memory leak issues (https://github.com/CrunchyData/pgmonitor/issues/295)
- prometheus - update prometheus sysconfig file to use up to date startup values (https://github.com/CrunchyData/pgmonitor/issues/293)

Bugfixes
--------

- postgres_exporter - fixed pgbackrest-info.sh script to account for old default pgBackRest config file not existing
- postgres_exporter - remove unnecessary $-escaping in the service file (https://github.com/CrunchyData/pgmonitor/issues/301)
- postgres_exporter - update global sysconfig file to have proper general queries file (https://github.com/CrunchyData/pgmonitor/issues/297)
