#!/usr/bin/env bash

# Currently waiting on tombstone cleaning command in next version of prometheus after 2.0.0
# This just marks the data as deleted, but doesn't actually remove it from disk nor remove the job name

CCP_DIR=/etc/prometheus
CCP_SVC_DIR=${CCP_DIR}/auto.d
JOBNAME=$1

if [ "${JOBNAME}" = "" ]; then
  echo "Usage: $0 <job name>"
  exit 1
else
  grep 'job:' ${CCP_DIR}/prometheus.yml ${CCP_SVC_DIR}/*.yml 2>/dev/null | grep "\<${JOBNAME}\>" &>/dev/null
  EX_VAL=$?
  if [ $EX_VAL = 1 ]; then
    HTTPCODE="\n%{http_code}"
    curl -sw "${HTTPCODE}" -X POST -d \
      "{
          \"matchers\": [{
          \"type\": \"EQ\",
          \"name\": \"job\",
          \"value\": \"${JOBNAME}\"
          }]
      }" \
      -H "Content-Type: application/json" http://localhost:9090/api/v2/admin/tsdb/delete_series

## Example:       
#    /api/v2/admin/tsdb/delete_series`, with the body of the format:
#{
#	"min_time": "2017-11-15T00:0:0+00:00",
#	"max_time": "2017-11-15T00:37:20+00:00",
#	"matchers": [{
#		"type": "EQ",
#		"name": "job",
#		"value": "prometheus"
#	}]
#}
#

    exit 0
  elif [ $EX_VAL = 2 ]; then
    echo "Unable to access config files ${CCP_DIR}/prometheus.yml ${CCP_SVC_DIR}/*.yml"
    exit 2
  else
    echo "Can not delete data for ${JOBNAME}, still referenced in configuration"
    exit 3
  fi
fi

