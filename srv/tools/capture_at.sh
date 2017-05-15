#!/bin/bash

INTERFACE=mon0
WLAN_ADDR_FILE=/sys/class/net/wlan1/address
WLAN_MAC_ADDR=`cat ${WLAN_ADDR_FILE} 2> /dev/null`
OUTDIR=./
CSV_FILE_PREFIX=capture
CSV_FILE=${OUTDIR}/${CSV_FILE_PREFIX}_${WLAN_MAC_ADDR}_`date +%Y%m%d%H%M%S`.csv

# Parameter
duration=60 # seconds
clean=0

# Usage
usage() {
  echo "Usage: ${0#*/} [-d=--duration] [-c=--clean]"
  echo "      -d: Default value is ${duration}."
  echo "      -c: Default value is ${clean}."
}

# Parse parameter
for ARG in $*; do
  case $ARG in
    -d=*|--duration=*)
      duration=(${ARG#*=})
      ;;
    -c|--clean)
      clean=1
      ;;
    -h|--help)
      usage
      exit 1
  esac
done

if [ ${clean} = 1 ]; then
  find ${OUTDIR} | grep -E ${CSV_FILE_PREFIX} | xargs rm -f
fi

sudo tshark -i ${INTERFACE} -Y "wlan.fc.type==0 and wlan.fc.subtype==4" -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal -a duration:${duration} > ${CSV_FILE}
