#!/usr/bin/env bash
###
#
# Copyright © 2017-2023 Crunchy Data Solutions, Inc. All Rights Reserved.
#
###

if [ "$1" == "" ]; then
  echo "Usage: $(basename $0) <PostgreSQL system identifier>"
  exit 1
fi

SYSTEM_ID=$1

[ -f /etc/pgmonitor.conf ] && . /etc/pgmonitor.conf

if [ ${BACKREST_AUTOCONFIG_STANZAS:-0} -gt 0 ]; then
  BACKREST_STANZAS=$(grep '^\[' /etc/pgbackrest.conf /etc/pgbackrest/  -srh |sort -u |grep -v ':\|global' |sed 's/\[\|\]//g' | tr '\n' ' ' )
  BACKREST_CONFIGS=""
fi

conf="default"

if [ -z "$BACKREST_CONFIGS" ] && [ -z "$BACKREST_STANZAS" ]; then
    echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --log-level-console=warn --output=json info | tr -d '\n')
elif [ ! -z "$BACKREST_CONFIGS" ] && [ -z "$BACKREST_STANZAS" ]; then
    read -r -a config_array <<< "$BACKREST_CONFIGS"
    for conf in "${config_array[@]}"
    do
      echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --log-level-console=warn --config=$conf --output=json info | tr -d '\n') | grep $SYSTEM_ID
      if [ $? == 0 ]; then
        break
      fi
    done
elif [ -z "$BACKREST_CONFIGS" ] && [ ! -z "$BACKREST_STANZAS" ]; then
    read -r -a stanza_array <<< "$BACKREST_STANZAS"
    for stanza in "${stanza_array[@]}"
    do
      export PGBACKREST_STANZA=$stanza
      echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --log-level-console=warn --output=json info | tr -d '\n') | grep $SYSTEM_ID
      if [ $? == 0 ]; then
        break
      fi
    done
fi

