# Setting up exporters

## Instructions
* Download postgres_exporter and save postgres_exporter to /usr/bin/postgres_exporter
```
chmod +x /usr/bin/postgres_exporter
```
* Download node_exporter and save node_exporter to /usr/bin/node_exporter
```
chmod +x /usr/bin/node_exporter
```
* Modify node/ccp_io_queue.sh for DISK to monitoring
* Modify node/ccp_is_pgready.sh for postgres bin path and to ensure it points to an existing database in the cluster to monitor (by default "postgres")

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
Install functions to the specific database you will be monitoring in the cluster

### For PG10
```
cp postgres/queries_pg10.yml /etc/ccp_monitoring/queries.yml
cp postgres/functions_pg10.sql /etc/ccp_monitoring/exporter_functions.sql
psql -f /etc/ccp_monitoring/exporter_functions.sql
```
### For PG96
```
cp postgres/queries_pg96.yml /etc/ccp_monitoring/queries.yml
cp postgres/functions_pg96.sql /etc/ccp_monitoring/exporter_functions.sql
psql -f /etc/ccp_monitoring/exporter_functions.sql
```

### Bloat setup

Run script on the specific database you will be monitoring bloat for in the cluster
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
