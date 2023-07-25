=======================
pgMonitor Release Notes
=======================

.. contents:: Topics


v4.9.0
======

Release Summary
---------------

Version 4.9.0 of pgMonitor includes updates to add additional metrics and now better supports monitoring multiple pgbouncer hosts. Please see the full CHANGELOG for additional information about this release.

Major Changes
-------------

- postgres_exporter - Added options for using materialized views to collect metrics that may cause longer query runtimes (object sizing, statistic, etc)
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
- prometheus - Add alert for cases where a PostgreSQL cluster does not have an instance that is the leader/primary.
- prometheus - Allow node_exporter's load alert to be based on the CPU count. Allows lowering of default thresholds and more accurate alerting.
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
