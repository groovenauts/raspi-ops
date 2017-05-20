#!/bin/bash

tshark -i "${INTERFACE}" -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal -b filesize:"${FILE_SIZE_KB}" -b files:"${FILES}" -w "${OUTFILE} -g" 1>/dev/null
