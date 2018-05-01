# Setting up Prometheus for pgmonitor

Prometheus can be set up on any Linux-based system, but the instructions below use RHEL/CentOS 7.

- [Installation](#installation)
- [Setup](#setup)
   - [RHEL / CentOS 7](#setup-on-rhelcentos-7)

## Installation

### Installation on RHEL/CentOS 7

#### With RPM Packages

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/).

If you install the below available packages with RPM, you can continue reading at the [Setup](#setup) section.

##### Available Packages

| Package Name                  | Description                                       |
|-------------------------------|---------------------------------------------------|
| alertmanager                  | Base package for the Alertmanager                 |
| prometheus2                   | Base package for Prometheus 2.x                   |
| pgmonitor-alertmanager-extras | Custom Crunchy configurations for Alertmanager    |
| pgmonitor-prometheus-extras   | Custom Crunchy configurations for Prometheus      |

#### Without Packages

For installations without using packages, you can download [Prometheus](https://prometheus.io/) and [Alertmanager](https://prometheus.io/docs/alerting/alertmanager/) from [https://prometheus.io/download](https://prometheus.io/download).

##### Minimum Versions

pgmonitor assumes to be using Prometheus 2.x. We recommend to always use the latest minor version of Prometheus.

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

The files contained in this repository are assumed to be installed in the following locations with the following names:

###### Prometheus

The Prometheus data directory should be `/var/lib/ccp_monitoring/prometheus` and owned by the `ccp_monitoring` user.  You can set it up with:

```bash
sudo mkdir /var/lib/ccp_monitoring/prometheus
sudo chmod 0700 /var/lib/ccp_monitoring/prometheus
sudo chown ccp_monitoring /var/lib/ccp_monitoring/prometheus
```

The following pgmonitor configuration files should be placed according to the following mapping:

| pgmonitor Configuration File | System Location |
|------------------------------|-----------------|
| crunchy-prometheus-service-el7.conf | `/etc/systemd/system/prometheus.service.d/crunchy-prometheus-service-el7.conf`  |
| sysconfig.prometheus | `/etc/sysconfig/prometheus` |
| crunchy-prometheus.yml | `/etc/prometheus/crunchy-prometheus.yml` |
| auto.d/ProductionDB.yml.example | `/etc/prometheus/auto.d/ProductionDB.yml.example` |
| crunchy-alertmanager.yml | `/etc/prometheus/crunchy-alertmanager.yml` |
| crunchy-alert-rules.yml | `/etc/prometheus/crunchy-alert-rules.yml` |

###### Alertmanager

The Alertmanager data directory should be `/var/lib/ccp_monitoring/alertmanager` and owned by the `ccp_monitoring` user.  You can set it up with:

```bash
sudo mkdir /var/lib/ccp_monitoring/alertmanager
sudo chmod 0700 /var/lib/ccp_monitoring/alertmanager
sudo chown ccp_monitoring /var/lib/ccp_monitoring/alertmanager
```

The following pgmonitor configuration files should be placed according to the following mapping:

| pgmonitor Configuration File | System Location |
|------------------------------|-----------------|
| crunchy-alertmanager-service-el7.conf | `/etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service-el7.conf`  |
| sysconfig.alertmanager | `/etc/sysconfig/alertmanager` |


## Setup

### Setup on RHEL/CentOS 7

#### Service Configuration

The following files contain defaults that should enable Prometheus and Alertmanager to run effectively on your system for the purposes of using pgmonitor.  You should take some time to review them.

If you need to modify them, see the notes in the files for more details and recommendations:

- `/etc/systemd/system/prometheus.service.d/crunchy-prometheus-service-el7.conf`
- `/etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service-el7.conf`

The below files contain startup properties for Prometheues and Alertmanager.  Please review and modify these files as you see fit:

- `/etc/sysconfig/prometheus`
- `/etc/sysconfig/alertmanager`

The below files dictate how Prometheus and Alertmanager will behave at runtime for the purposes of using pgmonitor.  Please review each file below and follow the instructions in order to set things up:

| File                                     | Instructions |
|------------------------------------------|--------------|
| `/etc/prometheus/crunchy-prometheus.yml` | Modify to set scrape interval if different from the default of 30s. Activate alert rules and Alertmanager by uncommenting lines when set as needed. Default service expects config file to be named `crunchy-prometheus.yml` |
| `/etc/prometheus/crunchy-alertmanager.yml` | Setup alert target (e.g., SMTP, SMS, etc.), receiver and route information. Default service expects config file to be named `crunchy-alertmanager.yml` |
| `/etc/prometheus/crunchy-alert-rules.yml` | Update rules as needed. Default Prometheus config expects file to be named `crunchy-alert-rules.yml` |
| `/etc/prometheus/auto.d/*.yml` | You will need at least one file with a final `.yml` extension. Copy the example file to create as many additional targets as needed.  Ensure the configuration files you want to use do not end in `.yml.example` but only with `.yml`. |

#### Enable Services

To enable and start Prometheus as a service, execute the following commands:

```bash
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
```

To enable and start Alertmanager as a service, execute the following commands:

```bash
sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl status alertmanager
```

## Note for packaging (RHEL/CentOS 7)

The service override files must be placed in the relevant drop-in folder to override the default service files.

```
/etc/systemd/system/prometheus.service.d/crunchy-prometheus-service.conf
/etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service.con
```

After a daemon-reload, systemd should automatically find these files and the crunchy services should work as intended.


### Setup on RHEL/CentOS 6

Detailed instructions coming soon.
