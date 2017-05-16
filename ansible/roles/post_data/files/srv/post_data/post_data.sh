#!/bin/bash

POST_DATA_PY="${WORK_DIR}/post_data.py"
WLAN_MAC_ADDR=$(cat "${WLAN_ADDR_FILE}" 2> /dev/null)

if [ -z "${POST_DATA_PY}" ]; then
  echo "Not found ${POST_DATA_PY}"
  exit 1
fi

if [ ! -d "${OUTLOG}" ]; then
  echo "Not found ${OUTLOG}"
  exit 1
fi
	
if [ -z "${CONFIG_PATH}" ]; then
  echo "Not found ${CONFIG_PATH}"
  exit 1
fi

if [ -z "${WLAN_MAC_ADDR}" ] ; then
  echo "Not found ${WLAN_ADDR_FILE}"
  exit 1
fi

python "${POST_DATA_PY}" "${OUTLOG}" "${WLAN_MAC_ADDR}" "${CONFIG_PATH}"
