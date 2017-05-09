#!/bin/bash
#
# Usage: image_flash.sh 2017-04-10-raspbian-jessie-lite.img disk3
#
image=$1
disk=$2

diskutil list

diskutil eraseDisk FAT32 RPI /dev/$disk

diskutil unmountDisk /dev/$disk

diskutil list

echo "write image"
sudo dd bs=1m if=$image of=/dev/r$disk
echo $?
