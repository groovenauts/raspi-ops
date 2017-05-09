#!/bin/bash

INTERFACE=mon0

sudo tshark -i ${INTERFACE} -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal
