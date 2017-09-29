#!/usr/bin/env bash

set -e
IODIR=/var/lib/ccp_monitoring
IOTMP=io_queue.tmp
IOFILE=io_queue.prom
DISK=vda
if [ ! -d ${IODIR} ]; then
  mkdir ${IODIR}
fi
rm -f ${IODIR}/${IOTMP}
echo "node_disk_queue_max{device=\"${DISK}\"} $(cat /sys/block/${DISK}/queue/nr_requests)" >>${IODIR}/${IOTMP}
echo "node_disk_queue_cur{device=\"${DISK}\"} $(iostat -xmt -d 1 1 ${DISK} | grep ^${DISK} | awk '{print $9}')" >>${IODIR}/${IOTMP}
mv ${IODIR}/${IOTMP} ${IODIR}/${IOFILE}
