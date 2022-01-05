#!/usr/bin/env bash
###
#
# Copyright 2017-2022 Crunchy Data Solutions, Inc. All Rights Reserved.
#
###

# Additional metric option to monitor pgBackRest version

OUTPUTDIR=/var/lib/ccp_monitoring/node_exporter
VERTMP="$(mktemp ${OUTPUTDIR}/ccp_backrest_versionXXX)"
VERFILE=ccp_backrest_version.prom
if [ ! -d ${OUTPUTDIR} ]; then
  mkdir -p ${OUTPUTDIR}
fi
cat <<EOF >${VERTMP}
# HELP ccp_backrest_version The version of pgBackRest installed on this system
# TYPE ccp_backrest_version gauge
ccp_backrest_version{} $(pgbackrest version | cut -s -d ' ' -f 2)
EOF
mv ${VERTMP} ${OUTPUTDIR}/${VERFILE}

