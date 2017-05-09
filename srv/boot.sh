#!/bin/bash

WLAN_IF=wlan1
PHY_IF=phy1
MON_IF=mon0

sudo ifconfig ${WLAN_IF} down
sudo iw phy ${PHY_IF} interface add ${MON_IF} type monitor
sudo ifconfig ${WLAN_IF} up
sudo ifconfig ${MON_IF} up
