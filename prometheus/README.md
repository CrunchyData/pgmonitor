# Setting up Prometheus

## Installation (RHEL/CENTOS 7)

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the Crunchy Data [access portal](https://access.crunchydata.com/).  Installing these RPMs will take care of all of the steps described in this Installation section. If you install via the RPM, you can continue reading at the [Setup](#setup-rhelcentos-7) section.

Packages available: prometheus2, alertmanager, pgmonitor-prometheus-extras, pgmonitor-alertmanager-extras

For non-package installations, Prometheus & Alertmanager can be downloaded from the developer website (https://prometheus.io/download). The minimum expected versions are Prometheus is 2.0 and Alertmanager 0.12.0. The files contained in this repository are assumed to be installed in the following locations with the following names:
```
Prometheus data folder assumed to be /var/lib/ccp_monitoring/prometheus and owned by ccp_monitoring user. If not, edit sysconfig file appropriately.
- crunchy-prometheus-service-el7.conf -> /etc/systemd/system/prometheus.service.d/crunchy-prometheus-service-el7.conf 
- sysconfig.prometheus -> /etc/sysconfig/prometheus
- crunchy-prometheus.yml -> /etc/prometheus/crunchy-prometheus.yml
- auto.d/ProductionDB.yml.example -> /etc/prometheus/auto.d/ProductionDB.yml.example
- crunchy-alert-rules.yml -> /etc/prometheus/crunchy-alert-rules.yml

Alertmanager data folder assumed to be /var/lib/ccp_monitoring/alertmanager and owned by ccp_monitoring user. If not, edit sysconfig file appropriately.
- crunchy-alertmanager-service-el7.conf -> /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service-el7.conf
- sysconfig.alertmanager -> /etc/sysconfig/alertmanager
```
## Setup (RHEL/CENTOS 7)

* If necessary, modify /etc/systemd/system/prometheus.service.d/crunchy-prometheus-service-el7.conf. See notes in example file for more details.
* If necessary, modify /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service-el7.conf. See notes in example file for more details.
* If necessary, modify /etc/sysconfig/prometheus to set prometheus startup properties. See notes within the file itself for recommendations.
* If necessary, modify /etc/sysconfig/alertmanager to set alertmanager startup properties. See notes within the file itself for recommendations.
* Modify /etc/prometheus/crunchy-prometheus.yml to set scrape interval if different from default. Activate alert rules and alertmanager by uncommenting lines when set as needed. Default service expects config file to be named crunchy-prometheus.yml.
* Modify /etc/prometheus/crunchy-alertmanager.yml and setup alert target (smtp, sms, etc), receiver and route information. Default service expects config file to be named crunchy-alertmanager.yml
* Modify /etc/prometheus/crunchy-alert-rules.yml and update rules as needed. Default prometheus config expects file to be named crunchy-alert-rules.yml.
* Modify /etc/prometheus/auto.d/*.yml.example file(s) to point to exporter services to auto-discover. Copy example file to create as many additional targets as needed. Remove .example suffix when configuration is final and Prometheus will auto-discover.

## Start services (RHEL/CENTOS 7)
```
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus

sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl status alertmanager
```

## Note for packaging (RHEL/CENTOS 7)

The service override files must be placed in the relevant drop-in folder to override the default service files.

    /etc/systemd/system/prometheus.service.d/crunchy-prometheus-service.conf
    /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service.conf

After a daemon-reload, systemd should automatically find these files and the crunchy services should work as intended.
    

## Setup (RHEL/CENTOS 6)
TODO
