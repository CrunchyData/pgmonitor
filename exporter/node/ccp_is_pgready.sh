#!/usr/bin/env bash

set -e
IODIR=/var/lib/ccp_monitoring
IOTMP=is_pgready.tmp
IOFILE=io_pgready.prom
PGBIN=/usr/pgsql-9.6/bin
if [ ! -d ${IODIR} ]; then
  mkdir ${IODIR}
fi
rm -f ${IODIR}/${IOTMP}
$PGBIN/pg_isready >/dev/null
EX_VAL=$?
if [ $EX_VAL -eq  0 ]; then
	echo "ccp_pg_ready 1" >>${IODIR}/${IOTMP}
else
	echo "ccp_pg_ready 0" >>${IODIR}/${IOTMP}
fi
mv ${IODIR}/${IOTMP} ${IODIR}/${IOFILE}
