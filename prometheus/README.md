# Setting up Prometheus

## Installation

* Install latest Prometheus package from Crunchy Repository
* Install latest Alertmanager package from Crunchy Repository
* Install latest crunchy-monitoring-prometheus-extras package
* Install latest crunchy-monitoring-alertmanager-extras package

## Setup

* Modify crunchy-prometheus.yml to set scrape interval if different from default. Activate alert rules and alertmanager by uncommenting lines when set as needed.
* Modify crunchy-alertmanager.yml and setup alert target (smtp, sms, etc), receiver and route information
* Modify crunchy-alert-rules.yml and update rules as needed
* Modify auto.d/*.yml.sample file(s) to point to exporter services to auto-discover. Copy sample file to create as many additional targets as needed. Remove .sample suffix when configuration is final and Prometheus will auto-discover.
* Modify sysconfig.prometheus to set the storage retention period for metric data (default is 1 week) and also the storage location if necessary


## Start services
```
systemctl enable prometheus
systemctl start prometheus
systemctl status prometheus

systemctl enable alertmanager
systemctl start alertmanager
systemctl status alertmanager
```

## Note for packaging

The service override files must be placed in the relevant drop-in folder to override the default service files.

    /etc/systemd/system/prometheus.service.d/crunchy-prometheus-service.conf
    /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service.conf

After a daemon-reload, systemd should automatically find these files and the crunchy services should work as intended.
    
