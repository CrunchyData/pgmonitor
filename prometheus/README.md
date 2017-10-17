# Setting up Prometheus

## Instructions

https://prometheus.io/download/

* Download prometheus and save prometheus to /usr/bin/prometheus
* Download alertmanager and save alertmanager to /usr/bin/alertmanager
* Modify alertmanager.yml and setup smtp information
* Modify alert-rules.yml and update rules
* Modify auto.d/*.yml file(s) to point to exporter services to auto-discover
* Modify sysconfig.prometheus to set the storage retention period for metric data (default is 1 week) and also the storage location if necessary

## Setup
Create the ccp_monitoring user if it does not yet exist
```
useradd ccp_monitoring -m -d /var/lib/ccp_monitoring
mkdir -p /etc/ccp_monitoring/auto.d
mkdir -p /var/lib/ccp_monitoring/prometheus
cp alertmanager.service prometheus.service /etc/systemd/system/
cp sysconfig.alertmanager /etc/sysconfig/alertmanager
cp sysconfig.prometheus /etc/sysconfig/prometheus
cp alertmanager.yml prometheus.yml alert-rules.yml /etc/ccp_monitoring/
cp auto.d/*.yml /etc/ccp_monitoring/auto.d/
chown -R ccp_monitoring:ccp_monitoring /etc/ccp_monitoring
chown -R ccp_monitoring:ccp_monitoring /var/lib/ccp_monitoring
```
Reload systemd confing
```
systemctl daemon-reload
```
Start services
```
systemctl enable prometheus
systemctl start prometheus
systemctl status prometheus

systemctl enable alertmanager
systemctl start alertmanager
systemctl status alertmanager
```

When Packaging service files shall go in /usr/lib/systemd/system/

