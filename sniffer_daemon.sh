#!/bin/bash

WORK_DIR=/srv

trap 'kill $(jobs -p)' EXIT

countdown() {
  secs=$(($1))
  message=$2
  while [ $secs -gt 0 ]; do
    echo -ne "$message $secs\033[0K\r"
    sleep 1
    : $((secs--))
  done
}

echo "=================================================================="
echo "[START] ${0#*/} (PID: $$)"

countdown 30 "Start packet capture. Please wait..."
sudo ${WORK_DIR}/capture.sh -s=256 &

countdown 60 "Start send rssi from packet capture. Please wait..."
sudo ${WORK_DIR}/post_data.sh &

echo "[FINISH] ${0#*/} (PID: $$)"

wait
