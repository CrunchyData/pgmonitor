# Setting up Prometheus

## Instructions
* Download prometheus and save prometheus to /usr/bin/prometheus
* Download alertmanager and save prometheus to /usr/bin/alertmanager
* Modify alertmanager.yml and setup smtp information
* Modify alert-rules.yml and update rules
* Modify auto.d/*.yml

## Setup
```
useradd ccp_monitoring -m -d /var/lib/ccp_monitoring
cp alertmanager.service prometheus.service /etc/systemd/system/
cp sysconfig.alertmanager /etc/sysconfig/alertmanager
cp sysconfig.prometheus /etc/sysconfig/prometheus
cp alertmanager.yml prometheus.yml /etc/ccp_monitoring/
cp auto.d/*.yml /etc/ccp_monitoring/auto.d/

systemctl daemon-reload
```

| When Packaging service files shall go in /usr/lib/systemd/system/

## Grafana

* Connect to grafana &gt;ip|&lt;:3000
* loging as admin/admin
* Change admin password
* Import all 4 dashboards 
  * PostgreSQL.json
  * PostgreSQLDetails.json
  * BloatDetails.json
  * CRUD_Details.json
