#!/bin/bash

WORK_DIR=/srv

sudo apt-get update -y
sudo apt-get install tshark -y
sudo apt-get install python-pip -y

cd ${WORK_DIR}
sudo pip install -r requirements.txt
