---
title: "Setting up Grafana"
draft: false
weight: 3
---

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/). Otherwise the Grafana RPM Package can be downloaded and installed from https://grafana.com/grafana/download. There is no difference between the Crunchy provided package and the one directly from Grafana.

- [Included Dashboards](#dashboards)
- [Installation](#installation)
    - [Linux](#linux)
- [Upgrading](#upgrading)
- [Setup](#setup)
    - [Linux](#setup-on-linux)

### Included Dashboards {#dashboards}

pgMonitor comes with several dashboards ready to be used with automatic provisioning. They provide examples of using the metrics from the postgres_exporter and node_exporter. Since provisioned dashboards cannot be edited directly in the web interface, if any custom changes are desired, it is recommmended to make a copy of them and make your changes there.

| Dashboard Name        | Filename              | Description                                       |
|-----------------------|-----------------------|---------------------------------------------------|
| Bloat Details         | Bloat_Details.json    | Provides details on database bloat (wasted space). Provides overview and top-n statistics.|
| CRUD Details          | CRUD_Details.json | Provides details on Create, Read, Update, Delete (CRUD) statistics on a per-table basis.  |
| pgBackRest            | PGBackrest.json | Provides details on backups performed with pgBackRest. Also provides recovery window to show timeframe available for PITR. |
| PGBouncer             | PGBouncer.json | Provides details from the PgBouncer statistics views. |
| PostgreSQL Details    | PG_Details.json | Provides detailed information for each PostgreSQL instance (connections, replication, wraparound, etc). |
| PostgreSQL Overview   | PG_Overview.json| Provides an overview of all PostgreSQL systems being monitored. Indicates whether a system is a Primary or Replica. Can click on each panel to open up the PostgreSQL Details for that system. |
| Query Statistics      | QueryStatistics.json| Provides an overview of statistics collected by the pg_stat_statements extension. |
| TableSize Details     | TableSize_Details.json | Provides size details on a per-table basis for the given database. |
|||
|Filesystem Details     | Filesystem_Details.json | Provides details on the filesystem metrics (disk usage, IO, etc). |
|Network Details        | Network_Details.json | Provides details on network usage (utilization, traffic in/out, netstat, etc). | 
|Overview               | Overview.json | The top level overview dashboard that provides links to the OS Overview, PostgreSQL Overview, ETCD, and Prometheus Alerts dashboards. |
|OS Details             | OS_Details.json | Provides details on operating system metrics (cpu, memory, swap, disk usage). Links to Filesystem Details dashboard. |
|OS Overview            | Overview.json| Provides an overview that shows the up status of each system monitored by pgMonitor. |
|||
|ETCD Details           | ETCD_Details.json | Provides details on the status of the ETCD cluster monitored by pgMonitor. |
|Prometheus Alerts      | Prometheus_Alerts.json| Provides a summary list of current and recent alerts that have fired in Prometheus. Interaction with the Alertmanager to silence alerts is possible from the Alerting menu in Grafana. |

## Installation {#installation}

### Linux {#linux}

#### With RPM Packages

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/).

If you install the below available packages with RPM, you can continue reading at the [Setup](#setup) section.

##### Available Packages

| Package Name              | Description                                                       |
|---------------------------|-------------------------------------------------------------------|
| grafana                   | Base package for grafana                                          |
| pgmonitor-grafana-extras  | Crunchy configurations for datasource & dashboard provisioning    |

#### Without Packages

Create the following directories on your grafana server if they don't exist:

```
mkdir -p /etc/grafana/provisioning/{datasources,dashboards}
mkdir -p /etc/grafana/crunchy_dashboards
```

| pgmonitor Configuration File              | System Location                                        |
|-------------------------------------------|--------------------------------------------------------|
| grafana/crunchy_grafana_datasource.yml    | /etc/grafana/provisioning/datasources/datasource.yml |  
| grafana/crunchy_grafana_dashboards.yml    | /etc/grafana/provisioning/dashboards/dashboards.yml |  

Review the {{< shell >}}crunchy_grafana_datasource.yml{{< /shell >}}} file to ensure it is looking at your Prometheus database. The included file assumes Grafana,  Prometheus, and Alertmanager are running on the same system. DO NOT CHANGE the datasource {{< yaml >}}uid{{< /yaml >}} or {{< yaml >}}name{{< /yaml >}} fields if you will be using the dashboards provided in this repo. They assume those values and will not work otherwise. Any other options can be changed as needed. Save the {{< shell >}}crunchy_grafana_datasource.yml{{< /shell >}} file and rename it to {{< shell >}}/etc/grafana/provisioning/datasources/datasources.yml{{< /shell >}}. Restart grafana and confirm through the web interface that the datasource was provisioned and working.

Review the {{< shell >}}crunchy_grafana_dashboards.yml{{< /shell >}} file to ensure it's looking at where you stored the provided dashboards. By default it is looking in {{< shell >}}/etc/grafana/crunchy_dashboards{{< /shell >}}. Save this file and rename it to {{< shell >}}/etc/grafana/provisioning/dashboards/dashboards.yml{{< /shell >}}. Restart grafana so it picks up the new config.

Save all of the desired .json dashboard files to the {{< shell >}}/etc/grafana/crunchy_dashboards{{< /shell >}} folder. All of them are not required, so if there is a dashboard you do not need, it can be left out.

## Upgrading {#upgrading}

Please review the ChangeLog for pgMonitor and take note of any changes to metric names and/or dashboards. Note that if you are using the included dashboards that are managed via the provisioning system, they will automatically be updated. If you've made any changes to configuration files and kept their default names, the package will not overwrite them and will instead make a new file with an {{< shell >}}*.rpmnew{{< /shell >}} extension. You can compare your file and the new one and incorporate any changes as needed or desired.

## Setup {#setup}

### Setup on Linux {#setup-on-linux}

#### Configuration Database

By default Grafana uses an SQLite database to store configuration and dashboard information. We recommend using a PostgreSQL database for better long term scalability. Before doing any further configuration, including changing the default admin password, set the `grafana.ini` to point to a postgresql instance that has a database created for it.

In psql run the following:

```
    CREATE ROLE grafana WITH LOGIN;
    CREATE DATABASE grafana;
    ALTER DATABASE grafana OWNER TO grafana;
    \password grafana
```

You may also need to adjust your `pg_hba.conf` to allow grafana to connect to your database.

In your `grafana.ini`, set the following options at a minimum with relevant values:

```ini
[database]

type = postgres
host = 127.0.0.1:5432
name = grafana
user = grafana
password = """mypassword"""
```

Now enable and start the grafana service

```
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```

Navigate to the web interface: https://&lt;ip-address&gt;:3000. Log in with admin/admin (be sure to change the admin password) and check settings to ensure the postgres options have been set and are working.

### Datasource & Dashboard Provisioning

Grafana provides the ability to automatically provision datasources and dashboards via configuration files instead of having to manually import them either through the web interface or the API. Note that provisioned dashboards can no longer be directly edited and saved via the web interface. See the Grafana documentation for how to edit/save provisioned dashboards: http://docs.grafana.org/administration/provisioning/#making-changes-to-a-provisioned-dashboard. If you'd like to customize these dashboards, we recommend first adding them via provisioning then saving them with a new name. You can then either manage them via the web interface or add them to the provisioning system.

The extras package takes care of putting all these files in place. If you did not use the Crunchy package to install Grafana, see the additional instructions above. Once that is done, the only additional setup that needs to be done is to set the "provisioning" option in the `grafana.ini` to point to the top level directory if it hasn't been done already. 

```ini
[paths]
provisioning = /etc/grafana/provisioning
```


