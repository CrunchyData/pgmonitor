=======================
pgMonitor Release Notes
=======================

.. contents:: Topics


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
