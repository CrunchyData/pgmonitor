#!/usr/bin/env bash

set -e

IODIR=/var/lib/prometheus/iodata

IOTMP=io_queue.tmp

IOFILE=io_queue.prom

DISK=sda

rm -f ${IODIR}/${IOTMP}

echo "node_disk_queue_max $(cat /sys/block/${DISK}/queue/nr_requests)" >>${IODIR}/${IOTMP}

echo "node_disk_queue_cur $(iostat -xmt -d 1 1 ${DISK} | grep ^${DISK} | awk '{print $9}')" >>${IODIR}/${IOTMP}

mv ${IODIR}/${IOTMP} ${IODIR}/${IOFILE}

