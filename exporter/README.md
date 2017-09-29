# Setting up exporters

## Instructions
* Download postgres_exporter and save postgres_exporter to /usr/bin/postgres_exporter
* Download node_exporter and save node_exporter to /usr/bin/node_exporter
* Modify node/ccp_io_queue.sh for DISK to monitoring
* Modify node/ccp_is_pgready.sh for postgres bin path

## Setup
```
yum install sysstat.x86_64 python-psycopg2.x86_64

useradd ccp_monitoring -m -d /var/lib/ccp_monitoring

cp crontab.txt /var/lib/ccp_monitoring
chown ccp_monitoring:ccp_monitoring /var/lib/ccp_monitoring/crontab.txt
su - ccp_monitoring -c "crontab crontab.txt"

cp node/node_exporter.service postgres/postgres_exporter.service /etc/systemd/system/
cp node/ccp_io_queue.sh node/ccp_is_pgready.sh pg_bloat_check.py /usr/bin/
cp node/sysconfig.node_exporter /etc/sysconfig/node_exporter
cp postgres/sysconfig.postgres_exporter /etc/sysconfig/postgres_exporter

systemctl daemon-reload
```

| When Packaging, service files shall go in /usr/lib/systemd/system/

## Database Setup

Install functions to the specific database you will be monitoring in the cluster

### For PG10
```
cp postgres/queries_pg10.yml /etc/ccp_monitoring/query.yml
psql -f postgres/functions_pg10.sql
```
### For PG96
```
cp postgres/queries_pg96.yml /etc/ccp_monitoring/query.yml
psql -f postgres/functions_pg96.sql
```

### postgresql.conf
```
shared_preload_libraries = 'pg_stat_statements,auto_explain'
```

### Bloat setup

Run script on the specific database you will be monitoring bloat for in the cluster

```
psql -c "CREATE EXTENSION pgstattuple; CREATE EXTENSION pg_stat_statements;"
/usr/bin/pg_bloat_check.py -c "host=localhost dbname=postgres user=postgres" --create_stats_table
psql -c "GRANT SELECT ON bloat_indexes, bloat_stats, bloat_tables TO monitor;"
```

