#!/bin/bash

WORK_DIR=/srv/setup

sudo apt-get update -y
sudo apt-get install tshark -y
sudo apt-get install python-pip -y

cd ${WORK_DIR} || exit 1
sudo pip install -r requirements.txt
