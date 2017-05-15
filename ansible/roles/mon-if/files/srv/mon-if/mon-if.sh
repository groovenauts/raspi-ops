#!/bin/bash

MON_IF=mon0
PHY0_MONITOR_MODE=$(/sbin/iw phy phy0 info | grep -c monitor)
PHY1_MONITOR_MODE=$(/sbin/iw phy phy1 info | grep -c monitor)
PHY2_MONITOR_MODE=$(/sbin/iw phy phy2 info | grep -c monitor)
PHY3_MONITOR_MODE=$(/sbin/iw phy phy3 info | grep -c monitor)
PHY4_MONITOR_MODE=$(/sbin/iw phy phy4 info | grep -c monitor)

MON_IF_COUNT=$(/sbin/ifconfig | grep -c ${MON_IF})
if [ "${MON_IF_COUNT}" -eq 0 ]
then
	# check phy monitor mode and add mon_if.
	if [ "${PHY0_MONITOR_MODE}" -gt 0 ]
	then
		/sbin/iw phy phy0 interface add ${MON_IF} type monitor
		/sbin/ifconfig ${MON_IF} up
	elif [ "${PHY1_MONITOR_MODE}" -gt 0 ]
	then
		/sbin/iw phy phy1 interface add ${MON_IF} type monitor
		/sbin/ifconfig ${MON_IF} up
	elif [ "${PHY2_MONITOR_MODE}" -gt 0 ]
	then
		/sbin/iw phy phy2 interface add ${MON_IF} type monitor
		/sbin/ifconfig ${MON_IF} up
	elif [ "${PHY3_MONITOR_MODE}" -gt 0 ]
	then
		/sbin/iw phy phy3 interface add ${MON_IF} type monitor
		/sbin/ifconfig ${MON_IF} up
	elif [ "${PHY4_MONITOR_MODE}" -gt 0 ]
	then
		/sbin/iw phy phy4 interface add ${MON_IF} type monitor
		/sbin/ifconfig ${MON_IF} up
	fi
fi
