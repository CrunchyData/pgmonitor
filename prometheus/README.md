# Setting up Prometheus

## Installation

* Install latest Prometheus package from Crunchy Repository
* Install latest Alertmanager package from Crunchy Repository
* Install latest pgmonitor-prometheus-extras package
* Install latest pgmonitor-alertmanager-extras package

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
