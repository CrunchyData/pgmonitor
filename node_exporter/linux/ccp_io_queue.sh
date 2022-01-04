#!/usr/bin/env bash
###
#
# Copyright © 2017-2022 Crunchy Data Solutions, Inc. All Rights Reserved.
#
###

# Additional metric option to monitor disk queue depth with node_exporter. Set the DISK variable to the disk system that is to be monitored

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
