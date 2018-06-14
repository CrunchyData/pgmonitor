#!/usr/bin/env bash

P_LEVELS=('WARNING' 'ERROR' 'FATAL')
P_COUNTS=(0 0 0)
P_DIR=/var/lib/ccp_monitoring/node_exporter
P_TMP=is_pgready-10.tmp
P_FILE=is_pgready-10.prom
P_BIN=/usr/pgsql-10/bin
P_DATA=${PGDATA:-/var/lib/pgsql/10/data}
P_FREQUENCY=5 #In minutes
#################################

isReady() {
  $P_BIN/pg_isready -d postgres >/dev/null
  EX_VAL=$?
  if [ $EX_VAL -eq  0 ]; then
    REC=$(psql -d postgres -Atc 'select pg_is_in_recovery()')
    if [ "$REC" = "f" ]; then
      echo "ccp_pg_ready 2" >>${P_DIR}/${P_TMP}
    else
      echo "ccp_pg_ready 1" >>${P_DIR}/${P_TMP}
    fi
  else
    echo "ccp_pg_ready 0" >>${P_DIR}/${P_TMP}
  fi
}

isEvent() {

P_FILE_TC=${P_DIR}/tailncount.txt
[ -f ${P_FILE_TC} ] && . ${P_FILE_TC}
P_O_LOGFILE=${LAST_LOGFILE:-""}
P_O_OFFSET=${LAST_OFFSET:-0}

LOGDIR=$(psql -d postgres -Atc 'show log_directory;')
LOGFILE=$(psql -d postgres -Atc 'show log_filename;')
LDSTART=${LOGDIR:0:1}
P_FILENAME=$(date -d "${P_FREQUENCY} minutes ago" "+${LOGFILE}")
if [[ LDSTART == '/' ]] ; then
  P_LOGFILE=${LOGDIR}/$P_FILENAME
else
  P_LOGFILE=${P_DATA}/${LOGDIR}/$P_FILENAME
fi

P_OFFSET=$(stat -c%s $P_LOGFILE)
if [[ $P_LOGFILE = $P_O_LOGFILE ]]; then
  TO_READ=$(( P_OFFSET - P_O_OFFSET ))
else
  for i in ${!P_LEVELS[@]}
  do
    echo ${P_LEVELS[$i]} ${P_COUNTS[$i]}
    P_COUNTS[$i]=$(tail -c +${P_O_OFFSET} ${P_O_LOGFILE} |grep "${P_LEVELS[$i]}" | wc -l)
  done
  TO_READ=$P_OFFSET
  P_O_OFFSET=0
fi

for i in ${!P_LEVELS[@]}
do
  NCOUNT=$(tail -c +${P_O_OFFSET} ${P_LOGFILE} | head -c ${TO_READ} |grep "${P_LEVELS[$i]}" | wc -l)
  OCOUNT=P_COUNTS[$i]
  COUNT=$(( NCOUNT + OCOUNT ))
  echo "ccp_log_event_count{event_type=\"${LEVEL}\"} ${COUNT}" >>${P_DIR}/${P_TMP}
done

cat >${P_FILE_TC} <<P_EOF
LAST_LOGFILE=${P_LOGFILE}
LAST_OFFSET=${P_OFFSET}
P_EOF

}

isSettings() {
  checksum=$(psql -d postgres -Atc 'SELECT name, setting FROM pg_settings ORDER BY name' | sha1sum | awk '{print $1}')
  echo "ccp_config_checksum ${checksum}" >>${P_DIR}/${P_TMP}
}

#################################
if [ ! -d ${P_DIR} ]; then
  mkdir ${P_DIR}
fi
rm -f ${P_DIR}/${P_TMP}
#################################

isReady()
isEvent()
isSettings()

#################################
mv ${P_DIR}/${P_TMP} ${P_DIR}/${P_FILE}
#################################

