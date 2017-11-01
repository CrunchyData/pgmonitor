# Setting up exporters

## Instructions
* Download and save the latest postgres_exporter to /usr/bin/postgres_exporter

https://github.com/wrouesnel/postgres_exporter/releases

```
chmod +x /usr/bin/postgres_exporter
```
* Download and save the latest node_exporter to /usr/bin/node_exporter

https://github.com/prometheus/node_exporter/releases

```
chmod +x /usr/bin/node_exporter
```
* Modify node/ccp_io_queue.sh for DISK to monitoring
* Modify node/ccp_is_pgready.sh for postgres bin path and to ensure it points to an existing database in the cluster to monitor (by default "postgres")
* Modify crontab.txt to run relevant scripts and schedule the bloat check for off-peak hours

## Setup
Create the ccp_monitoring user if it does not yet exist
```
useradd ccp_monitoring -m -d /var/lib/ccp_monitoring
```
```
yum install sysstat.x86_64 python-psycopg2.x86_64

cp node/node_exporter.service postgres/postgres_exporter.service /etc/systemd/system/
cp node/ccp_io_queue.sh node/ccp_is_pgready.sh pg_bloat_check.py /usr/bin/
cp node/sysconfig.node_exporter /etc/sysconfig/node_exporter
cp postgres/sysconfig.postgres_exporter /etc/sysconfig/postgres_exporter

cp crontab.txt /var/lib/ccp_monitoring
chown ccp_monitoring:ccp_monitoring /var/lib/ccp_monitoring/crontab.txt
sudo -u ccp_monitoring crontab crontab.txt

systemctl daemon-reload
```

When Packaging, service files shall go in /usr/lib/systemd/system/

## Database Setup

### postgresql.conf
Install contrib modules to provide additional monitoring capabilities. This requires a restart of the database.
```
shared_preload_libraries = 'pg_stat_statements,auto_explain'
```
pg_stat_statements requires running the following statement in the database(s) to be monitored
```
psql -d postgres -c "CREATE EXTENSION pg_stat_statements"
```

### Monitoring Queries File

Install functions to all databases you will be monitoring in the cluster. The queries common to all postgres versions are contained in queries_common.yml. Major version specific queries are contained in a relevantly named file. Queries for more specialized monitoring are contained in additional files. postgres_exporter only takes a single query file as an argument for custom queries, so cat together the queries necessary into a single file. 

For example, to use just the common queries for PostgreSQL 9.5/9.6 do the following:
```
cd postgres
cat queries_common.yml queries_per_db.yml queries_pg95.yml > queries.yml
cp queries.yml /etc/ccp_monitoring/queries.yml
cp functions_pg95.sql /etc/ccp_monitoring/exporter_functions.sql
psql -f /etc/ccp_monitoring/exporter_functions.sql
```
To include queries for PostgreSQL 10 as well as pg_stat_statements and bloat do the following:
```
cd postgres
cat queries_common.yml queries_per_db.yml queries_pg10.yml queries_pg_stat_statements.yml queries_bloat.yml > queries.yml
cp queries.yml /etc/ccp_monitoring/queries.yml
cp functions_pg10.sql /etc/ccp_monitoring/exporter_functions.sql
psql -f /etc/ccp_monitoring/exporter_functions.sql
```
Certain metrics are not cluster-wide, so in that case multiple exporters must be run to collect all relevant metrics. The queries_per_db.yml file contains these queries and the secondary exporter(s) can use this file to collect those metrics and avoid duplicating cluster-wide metrics. Note that some other metrics are per database as well (bloat). You can then define multiple targets for that job in Prometheus so that all the metrics are collected together.
```
cd postgres
cat queries_per_db.yml queries_bloat.yml > queries_mydb.yml
cp queries_mydbname.yml /etc/ccp_monitoring/queries_mydb.yml
```
Modify the sysconfig environment variable accordingly (change port and query file)
```
WEB_LISTEN_ADDRESS="-web.listen-address=localhost:9188"
QUERY_PATH="-extend.query-path=/etc/ccp_monitoring/queries_mydb.yml"
```

### Bloat setup

Run script on the specific database(s) you will be monitoring bloat for in the cluster
See special note in crontab.txt concerning a superuser requirement for using this script

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
