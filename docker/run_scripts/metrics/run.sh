#!/bin/bash

# Copyright 2018 Crunchy Data Solutions, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo "Starting metrics example..."

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
$DIR/cleanup.sh

docker volume create --driver local --name=metrics-volume
docker volume create --driver local --name=pgsql-volume
docker network create --driver bridge pgnet

echo "Starting PostgreSQL container.."
docker run \
    --name="crunchy-pgsql" \
    --hostname="crunchy-pgsql" \
    -p 5432:5432 \
    -v pgsql-volume:/pgdata \
    --network="pgnet" \
    --env-file=./run_scripts/metrics/env/pgsql.list \
    -d crunchy-postgres:latest

echo "Starting Collect container.."
docker run \
    --name="crunchy-collect" \
    --hostname="crunchy-collect" \
    --network="pgnet" \
    --env-file=./run_scripts/metrics/env/collect.list \
    -d crunchy-collect:latest

echo "Starting Prometheus container.."
docker run \
    --name="crunchy-prometheus" \
    --hostname="crunchy-prometheus" \
    -p 9090:9090 \
    -v metrics-volume:/data \
    --network="pgnet" \
    --env-file=./run_scripts/metrics/env/prometheus.list \
    -d crunchy-prometheus:latest

echo "Starting Grafana container.."
docker run \
    --name="crunchy-grafana" \
    --hostname="crunchy-grafana" \
    -p 3000:3000 \
    -v metrics-volume:/data \
    --network="pgnet" \
    --env-file=./run_scripts/metrics/env/grafana.list \
    -d crunchy-grafana:latest

exit 0
