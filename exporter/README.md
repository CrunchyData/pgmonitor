# Setting up exporters

## Installation

* Install latest node_exporter package from Crunchy Repository
* Install latest postgres_exporter package from Crunchy Repository
* Install latest pgmonitor-pg##-extras package for your major version of PostgreSQL
* Install latest crunchy-pg_bloat-check package if you need to monitor database bloat

## Service Setup (RHEL/CENTOS 7)

* If necessary, modify /etc/systemd/system/node_exporter.service.d/crunchy-node-exporter-service-el7.conf. See notes in file for more details.
* If necessary, modify /etc/sysconfig/node_exporter. See notes in file for more details.
* If necessary, modify /etc/sysconfig/postgres_exporter. See notes in file for more details.
* Modify /etc/postgres_exporter/##/crontab##.txt to run relevant scripts and schedule the bloat check for off-peak hours. Add crontab entries manually to ccp_monitoring user (or user relevant for your environment).

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

### Monitoring Queries File

Install functions to all databases you will be monitoring in the cluster (if you don't have pg_stat_statements installed, you can ignore the error given). The queries common to all postgres versions are contained in queries_common.yml. Major version specific queries are contained in a relevantly named file. Queries for more specialized monitoring are contained in additional files. postgres_exporter only takes a single query file as an argument for custom queries, so cat together the queries necessary into a single file. 

For example, to use just the common queries for PostgreSQL 9.6 do the following. Note the location of the final queries file is based on the major version installed. The exporter service will look in the relevant version folder in the ccp_monitoring directory:
```
cd /etc/postgres_exporter/96
cat queries_common.yml queries_per_db.yml queries_pg92-96.yml > queries.yml
psql -f /etc/postgres_exporter/96/functions_pg92-96.sql
```
As another example, to include queries for PostgreSQL 10 as well as pg_stat_statements and bloat do the following:
```
cd /etc/postgres_exporter/10
cat queries_common.yml queries_per_db.yml queries_pg10.yml queries_pg_stat_statements.yml queries_bloat.yml > queries.yml
psql -f /etc/postgres_exporter/10/functions_pg10.sql
```

For replica servers, the setup is the same except that the functions_pg##.sql file does not need to be run since writes cannot be done there and it was already run on the master.

### GRANTS
The ccp_monitoring role (created by running the "functions_pg##.sql" file above) must be allowed to connect to all databases in the cluster. To do this, run the following command to generate the necessary GRANT statements:
```
SELECT 'GRANT CONNECT ON DATABASE "' || datname || '" TO ccp_monitoring;' FROM pg_database WHERE datallowconn = true;
```
This should generate one or more statements similar to the following:
```
GRANT CONNECT ON DATABASE "postgres" TO ccp_monitoring;
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
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```
To most easily allow the possibility of multiple postgres exporters and avoid maintaining many similar service files, a systemd template service file is used. The name of the sysconfig EnvironmentFile to be used by the service is passed as the value after the "@" and before ".service" in the service name. The default exporter's EnvironmentFile is named "postgres_exporter".
```
sudo systemctl enable crunchy_postgres_exporter@postgres_exporter.service
sudo systemctl start crunchy_postgres_exporter@postgres_exporter
sudo systemctl status crunchy_postgres_exporter@postgres_exporter

```

## Running multiple postgres exporters (RHEL7)
Certain metrics are not cluster-wide, so in that case multiple exporters must be run to collect all relevant metrics. The queries_per_db.yml file contains these queries and the secondary exporter(s) can use this file to collect those metrics and avoid duplicating cluster-wide metrics. Note that some other metrics are per database as well (bloat). You can then define multiple targets for that job in Prometheus so that all the metrics are collected together. Note that the "functions_*.sql" file does not need to be run on these additional databases.
```
cd /etc/postgres_exporter/96
cat queries_per_db.yml queries_bloat.yml > queries_mydb.yml
```
You'll need to create a new sysconfig environment file for the second exporter service. You can just copy the existing ones and modify the relevant lines, mainly being the port, database name, and query file 
```
cp /etc/sysconfig/postgres_exporter /etc/sysconfig/postgres_exporter_mydb 

OPT="--web.listen-address=0.0.0.0:9188 --extend.query-path=/etc/postgres_exporter/96/queries_mydb.yml"
DATA_SOURCE_NAME="postgresql://ccp_monitoring@localhost:5432/mydb?sslmode=disable"
```
Since a systemd template is used for the postgres_exporter services, all you need to do is pass the sysconfig file name as part of the new service name.
```
sudo systemctl enable crunchy_postgres_exporter@postgres_exporter_mydb.service
sudo systemctl start cruncy_postgres_exporter@postgres_exporter_mydb
sudo systemctl status crunchy_postgres_exporter@postgres_exporter_mydb

```
Lastly, update the Prometheus auto.d target file to include the new exporter in the same one you already had running for this system

## Note for packaging (RHEL/CENTOS 7)

The service override file(s) must be placed in the relevant drop-in folder to override the default service files.

    /etc/systemd/system/node_exporter.service.d/*.conf

After a daemon-reload, systemd should automatically find these files and the crunchy services should work as intended.
 

## Setup (RHEL/CENTOS 6)

The node_exporter and postgres_exporter services on RHEL6 require the "daemonize" package that is part of the EPEL repository. This can be turned on by running:

    sudo yum install epel-release

All setup for the exporters is the same on RHEL6 as it was for 7 with the exception of the base service files. Whereas RHEL7 uses systemd, RHEL6 uses init.d. The RHEL6 packages will create the base service files for you

    /etc/init.d/crunchy-node-exporter
    /etc/init.d/crunchy-postgres-exporter

Note that these service files are managed by the package and any changes you make to them could be overwritten by future updates. If you need to customize the service files for RHEL6, it's recommended making a copy and editing/using those.

The same /etc/sysconfig files that are used in RHEL7 above are also used in RHEL6, so follow guidance above concerning them and the notes that are contained in the files themselves.

Once the files are in place, set the service to start on boot, then manually start it

    sudo chkconfig crunchy-node-exporter on
    sudo service crunchy-node-exporter start
    sudo service crunchy-node-exporter status

    sudo chkconfig crunchy-postgres-exporter on
    sudo service crunchy-postgres-exporter start
    sudo service crunchy-postgres-exporter status


## Running multiple postgres exporters (RHEL6)
If you need to run multiple postgres_exporter services, follow the same instructions as RHEL7 for making a new queries_XX.yml file to only gather database specific metrics. Then follow the steps below:

    - Make a copy of the /etc/sysconfig file with a new name
    - Update --web.listen-address in the new sysconfig file to use a new port number
    - Update --extend.query-path in the new sysconfig file to point to the new query file generated
    - Update the DATA_SOURCE_NAME in the new sysconfig file to point to the name of the database to be monitored
    - Make a copy of the /etc/init.d/crunchy-postgres-exporter with a new name
    - Update the SYSCONFIG variable in the new init.d file to match the new sysconfig file
    - Update the Prometheus auto.d target file to include the new exporter in the same one you already had running for this system

Remaining steps to initialize service at boot and start it up should be the same as above for the default service.
