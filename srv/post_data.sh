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

# Read files
# E.g.
#   /var/log/capture/packet_00001_20170427122557.pcap
#   /var/log/capture/packet_00002_20170427124633.pcap
#   ...
while :
do
  file_count=`\find ${OUTLOG} -name 'packet*.pcap' -type f -print0 | xargs -0 --no-run-if-empty ls | wc -w`
  if [ ${file_count} -lt 2 ]; then
    continue
  fi
  for file in `\find ${OUTLOG} -name 'packet*.pcap' -type f -print0 | xargs -0 --no-run-if-empty ls -1t`; do
    csv_file=${file}.csv
    sudo tshark -r ${file} -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal > ${csv_file}
    if [ ! -e "${csv_file}" ] || [ ! -s "${csv_file}" ] ; then
      # Remove temporary file
      sudo rm -f "${csv_file}"
      echo "    [ERROR] Failed convert packet capture file using 'tshark'."
      continue
    fi
    # Post to Iot Borad
    sudo python ${WORK_DIR}/post_data.py ${csv_file} ${WLAN_MAC_ADDR} ${CONFIG_PATH}
    if [ "$?" -eq 0 ] ; then
      # Remove pcap file
      sudo rm -f ${file}
      echo "    [SUCCESS] ${file}"
    fi
    # Remove temporary file
    sudo rm -f ${csv_file}
  done
done

echo "[INFO] Finish ${0#*/} (PID: $$)"
