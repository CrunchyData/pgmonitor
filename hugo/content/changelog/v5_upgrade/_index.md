---
title: "Upgrading to pgMonitor v5.0.0"
draft: false
weight: 5
---

Version 5 of pgMonitor introduces a new exporter that will be used for collecting PostgreSQL metrics: [sql_exporter](https://github.com/burningalchemist/sql_exporter). Converting to this new exporter will involve cleaning up the old postgres_exporter, updating Prometheus targets, and installing new Grafana dashboards.

## Cleanup

### postgres_exporter

This new exporter for PostgreSQL allows for just a single exporter to connect to all databases within a PostgreSQL instance as well as connecting directly to PgBouncer to collect its metrics.
There is no longer any need for the postgres_exporter to be running, so its services can be shutdown. Some examples of those service names based on the old documentation are as follows:

```
sudo systemctl stop crunchy-postgres-exporter@postgres_exporter_pg##
sudo systemctl disable crunchy-postgres-exporter@postgres_exporter_pg##

sudo systemctl stop crunchy-postgres-exporter@postgres_exporter_pg##_per_db
sudo systemctl disable crunchy-postgres-exporter@postgres_exporter_pg##_per_db
```

Note the values after the @ symbol may be different depending on the sysconfig files that have been created for your exporters. There may also be exporters running for multiple clusters and we would recommend replacing all of the existing postgres_exporters with the new sql_exporter.

If you've installed pgMonitor with the packages provided by Crunchy Data, those packages can now be uninstalled as well.

| Package Name                   | Description                                                               |
|--------------------------------|---------------------------------------------------------------------------|
| pgbouncer_fdw                  | Package for the pgbouncer_fdw extension                                   |
| pgmonitor-pg-common            | Package containing postgres_exporter items common for all versions of PostgreSQL |
| pgmonitor-pg##-extras          | Crunchy-optimized configurations for postgres_exporter. Note that each major version of PostgreSQL has its own extras package (pgmonitor-pg13-extras, pgmonitor-pg14-extras, etc) |
| postgres_exporter              | Base package for postgres_exporter                                        |

WARNING:

Depending on the order that packages were installed, the removal of the `pgmonitor-pg-common` and/or `pgmonitor-pg##-extras` package may attempt to uninstall the core PostgreSQL packages. This has been observed on RHEL systems that are using DNF to manage their packages. Please carefully review which packages are being removed during this cleanup step. It is recommended to use the `--noautoremove` flag to the package removal command

```
dnf remove --noautoremove pgmonitor-pg-common
```

Also note that the pgbouncer_fdw is no longer required to monitor PgBouncer if using sql_exporter but it can still be used if desired. Per previous instructions, it was usually only installed on the global database. The extension can be removed as follows if it's not needed.
```
DROP EXTENSION pgbouncer_fdw;
```

If postgres_exporter was not set up with packages, you can now manually remove all the related files. Note the ## is replaced with the major version of PG that was being monitored. It is possible that multiple versions of PG had been monitored and copies of these files could exist for all versions. Also, the sysconfig files listed below are the defaults used in examples; there may be additional postgres_exporter sysconfig files on your system(s).

| System Location |
|-----------------|
| /etc/postgres_exporter/  |
| /usr/lib/systemd/system/crunchy-postgres-exporter@.service  |
| /etc/sysconfig/postgres_exporter_pg##  |
| /etc/sysconfig/postgres_exporter_pg##_per_db  |
| /usr/bin/pgbackrest-info.sh |
| /etc/pgmonitor.conf |


### Prometheus
All postgres_exporter Prometheus targets can now be removed. The default location for Prometheus targets is `/etc/prometheus/auto.d/`, but please check your Prometheus installation for possible additional target locations. In the identified location(s), remove any targets for the postgres_exporter. The default ports for postgres_exporter were 9187 and 9188, so any targets with these ports should be examined for removal. Note that if alerting had previously been enabled, the previous step likely caused multiple alerts to fire; once this step is done, you can simply reload Prometheus to clear these targets and any related alerts should resolve themselves.

```bash
sudo systemctl reload prometheus
```
Any alerts related to postgres_exporter can also be removed from the files contained in the default alert files location `/etc/prometheus/alert-rules.d/`. Note the default example alert file had been named `crunchy-alert-rules-pg.yml`

### Grafana

Version 5.x of pgMonitor raises the minimum required version of Grafana to 10.4. It also removes dashboards related to postgres_exporter and adds new ones for sql_exporter. If you are simply using the dashboards provided by pgMonitor, the easiest method to update is to simply remove the old ones and install the new ones.

If you are using Crunchy-provided packages, simply uninstall the old packages. It's recommended to follow the non-package removal process below as well to ensure things are cleaned up properly.

| Package Name              | Description                                                       |
|---------------------------|-------------------------------------------------------------------|
| pgmonitor-grafana-extras  | Crunchy configurations for datasource & dashboard provisioning    |

If you didn't use the Crunchy-provided packages, ensure the files in the following folder are removed:

```
| System Location |
|-----------------|
| /etc/grafana/crunchy_dashboards |
```

## Set up sql_exporter

At this point, you should just be able to follow the [standard setup instructions](https://access.crunchydata.com/documentation/pgmonitor/latest/) for the latest version of pgMonitor. This will set up the new exporter, Prometheus targets, and new Grafana dashboards.
