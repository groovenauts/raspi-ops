#!/bin/bash

PCAP_DIR="/var/log/capture"

PCAP_FILE_COUNT=$(ls -1 ${PCAP_DIR}/*pcap | wc -l)
if [ "${PCAP_FILE_COUNT}" -gt 1 ]
then
	PCAP_OLDEST_FILE=$(ls -1tr ${PCAP_DIR}/*pcap | head -1)
fi
