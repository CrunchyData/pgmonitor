# Setting up exporters

## Installation

* Install latest node_exporter package from Crunchy Repository
* Install latest postgres_exporter package from Crunchy Repository
* Install latest crunchy-monitoring-extras-pg## package for your major version of PostgreSQL
* Install latest crunchy-pg_bloat-check package if you need to monitor database bloat

## Service Setup (RHEL/CENTOS 7)

* Copy/Rename /etc/systemd/system/node_exporter.service.d/crunchy-node-exporter-service-el7.conf.example to override default node_exporter service. See notes in example file for more details.
* Copy/Rename & modify /etc/sysconfig/node_exporter.example as necessary. Default name expected is node_exporter.
* Copy/Rename & modify /etc/sysconfig/postgres_exporter.example as necessary. Default name expected is postgres_exporter.
* Modify /var/lib/ccp_monitoring/crontab.txt to run relevant scripts and schedule the bloat check for off-peak hours. Add crontab entries manually to ccp_monitoring user (or user relevant for your environment).

## Database Setup

### postgresql.conf
Install contrib modules to provide additional monitoring capabilities. This requires a restart of the database if you would like these contrib modules installed.
```
shared_preload_libraries = 'pg_stat_statements,auto_explain'
```
pg_stat_statements requires running the following statement in the database(s) to be monitored
```
psql -d postgres -c "CREATE EXTENSION pg_stat_statements"
```

### GRANTS
The ccp_monitoring role must be allowed to connect to all databases in the cluster. To do this, run the following command to generate the necessary GRANT statements:
```
SELECT 'GRANT CONNECT ON DATABASE "' || datname || '" TO ccp_monitoring;' FROM pg_database WHERE datallowconn = true;
```
This should generate one or more statements similar to the following:
```
GRANT CONNECT ON DATABASE "postgres" TO ccp_monitoring;
```

### Monitoring Queries File

Install functions to all databases you will be monitoring in the cluster (if you don't have pg_stat_statements installed, you can ignore the error given). The queries common to all postgres versions are contained in queries_common.yml. Major version specific queries are contained in a relevantly named file. Queries for more specialized monitoring are contained in additional files. postgres_exporter only takes a single query file as an argument for custom queries, so cat together the queries necessary into a single file. 

For example, to use just the common queries for PostgreSQL 9.6 do the following. Note the location of the final queries file is based on the major version installed. The exporter service will look in the relevant version folder in the ccp_monitoring directory:
```
cd /var/lib/ccp_monitoring/96
cat queries_common.yml queries_per_db.yml queries_pg96.yml > queries.yml
psql -f /var/lib/ccp_monitoring/96/functions_pg96.sql
```
As another example, to include queries for PostgreSQL 10 as well as pg_stat_statements and bloat do the following:
```
cd /var/lib/ccp_monitoring/10
cat queries_common.yml queries_per_db.yml queries_pg10.yml queries_pg_stat_statements.yml queries_bloat.yml > queries.yml
psql -f /var/lib/ccp_monitoring/10/functions_pg10.sql
```

### Bloat setup

Run script on the specific database(s) you will be monitoring bloat for in the cluster. See special note in crontab.txt concerning a superuser requirement for using this script

```
psql -d postgres -c "CREATE EXTENSION pgstattuple;"
/usr/bin/pg_bloat_check.py -c "host=localhost dbname=postgres user=postgres" --create_stats_table
psql -d postgres -c "GRANT SELECT ON bloat_indexes, bloat_stats, bloat_tables TO ccp_monitoring;"
```

## Startup services (RHEL/CENTOS 7)

```
systemctl enable node_exporter
systemctl start node_exporter
systemctl status node_exporter
```
To most easily allow the possibility of multiple postgres exporters and avoid maintaining many similar service files, a systemd template service file is used. The name of the sysconfig EnvironmentFile to be used by the service is passed as the value after the "@" and before ".service" in the service name. The default exporter's EnvironmentFile is named "postgres_exporter".
```
systemctl enable crunchy_postgres_exporter@postgres_exporter.service
systemctl start cruncy_postgres_exporter@postgres_exporter
systemctl status crunchy_postgres_exporter@postgres_exporter

```

## Running multiple postgres exporters
Certain metrics are not cluster-wide, so in that case multiple exporters must be run to collect all relevant metrics. The queries_per_db.yml file contains these queries and the secondary exporter(s) can use this file to collect those metrics and avoid duplicating cluster-wide metrics. Note that some other metrics are per database as well (bloat). You can then define multiple targets for that job in Prometheus so that all the metrics are collected together.
```
cat queries_per_db.yml queries_bloat.yml > queries_mydb.yml
cp queries_mydbname.yml /var/lib/ccp_monitoring/96/queries_mydb.yml
```
You'll need to create a new sysconfig environment file for the second exporter service. You can just copy the existing ones and modify the relevant lines, mainly being the port, database name, and query file 
```
cp /etc/sysconfig/postgres_exporter /etc/sysconfig/postgres_exporter_mydb 

WEB_LISTEN_ADDRESS="-web.listen-address=192.168.1.101:9188"
QUERY_PATH="-extend.query-path=/var/lib/ccp_monitoring/96/queries_mydb.yml"
DATA_SOURCE_NAME="postgresql://ccp_monitoring@localhost:5432/mydb?sslmode=disable"
```
Since a systemd template is used for the postgres_exporter services, all you need to do is pass the sysconfig file name as part of the new service name.
```
systemctl enable crunchy_postgres_exporter@postgres_exporter_mydb.service
systemctl start cruncy_postgres_exporter@postgres_exporter_mydb
systemctl status crunchy_postgres_exporter@postgres_exporter_mydb

```

## Note for packaging (RHEL/CENTOS 7)

The service override file(s) must be placed in the relevant drop-in folder to override the default service files.

    /etc/systemd/system/node_exporter.service.d/*.conf

After a daemon-reload, systemd should automatically find these files and the crunchy services should work as intended.
 

## Setup (RHEL/CENTOS 6)
TODO
