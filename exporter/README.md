# Setting up exporters

## Installation

* Install latest node_exporter package from Crunchy Repository
* Install latest postgres_exporter package from Crunchy Repository

## Service Setup

* Modify sysconfig.postgres_exporter to set WEB_LISTEN_ADDRESS to the network IP assigned to the server that the exporter will run on. 
* Modify sysconfig.postgres_exporter to set DATA_SOURCE_NAME to set which database to connect to to monitor (default is "postgres")
* Modify node/ccp_is_pgready.sh for postgres bin path and to ensure it points to an existing database in the cluster to monitor (by default "postgres")
* Modify node/ccp_io_queue.sh for DISK to monitoring (if using this metric)
* Modify crontab.txt to run relevant scripts and schedule the bloat check for off-peak hours

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

Install functions to all databases you will be monitoring in the cluster. The queries common to all postgres versions are contained in queries_common.yml. Major version specific queries are contained in a relevantly named file. Queries for more specialized monitoring are contained in additional files. postgres_exporter only takes a single query file as an argument for custom queries, so cat together the queries necessary into a single file. 

For example, to use just the common queries for PostgreSQL 9.5 do the following:
```
cd /var/lib/ccp_monitoring/95
cat queries_common.yml queries_per_db.yml queries_pg95.yml > queries.yml
cp queries.yml /var/lib/ccp_monitoring/queries.yml
psql -f /var/lib/ccp_monitoring/functions_pg95.sql
```
As another example, to include queries for PostgreSQL 10 as well as pg_stat_statements and bloat do the following:
```
cd /var/lib/ccp_monitoring/10
cat queries_common.yml queries_per_db.yml queries_pg10.yml queries_pg_stat_statements.yml queries_bloat.yml > queries.yml
cp queries.yml /etc/ccp_monitoring/queries.yml
psql -f /var/lib/ccp_monitoring/functions_pg10.sql
```

### Running multiple postgres exporters
Certain metrics are not cluster-wide, so in that case multiple exporters must be run to collect all relevant metrics. The queries_per_db.yml file contains these queries and the secondary exporter(s) can use this file to collect those metrics and avoid duplicating cluster-wide metrics. Note that some other metrics are per database as well (bloat). You can then define multiple targets for that job in Prometheus so that all the metrics are collected together.
```
cat queries_per_db.yml queries_bloat.yml > queries_mydb.yml
cp queries_mydbname.yml /etc/ccp_monitoring/queries_mydb.yml
```
You'll need to create a new service file and sysconfig environment file for the second exporter service. You can just copy the existing ones and modify the relevant lines 
```
cp /etc/systemd/system/postgres_exporter /etc/systemd/system/postgres_exporter_mydb

EnvironmentFile=/etc/sysconfig/postgres_exporter_mydb
```

Change environment variables accordingly in the sysconfig file (change port, database name and query file)

```
cp /etc/sysconfig/postgres_exporter /etc/sysconfig/postgres_exporter_mydb 

WEB_LISTEN_ADDRESS="-web.listen-address=192.168.1.101:9188"
QUERY_PATH="-extend.query-path=/etc/ccp_monitoring/queries_mydb.yml"
DATA_SOURCE_NAME="postgresql://ccp_monitoring@localhost:5432/mydb?sslmode=disable"
```

### Bloat setup

Run script on the specific database(s) you will be monitoring bloat for in the cluster. See special note in crontab.txt concerning a superuser requirement for using this script

```
psql -d postgres -c "CREATE EXTENSION pgstattuple;"
/usr/bin/pg_bloat_check.py -c "host=localhost dbname=postgres user=postgres" --create_stats_table
psql -d postgres -c "GRANT SELECT ON bloat_indexes, bloat_stats, bloat_tables TO ccp_monitoring;"
```

## Startup services

```
systemctl enable postgres_exporter
systemctl start postgres_exporter
systemctl status postgres_exporter

systemctl enable node_exporter
systemctl start node_exporter
systemctl status node_exporter
```
