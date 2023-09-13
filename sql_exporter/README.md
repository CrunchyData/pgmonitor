# sql_exporter Setup

Note this is just an example setup for a PoC. The actual setup will have many of the same steps, but of course won't have cleartext password setup instructions.

Make the pgmonitor_extension available to be installed. See the README in the `pgmonitor_extension` folder. Do not install the extension in the database yet, just do the `make install` (or install package if available). We'll be using a setup file below to do that.

Install the pgmonitor extras package for the relevant version of PG from the Crunchy Repos for right now to set up the ccp_monitoring system user.
```
sudo dnf install pgmonitor-pg##-extras.noarch
```
Set up a pgpass file for the `ccp_monitoring` system user in `/var/lib/ccp_monitoring`
```
*:*:*:ccp_monitoring:stuff
```

Download sql_exporter from https://github.com/burningalchemist/sql_exporter. Binaries and packages for most OS's are available. 
```
wget https://github.com/burningalchemist/sql_exporter/releases/download/0.12.1/sql_exporter-0.12.1.linux-amd64.tar.gz
tar xvzf sql_exporter-0.12.1.linux-amd64.tar.gz
cp sql_exporter-0.12.1.linux-amd64/sql_exporter /usr//bin/
```
RPM is available, but the service that it sets up does not work. Use the following service files included in this repo

```
cp pgmonitor/sql_exporter/linux/sql-exporter@.service /usr/lib/systemd/system/sql-exporter@.service
cp pgmonitor/sql_exporter/linux/sql_exporter.sysconfig /etc/sysconfig/sql_exporter

systemctl daemon-reload

systemctl enable sql-exporter@sql_exporter
```

Copy all files in the `common` folder to `/etc/sql_exporter/`
```
mkdir /etc/sql_exporter
cp pgmonitor/sql_exporter/common/* /etc/sql_exporter/
```

Run the `setup_db.sql` file on each database to be monitored. This will create the proper database roles and install the extension into the schema that sql_exporter is currently configured to use. The pgpass file created earlier should allow this to "just work"
```
psql -f /etc/sql_exporter/setup_db.sql
```
Start the sql_exporter
```
systemctl start sql-exporter@sql_exporter
```
Check the output for metrics starting with `ccp_`. If not working, check the postgresql logs or the syslogs for errors


