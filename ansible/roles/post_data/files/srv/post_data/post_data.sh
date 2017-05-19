#!/bin/bash

POST_DATA_PY="${WORK_DIR}/post_data.py"
HOST_NAME=$(hostname)

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

if [ -z "${HOST_NAME}" ] ; then
  echo "Not found ${HOST_NAME}"
  exit 1
fi

python "${POST_DATA_PY}" "${OUTLOG}" "${HOST_NAME}" "${CONFIG_PATH}"
