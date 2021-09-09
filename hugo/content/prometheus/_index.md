---
title: "Setting up Prometheus"
draft: false
weight: 2
---

Prometheus can be set up on any Linux-based system, but pgMonitor currently only supports running it on RHEL/CentOS 7 or later.

- [Installation](#installation)
    - [RHEL / CentOS](#rhel-centos)
- [Upgrading](#upgrading)
- [Setup](#setup)
    - [RHEL / CentOS](#setup-on-rhel-centos)

## Installation {#installation}

### RHEL / CentOS {#rhel-centos}

#### With RPM Packages

There are RPM packages available to [Crunchy Data](https://www.crunchydata.com) customers through the [Crunchy Customer Portal](https://access.crunchydata.com/).

After installing via these RPMs, you can continue reading at the [Setup](#setup) section.

##### Available Packages

| Package Name                  | Description                                       |
|-------------------------------|---------------------------------------------------|
| alertmanager                  | Base package for the Alertmanager                 |
| prometheus2                   | Base package for Prometheus 2.x                   |
| pgmonitor-alertmanager-extras | Custom Crunchy configurations for Alertmanager    |
| pgmonitor-prometheus-extras   | Custom Crunchy configurations for Prometheus      |

#### Without Crunchy Data Packages

For installations without using packages provided by Crunchy Data, we recommend using the repository maintained at https://github.com/lest/prometheus-rpm. Instructions for setup and installation are contained there. Note this only sets up the base service. The additional files and steps for pgMonitor still need to be set up as instructed below.

Or you can also download [Prometheus](https://prometheus.io/) and [Alertmanager](https://prometheus.io/docs/alerting/alertmanager/) from the original site at [https://prometheus.io/download](https://prometheus.io/download). Note that no base service setup is provided here, just the binaries.

##### Minimum Versions

pgMonitor assumes to be using at least Prometheus 2.9.x. We recommend to always use the latest minor version of Prometheus.

##### User and Configuration Directory Installation

You will need to create a system user named {{< shell >}}ccp_monitoring{{< /shell >}} which you can do with the following command:

```bash
sudo useradd -d /var/lib/ccp_monitoring ccp_monitoring
```

##### Configuration File Installation

The files contained in this repository are assumed to be installed in the following locations with the following names:

###### Prometheus

The Prometheus data directory should be {{< shell >}}/var/lib/ccp_monitoring/prometheus{{< /shell >}} and owned by the {{< shell >}}ccp_monitoring{{< /shell >}} user.  You can set it up with:

```bash
sudo install -d -m 0700 -u ccp_monitoring -g ccp_monitoring /var/lib/ccp_monitoring/prometheus
```

The following pgmonitor configuration files should be placed according to the following mapping:

| pgMonitor Configuration File | System Location |
|------------------------------|-----------------|
| prometheus/linux/crunchy-prometheus-service-rhel.conf | /etc/systemd/system/prometheus.service.d/crunchy-prometheus-service-rhel.conf  |
| prometheus/linux/sysconfig.prometheus | /etc/sysconfig/prometheus |
| prometheus/linux/crunchy-prometheus.yml | /etc/prometheus/crunchy-prometheus.yml |
| prometheus/linux/auto.d/\*.yml.example | /etc/prometheus/auto.d/*.yml.example |
| prometheus/linux/alert-rules.d/crunchy-alert-rules\*.yml.example | /etc/prometheus/alert-rules.d/crunchy-alert-rules-\*.yml.example |
| prometheus/common/auto.d/\*.yml.example | /etc/prometheus/auto.d/*.yml.example |
| prometheus/common/alert-rules.d/crunchy-alert-rules\*.yml.example | /etc/prometheus/alert-rules.d/crunchy-alert-rules-\*.yml.example |

###### Alertmanager

The Alertmanager data directory should be `/var/lib/ccp_monitoring/alertmanager` and owned by the `ccp_monitoring` user.  You can set it up with:

```bash
sudo install -d -m 0700 -o ccp_monitoring -g ccp_monitoring /var/lib/ccp_monitoring/alertmanager
```

The following pgMonitor configuration files should be placed according to the following mapping:

| pgMonitor Configuration File | System Location |
|------------------------------|-----------------|
| alertmanager/linux/crunchy-alertmanager-service-rhel.conf | /etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service-rhel.conf |
| alertmanager/linux/sysconfig.alertmanager | /etc/sysconfig/alertmanager |
| alertmanager/common/crunchy-alertmanager.yml | /etc/prometheus/crunchy-alertmanager.yml |


### Upgrading {#upgrading}

Please review the ChangeLog for any changes that may be relevant to your environment.

Of note, items like the alert rules and configuration files often require user edits. The packages will install newer versions of these files, but if the user has changed their contents but kept the same file name, the package will not overwrite them. Instead it will make a file with an {{< shell >}}*.rpmnew{{< /shell >}} extension that contains the newer version of the file. These new files can be reviewed/compared to he user's file to incorporate any desired changes.

## Setup {#setup}

### Setup on RHEL/CentOS {#setup-on-rhel-centos}

#### Service Configuration

The following files contain defaults that should enable Prometheus and Alertmanager to run effectively on your system for the purposes of using pgmonitor.  You should take some time to review them.

If you need to modify them, see the notes in the files for more details and recommendations:

- {{< shell >}}/etc/systemd/system/prometheus.service.d/crunchy-prometheus-service-rhel.conf{{< /shell >}}
- {{< shell >}}/etc/systemd/system/alertmanager.service.d/crunchy-alertmanager-service-rhel.conf{{< /shell >}}

The below files contain startup properties for Prometheues and Alertmanager.  Please review and modify these files as you see fit:

- {{< shell >}}/etc/sysconfig/prometheus{{< /shell >}}
- {{< shell >}}/etc/sysconfig/alertmanager{{< /shell >}}

The below files dictate how Prometheus and Alertmanager will behave at runtime for the purposes of using pgMonitor.  Please review each file below and follow the instructions in order to set things up:

| File                                     | Instructions |
|------------------------------------------|--------------|
| /etc/prometheus/crunchy-prometheus.yml | Modify to set scrape interval if different from the default of 30s. Activate alert rules and Alertmanager by uncommenting lines when set as needed. Activate blackbox_exporter monitoring if desired. Service file provided by pgMonitor expects config file to be named `crunchy-prometheus.yml` |
| /etc/prometheus/crunchy-alertmanager.yml | Setup alert target (e.g., SMTP, SMS, etc.), receiver and route information. Service file provided by pgMonitor expects config file to be named `crunchy-alertmanager.yml` |
| /etc/prometheus/alert-ruled.d/crunchy-alert-rules-\*.yml.example | Update rules as needed and remove `.example` suffix. Prometheus config provided by pgmonitor expects `.yml` files to be located in `/etc/prometheus/alert-rules.d/` |
| /etc/prometheus/auto.d/*.yml | You will need at least one file with a final `.yml` extension. Copy the example files to create as many additional targets as needed.  Ensure the configuration files you want to use do not end in `.yml.example` but only with `.yml`. Note that in order to use the provided Grafana dashboards, the extra "exp_type" label must be applied to all targets and be set appropriately (pg or node). Also, PostgreSQL targets make use of the "cluster_name" variable and should be given a relevant value so all systems (primary & replicas) can be related to each other when needed (Grafana dashboards, etc). See the example target files provided for how to set the labels for postgres or node exporter targets. |

#### Blackbox Exporter

By default, the Blackbox exporter probes are commented out in the {{< shell >}}crunchy-prometheus.yml{{< /shell >}} file; please see the notes in that commented out section. For the default IPv4 TCP port targets that pgMonitor configures the blackbox_exporter with, the desired monitoring targets can be configured under the {{ yaml }}static_configs: targets{{ /yaml }} section of the {{ yaml }}blackbox_tcp_services{{ /yaml }} job; some examples for Grafana & Patroni are given there. It is also possible to create another auto-scrape target directory similar to {{< shell >}}auto.d{{< /shell >}} and manage your blackbox targets more dynamically.

If you configure additional probes beyond the one that pgMonitor comes with, you will need to create a different Prometheus {{< yaml >}}job_name{{< /yaml >}} for them for the given {{< yaml >}}params: module{{< /yaml >}} name.

An example rules file for monitoring Blackbox probes, {{< shell >}}crunchy-alert-rules-blackbox.yml.example{{< /shell >}}, is available in the {{< shell >}}alert-rules.d{{< /shell >}} folder.

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
