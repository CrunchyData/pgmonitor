#!/usr/bin/env bash
###
#
# Copyright 2017-2021 Crunchy Data Solutions, Inc. All Rights Reserved.
#
###

# Additional metric option to monitor disk queue depth with node_exporter. Set the DISK variable to the disk system that is to be monitored

OUTPUTDIR=/var/lib/ccp_monitoring/node_exporter
VERTMP=backrest_version.tmp
VERFILE=backrest_version.prom
if [ ! -d ${OUTPUTDIR} ]; then
  mkdir ${OUTPUTDIR}
fi
rm -f ${OUTPUTDIR}/${VERTMP}
cat <<EOF >${OUTPUTDIR}/${VERTMP}
HELP ccp_backrest_version The version of pgBackRest installed on this system
TYPE ccp_backrest_version gauge
ccp_backrest_version{} $(pgbackrest version | cut -d ' ' -f 2)
EOF
mv ${OUTPUTDIR}/${VERTMP} ${OUTPUTDIR}/${VERFILE}
