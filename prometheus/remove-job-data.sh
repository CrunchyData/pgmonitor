#!/usr/bin/env bash
CCP_DIR=/etc/prometheus
CCP_SVC_DIR=${CCP_DIR}/auto.d
JOBNAME=$1

if [ "${JOBNAME}" = "" ]; then
  echo "Usage: $0 <job name>"
  exit 1
else
  grep $JOBNAME ${CCP_DIR}/prometheus.yml ${CCP_SVC_DIR}/*.yml &>/dev/null
  EX_VAL=$?
  if [ $EX_VAL = 1 ]; then
    curl -XDELETE -g "http://localhost:9090/api/v1/series?match[]={job='${JOBNAME}'}"
    exit 0
  elif [ $EX_VAL = 2 ]; then
    echo "Unable to access config files ${CCP_DIR}/prometheus.yml ${CCP_SVC_DIR}/*.yml"
    exit 2
  else
    echo "Can not delete data for ${JOBNAME}, still referenced in configuration"
    exit 3
  fi
fi

