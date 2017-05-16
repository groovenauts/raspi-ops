#!/bin/bash

WORK_DIR=/srv
OUTLOG=/var/log/capture
OUTFILE_PREFIX=packet
OUTFILE_EXT=pcap
WLAN_ADDR_FILE=/sys/class/net/wlan1/address
WLAN_MAC_ADDR=`cat ${WLAN_ADDR_FILE} 2> /dev/null`
CONFIG_PATH=/srv/config.yaml

echo "[INFO] Start ${0#*/} (PID: $$)"

if [ -z "${WLAN_MAC_ADDR}" ] ; then
  echo "Not found ${WLAN_ADDR_FILE}"
  exit 1
fi

sudo python ${WORK_DIR}/post_data.py ${OUTLOG} ${WLAN_MAC_ADDR} ${CONFIG_PATH}

echo "[INFO] Finish ${0#*/} (PID: $$)"
