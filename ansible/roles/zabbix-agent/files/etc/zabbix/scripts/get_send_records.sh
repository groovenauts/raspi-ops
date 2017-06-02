#!/bin/bash

RESULTS_FILE=/var/log/syslog
TARGET_DATE=$(date -d '1 minute ago' "+ %-d %H:%M:")

send_records=$(grep "${TARGET_DATE}" "${RESULTS_FILE}" | grep "SUCCESS" | awk '{sum+=$9}END{print sum}') || exit 1
if [ -z "${send_records}" ]
then
	send_records=0
fi

echo "${send_records}"

exit 0
