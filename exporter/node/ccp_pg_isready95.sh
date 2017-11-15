#!/usr/bin/env bash

PGDIR=/var/lib/ccp_monitoring/node_exporter
PGTMP=is_pgready-9.5.tmp
PGFILE=is_pgready-9.5.prom
PGBIN=/usr/pgsql-9.5/bin
if [ ! -d ${PGDIR} ]; then
  mkdir ${PGDIR}
fi
rm -f ${PGDIR}/${PGTMP}
$PGBIN/pg_isready -d postgres >/dev/null
EX_VAL=$?
if [ $EX_VAL -eq  0 ]; then
	echo "ccp_pg_ready 1" >>${PGDIR}/${PGTMP}
else
	echo "ccp_pg_ready 0" >>${PGDIR}/${PGTMP}
fi
mv ${PGDIR}/${PGTMP} ${PGDIR}/${PGFILE}
