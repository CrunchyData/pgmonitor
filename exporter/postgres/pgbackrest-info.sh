#!/usr/bin/env bash

[ -f /etc/pgmonitor.conf ] && . /etc/pgmonitor.conf

conf="default"
if [ -z "$BACKREST_CONFIGS" ] && [ -z "$BACKREST_STANZAS" ]; then
    echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --output=json info | tr -d '\n')
elif [ ! -z "$BACKREST_CONFIGS" ] && [ -z "$BACKREST_STANZAS" ]; then
    IFS=':' read -r -a config_array <<< "$BACKREST_CONFIGS"
    for conf in "${config_array[@]}"
    do
      echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --config=$conf --output=json info | tr -d '\n')
    done
elif [ -z "$BACKREST_CONFIGS" ] && [ ! -z "$BACKREST_STANZAS" ]; then
    IFS=':' read -r -a stanza_array <<< "$BACKREST_STANZAS"
    for stanza in "${stanza_array[@]}"
    do
      export PGBACKREST_STANZA=$stanza
      echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --output=json info | tr -d '\n')
    done
else
    IFS=':' read -r -a config_array <<< "$BACKREST_CONFIGS"
    IFS=':' read -r -a stanza_array <<< "$BACKREST_STANZAS"
    if [ ${#config_array[@]} -ne ${#stanza_array[@]} ]; then
      echo "Configuration error, BACKREST_CONFIGS and BACKREST_STANZAS must have same number of elements"
      exit 1
    fi
    ary_len=${#config_array[@]}
    for (( i=0; i<$ary_len; i++ ))
    do
      conf=${config_array[$i]}
      stanza=${stanza_array[$i]}
      export PGBACKREST_STANZA=$stanza
      echo $(echo -n "$conf|" | tr '/' '_'; pgbackrest --config=$conf --output=json info | tr -d '\n')
    done
fi

