---
title: "Setting up Grafana"
draft: false
weight: 3
---

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/). Otherwise the Grafana RPM Package can be downloaded and installed from https://grafana.com/grafana/download. There is no difference between the Crunchy provided package and the one directly from Grafana.

## Installation

### Upgrading

If you'd like to take advantage of the new provisioning system in Grafana 5 provided by pgmonitor 2.x, we recommend either renaming or deleting your existing datasources and dashboards so there are no issues when the provisioned versions are imported.

When upgrading from pgmonitor 1.x to 2.x, note that many of the system related metric names from node_exporter have had their names changed. The new graphs provided for Grafana 5+ have taken these new names into account. Also, the top level PostgreSQL Overview dashboard no longer uses the ccp_is_ready metric, so you will have to include some new postgres_exporter metrics for that dashboard to work.

### With RPM Packages

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/).

If you install the below available packages with RPM, you can continue reading at the [Setup](#setup) section.

#### Available Packages

| Package Name              | Description                                                       |
|---------------------------|-------------------------------------------------------------------|
| grafana                   | Base package for grafana                                          |
| pgmonitor-grafana-extras  | Crunchy configurations for datasource & dashboard provisioning    |

#### Without Packages

Create the following directories on your grafana server if they don't exist:

    mkdir -p /etc/grafana/provisioning/datasources
    mkdir -p /etc/grafana/provisioning/dashboards
    mkdir -p /etc/grafana/crunchy_dashboards

| pgmonitor Configuration File              | System Location                                        |
|-------------------------------------------|--------------------------------------------------------|
| grafana/crunchy_grafana_datasource.yml    | `/etc/grafana/provisioning/datasources/datasource.yml` |  
| grafana/crunchy_grafana_dashboards.yml    | `/etc/grafana/provisioning/dashboards/dashboards.yml` |  

Review the crunchy_grafana_datasource.yml file to ensure it is looking at your Prometheus database. The included file assumes Grafana and Prometheus are running on the same system. DO NOT CHANGE the datasource "name" if you will be using the dashboards provided in this repo. They assume that name and will not work otherwise. Any other options can be changed as needed. Save the crunchy_grafana_datasource.yml file and rename to /etc/grafana/provisioning/datasources/datasources.yml. Restart grafana and confirm through the web interface that the datasource was provisioned and working.

Review the crunchy_grafana_dashboards.yml file to ensure it's looking at where you stored the provided dashboards. By default it is looking in /etc/grafana/crunchy_dashboards. Save this file and rename to /etc/grafana/provisioning/dashboards/dashboards.yml. Restart grafana so it picks up the new config.

Save all of the .json dashboard files to the /etc/grafana/crunchy_dashboards folder.

## Setup

### Configuration Database

By default Grafana uses an SQLite database to store configuration and dashboard information. We recommend using a PostgreSQL database for better long term scalability. Before doing any further configuration, including changing the default admin password, set the grafana.ini to point to a postgresql instance that has a database created for it.

In psql run the following:

    CREATE ROLE grafana WITH LOGIN;
    CREATE DATABASE grafana;
    ALTER DATABASE grafana OWNER TO grafana;
    \password grafana

You may also need to adjust your pg_hba.conf to allow grafana to connect to your database.

In your grafana.ini, set the following options at a minimum with relevant values:

    [database]

    type = postgres
    host = 127.0.0.1:5432
    name = grafana
    user = grafana
    password = """mypassword"""

Now enable and start the grafana service

    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
    sudo systemctl status grafana-server

Navigate to the web interface: https://&lt;ip-address&gt;:3000. Log in with admin/admin (be sure to change the admin password) and check settings to ensure the postgres options have been set and are working.

### Datasource & Dashboard Provisioning

Grafana 5.x provides the ability to automatically provision datasources and dashboards via configuration files instead of having to manually import them either through the web interface or the API. Note that provisioned dashboards can no longer be directly edited and saved via the web interface. See the Grafana documentation for how to edit/save provisioned dashboards: http://docs.grafana.org/administration/provisioning/#making-changes-to-a-provisioned-dashboard. If you'd like to customize these dashboards, we recommend first adding them via provisioning then exporting and importing manually via the web interface.

The extras package takes care of putting all these files in place. If you did not use the crunchy package to install grafana, see the additional instructions above. Once that is done, the only additional setup that needs to be done is to set the "provisioning" option in the grafana.ini to point to the top level directory if it hasn't been done already. If you're upgrading from Grafana 4.x to 5.x, you will have to add the "provisioning" option to the [paths] section of the grafana.ini file. Once that is done, just restart grafana and all datasources and dashboards should appear.

    [paths]
    provisioning = /etc/grafana/provisioning
