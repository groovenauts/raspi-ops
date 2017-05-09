#!/bin/bash

INTERFACE=mon0
OUTDIR=/var/log
OUTFILE_PREFIX=packet
OUTFILE_EXT=pcap
OUTFILE=${OUTDIR}/${OUTFILE_PREFIX}.${OUTFILE_EXT}

# Parameter
filesize=256000 # =>256MB
files=100 # => 256MB * 100 = 2.56GB

# Usage
usage() {
  echo "Usage: ${0#*/} [-s=--log-size] [-n=--log-num]"
  echo "      -s: Default value is ${filesize}."
  echo "      -n: Default value is ${files}."
  echo "      The output file is '${OUTDIR}/${OUTFILE_PREFIX}_{number}_{yyyymmddhhmmss}.${OUTFILE_EXT}'"
}

# Parse parameter
for ARG in $*; do
  case $ARG in
    -s=*|--log-size=*)
      filesize=(${ARG#*=})
      ;;
    -n=*|--log-num=*)
      files=(${ARG#*=})
      ;;
    -h|--help)
      usage
      exit 1
  esac
done

echo "[START] ${0#*/} (PID: $$)"

sudo tshark -i ${INTERFACE} -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal -b filesize:${filesize} -b files:${files} -w ${OUTFILE} 1>/dev/null
# => /var/log/packet_00001_20170508120443.pcap
#    /var/log/packet_00002_20170508120629.pcap
#    ...

echo "[FINISH] ${0#*/} (PID: $$)"
