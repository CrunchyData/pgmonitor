# Setting up exporters for pgmonitor

The exporters below can be set up on any Linux-based system, but the instructions below use RHEL/CentOS 7.

- [Installation](#installation)
- [Setup](#setup)
   - [RHEL / CentOS 7](#setup-on-rhelcentos-7)
   - [RHEL / CentOS 6](#installationsetup-on-rhelcentos-6)

## Installation

### Installation on RHEL/CentOS 7

#### With RPM Packages

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/).

If you install the below available packages with RPM, you can continue reading at the [Setup](#setup) section.

##### Available Packages

| Package Name                  |
|-------------------------------|
| node_exporter                 |
| pg_bloat_check                |
| pgmonitor-pg10-extras         |
| pgmonitor-pg96-extras         |
| pgmonitor-pg95-extras         |
| pgmonitor-pg94-extras         |
| postgres_exporter             |

#### Without Packages

For non-package installations, the exporters & pg_bloat_check can be downloaded from their respective repositories:

| Library                       |            |
|-------------------------------|------------|
| node_exporter                 | https://github.com/prometheus/node_exporter/releases |
| postgres_exporter             | https://github.com/wrouesnel/postgres_exporter/releases |
| pg_bloat_check                | https://github.com/keithf4/pg_bloat_check |

##### User and Configuration Directory Installation

You will need to create a user named `ccp_monitoring` which you can do with the following command:

```bash
sudo useradd ccp_monitoring
```

Create a folder in `/var/lib/` and set its permissions as such:

```bash
sudo mkdir /var/lib/ccp_monitoring
sudo chmod 0700 /var/lib/ccp_monitoring
sudo chown ccp_monitoring /var/lib/ccp_monitoring
```

##### Configuration File Installation

All executables are expected to be in the `/usr/bin` directory. A base node_exporter systemd file is expected to be in place already. An example one can be found here:

https://github.com/lest/prometheus-rpm/tree/master/node_exporter

The files contained in this repository are assumed to be installed in the following locations with the following names. In the instructions below, you should replace a double-hash (`##`) with the two-digit major version of PostgreSQL you are running (ex: 95, 96, 10, etc.).

##### node_exporter

The node_exporter data directory should be `/var/lib/ccp_monitoring/node_exporter` and owned by the `ccp_monitoring` user.  You can set it up with:

```bash
sudo mkdir /var/lib/ccp_monitoring/node_exporter
sudo chmod 0700 /var/lib/ccp_monitoring/node_exporter
sudo chown ccp_monitoring /var/lib/ccp_monitoring/node_exporter
```

The following pgmonitor configuration files should be placed according to the following mapping:

| pgmonitor Configuration File | System Location |
|------------------------------|-----------------|
| node/crunchy-node-exporter-service-el7.conf | `/etc/systemd/system/node_exporter.service.d/crunchy-node-exporter-service-el7.conf`  |
| node/sysconfig.prometheus | `/etc/sysconfig/node_exporter` |
| node/ccp_pg_isready##.sh | `/usr/bin/ccp_pg_isready##.sh` |

##### postgres_exporter

The following pgmonitor configuration files should be placed according to the following mapping:

| pgmonitor Configuration File | System Location |
|------------------------------|-----------------|
| crontab##.txt | `/etc/postgres_exporter/##/crontab##.txt`  |
| postgres/crunchy_postgres_exporter@.service | `/usr/lib/systemd/system/crunchy_postgres_exporter@.service`  |
| postgres/sysconfig.postgres_exporter_pg## | `/etc/sysconfig/postgres_exporter_pg##`  |
| postgres/functions_pg##.sql | `/etc/postgres_exporter/##/functions_pg##.sql`  |
| postgres/queries_pg##.yml | `/etc/postgres_exporter/##/queries_pg##.yml`  |
| postgres/queries_common.yml | `/etc/postgres_exporter/##/queries_common.yml`  |
| postgres/queries_per_db.yml | `/etc/postgres_exporter/##/queries_per_db.yml`  |
| postgres/queries_bloat.yml | `/etc/postgres_exporter/##/queries_bloat.yml`  |
| postgres/queries_pg_stat_statements.ymll | `/etc/postgres_exporter/##/queries_pg_stat_statements.yml`  |


Make sure `/etc/sysconfig/postgres_exporter` is symlinked to `/etc/sysconfig/postgres_exporter_pg##`. For example, if you are monitoring PostgreSQL 10, you can use the following command:

```bash
sudo ln -s /etc/sysconfig/postgres_exporter_pg10 /etc/sysconfig/postgres_exporter
```

## Setup

### Setup on RHEL/CentOS 7

#### Service Configuration

The following files contain defaults that should enable the exporters to run effectively on your system for the purposes of using pgmonitor.  You should take some time to review them.

If you need to modify them, see the notes in the files for more details and recommendations:
- `/etc/systemd/system/node_exporter.service.d/crunchy-node-exporter-service-el7.conf`
- `/etc/sysconfig/node_exporter`
- `/etc/sysconfig/postgres_exporter`

Note that `/etc/sysconfig/postgres_exporter` is a symlink to avoid issues during major version upgrades of PostgreSQL.

##### Crontab for pg_bloat_check

In the default pgmonitor setup, the `pg_bloat_check.py` script is meant to be run by the `ccp_monitoring` user created earlier.  The `/etc/postgres_exporter/##/crontab.txt` file (where "##" is your PostgreSQL version, e.g. `10`) is meant to be a guide for how you setup your _crontab_. You should modify crontab entries to schedule your bloat check for off-peak hours.

If you want to run `pg_bloat_check.py`, install the entries in the crontab of the `ccp_monitoring` user.

#### Database Configuration

##### General Configuration

First, make sure you have installed the PostgreSQL contrib modules.  You can install them with the following command:

```bash
sudo yum install postgresqlXX-contrib
```

Where `XX` corresponds to your current PostgreSQL version.  For PostgreSQL 10 this would be:

```bash
sudo yum install postgresql10-contrib
```

You will need to modify your `postgresql.conf` configuration file to tell PostgreSQL to load shared libraries. In the default setup, this file can be found at `/var/lib/pgsql/10/data/postgresql.conf`.

Modify your `postgresql.conf` configuration file to add the following shared libraries

```
shared_preload_libraries = 'pg_stat_statements,auto_explain'
```

You will need to restart your PostgreSQL instance for the change to take effect.

For each database you are planning to monitor, you will need to run the following command as a PostgreSQL superuser:

```sql
CREATE EXTENSION pg_stat_statements;
```

If you want for the `pg_stat_statements` extension to be available in all newly created databases, you can run the following command as a PostgreSQL superuser:

```bash
psql -d template1 -c "CREATE EXTENSION pg_stat_statements;"
```

##### Monitoring Setup

Install functions to all databases you will be monitoring in the cluster (if you don't have `pg_stat_statements` installed, you can ignore the error given). The queries common to all postgres versions are contained in `queries_common.yml`. Major version specific queries are contained in a relevantly named file. Queries for more specialized monitoring are contained in additional files. postgres_exporter only takes a single query file as an argument for custom queries, so cat together the queries necessary into a single file.

For example, to use just the common queries for PostgreSQL 9.6 do the following. Note the location of the final queries file is based on the major version installed. The exporter service will look in the relevant version folder in the ccp_monitoring directory:

```bash
cd /etc/postgres_exporter/96
cat queries_common.yml queries_per_db.yml queries_pg92-96.yml > queries.yml
psql -f /etc/postgres_exporter/96/functions_pg92-96.sql
```
As another example, to include queries for PostgreSQL 10 as well as pg_stat_statements and bloat do the following:

```bash
cd /etc/postgres_exporter/10
cat queries_common.yml queries_per_db.yml queries_pg10.yml queries_pg_stat_statements.yml queries_bloat.yml > queries.yml
psql -f /etc/postgres_exporter/10/functions_pg10.sql
```

For replica servers, the setup is the same except that the functions_pg##.sql file does not need to be run since writes cannot be done there and it was already run on the master.

###### Access Control: GRANT statements

The `ccp_monitoring` database role (created by running the "functions_pg##.sql" file above) must be allowed to connect to all databases in the cluster. To do this, run the following command to generate the necessary GRANT statements:

```sql
SELECT 'GRANT CONNECT ON DATABASE "' || datname || '" TO ccp_monitoring;'
FROM pg_database
WHERE datallowconn = true;
```
This should generate one or more statements similar to the following:

```sql
GRANT CONNECT ON DATABASE "postgres" TO ccp_monitoring;
```

###### Bloat setup

Run script on the specific database(s) you will be monitoring bloat for in the cluster. See special note in crontab.txt concerning a superuser requirement for using this script

```bash
psql -d postgres -c "CREATE EXTENSION pgstattuple;"
/usr/bin/pg_bloat_check.py -c "host=localhost dbname=postgres user=postgres" --create_stats_table
psql -d postgres -c "GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON bloat_indexes, bloat_stats, bloat_tables TO ccp_monitoring;"
```

#### Enable Services

```bash
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

To most easily allow the possibility of multiple postgres exporters and avoid maintaining many similar service files, a systemd template service file is used. The name of the sysconfig EnvironmentFile to be used by the service is passed as the value after the "@" and before ".service" in the service name. The default exporter's EnvironmentFile is named "postgres_exporter".

```bash
sudo systemctl enable crunchy_postgres_exporter@postgres_exporter.service
sudo systemctl start crunchy_postgres_exporter@postgres_exporter
sudo systemctl status crunchy_postgres_exporter@postgres_exporter

```

### Running multiple postgres exporters (RHEL / CentOS 7)

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


## Installation / Setup on RHEL/CentOS 6

The node_exporter and postgres_exporter services on RHEL6 require the "daemonize" package that is part of the EPEL repository. This can be turned on by running:

    sudo yum install epel-release

All setup for the exporters is the same on RHEL6 as it was for 7 with the exception of the base service files. Whereas RHEL7 uses systemd, RHEL6 uses init.d. The Crunchy RHEL6 packages will create the base service files for you

    /etc/init.d/crunchy-node-exporter
    /etc/init.d/crunchy-postgres-exporter

Note that these service files are managed by the package and any changes you make to them could be overwritten by future updates. If you need to customize the service files for RHEL6, it's recommended making a copy and editing/using those.

Or if you are setting this up manually, the repository file locations and expected directories are:

```bash
node/crunchy-node-exporter-el6.service -> /etc/init.d/crunchy-postgres-exporter
postgres/crunchy-postgres-exporter-el6.service -> /etc/init.d/crunchy-postgres-exporter

/var/run/postgres_exporter/
/var/log/postgres_exporter/ (owned by postgres_exporter service user)

/var/run/node_exporter/
/var/log/node_exporter/ (owned by node_exporter service user)
```

The same /etc/sysconfig files that are used in RHEL7 above are also used in RHEL6, so follow guidance above concerning them and the notes that are contained in the files themselves.

Once the files are in place, set the service to start on boot, then manually start it

```bash
sudo chkconfig crunchy-node-exporter on
sudo service crunchy-node-exporter start
sudo service crunchy-node-exporter status

sudo chkconfig crunchy-postgres-exporter on
sudo service crunchy-postgres-exporter start
sudo service crunchy-postgres-exporter status
```

### Running multiple postgres exporters (RHEL / CentOS 6)
If you need to run multiple postgres_exporter services, follow the same instructions as RHEL / CentOS 7 for making a new queries_XX.yml file to only gather database specific metrics. Then follow the steps below:

    - Make a copy of the /etc/sysconfig file with a new name
    - Update --web.listen-address in the new sysconfig file to use a new port number
    - Update --extend.query-path in the new sysconfig file to point to the new query file generated
    - Update the DATA_SOURCE_NAME in the new sysconfig file to point to the name of the database to be monitored
    - Make a copy of the /etc/init.d/crunchy-postgres-exporter with a new name
    - Update the SYSCONFIG variable in the new init.d file to match the new sysconfig file
    - Update the Prometheus auto.d target file to include the new exporter in the same one you already had running for this system

Remaining steps to initialize service at boot and start it up should be the same as above for the default service.
