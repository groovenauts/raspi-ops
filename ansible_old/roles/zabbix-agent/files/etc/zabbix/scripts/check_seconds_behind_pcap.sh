#!/bin/bash

PCAP_DIR="/var/log/capture"

fnc_get_file_date () {
	# /var/log/capture/packet_01802_20170526135516.pcap
	file_name_full_path=$1	
	if [ "${file_name_full_path}" != "" ]
	then
		# /var/log/capture/packet_01802_20170526135516.pcap -> packet_01802_20170526135516.pcap
		file_name=${file_name_full_path##*/}
		# packet_01802_20170526135516.pcap -> packet_01802_20170526135516
		file_name_without_extention=${file_name%.*}
		# packet_01802_20170526135516 -> 20170526135516
		file_name_pick_date=$(echo "${file_name_without_extention}" | awk -F"_" '{print $3}')
		# 20170526135516 -> 2017/05/26 13:35:16
		file_date="${file_name_pick_date:0:4}/${file_name_pick_date:4:2}/${file_name_pick_date:6:2} ${file_name_pick_date:8:2}:${file_name_pick_date:10:2}:${file_name_pick_date:12:2}"
	else
		return 1
	fi
	echo "${file_date}"
	return 0
}

PCAP_OLDEST_FILE_NAME=$(find ${PCAP_DIR} -name "*pcap" | sort | head -1) || exit 1
if [ "${PCAP_OLDEST_FILE_NAME}" != "" ]
then
	PCAP_OLDEST_FILE_DATE=$(fnc_get_file_date "${PCAP_OLDEST_FILE_NAME}") || exit 1
	SECONDS_BEHIND_PCAP=$(( $(date +%s) - $(date --date="${PCAP_OLDEST_FILE_DATE}" +%s) )) || exit 1
	echo "${SECONDS_BEHIND_PCAP}"
else
	echo "0"
fi
exit 0
