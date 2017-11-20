# Setting up Prometheus

## Installation

* Install latest Prometheus package from Crunchy Repository
* Install latest Alertmanager package from Crunchy Repository
* Install latest crunchy-monitoring-prometheus-extras package
* Install latest crunchy-monitoring-alertmanager-extras package

## Setup (RHEL/CENTOS 7)

* Copy/Rename & modify /etc/systemd/system/prometheus.service.d/crunchy-prometheus-el7.service.example to uncomment necessary lines to override default prometheus service. See notes in example file for more details.
* Copy/Rename & modify /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-el7.service.example to uncomment necessary lines to override default alertmanager service. See notes in example file for more details.
* Copy/Rename & modify /etc/sysconfig/prometheus.example as necessary. See notes within the file itself for recommendations.
* Copy/Rename & modify /etc/sysconfig/alertmanager.example as necessary. See notes within the file itself for recommendations.
* Copy/Rename & modify /etc/prometheus/crunchy-prometheus.yml.example to set scrape interval if different from default. Activate alert rules and alertmanager by uncommenting lines when set as needed. Default service expects config file to be named crunchy-prometheus.yml.
* Copy/Rename & modify crunchy-alertmanager.yml.example and setup alert target (smtp, sms, etc), receiver and route information. Default service expects config file to be named crunchy-alertmanager.yml
* Copy/Rename & modify /etc/prometheus/crunchy-alert-rules.yml.example and update rules as needed. Default prometheus config expects file to be named crunchy-alert-rules.yml.
* Modify auto.d/*.yml.sample file(s) to point to exporter services to auto-discover. Copy sample file to create as many additional targets as needed. Remove .sample suffix when configuration is final and Prometheus will auto-discover.

## Start services (RHEL/CENTOS 7)
```
systemctl enable prometheus
systemctl start prometheus
systemctl status prometheus

systemctl enable alertmanager
systemctl start alertmanager
systemctl status alertmanager
```

## Note for packaging (RHEL/CENTOS 7)

The service override files must be placed in the relevant drop-in folder to override the default service files.

    /etc/systemd/system/prometheus.service.d/crunchy-prometheus-service.conf
    /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service.conf

After a daemon-reload, systemd should automatically find these files and the crunchy services should work as intended.
    

## Setup (RHEL/CENTOS 6)
TODO
