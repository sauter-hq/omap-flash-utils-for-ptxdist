#!/bin/bash

BASEDIR=$(dirname $0)
IMAGESDIR=${BASEDIR}/jffs2-repair-images

if [ -z $1 ] || [ -z $2 ]; then
        echo "Usage : "
        echo -e "\t repair-to-jffs2.sh <tty-path> <current-pc-ipaddr>"
				echo -e "\t \t tty-path \t \t path to a serial device, e.g. /dev/ttyUSB0"
				echo -e "\t \t current-pc-ipaddr \t \t ip address which is accessible by the device (used for tftp)"
        exit 1
fi

TTY_PATH=$1
CURRENT_IPADDR=$2

IMAGESDIR_ABS=$(dirname $(readlink -e ${IMAGESDIR}))/$(basename ${IMAGESDIR}) 
echo "Opening TFTP Server for access to : ${IMAGESDIR_ABS}"
in.tftpd -u root -4 -v --verbosity 8 -p -a 0.0.0.0:69 -l --foreground ${IMAGESDIR_ABS} &

helpers/flash-device.sh ${TTY_PATH} ${IMAGESDIR_ABS} ${CURRENT_IPADDR} ${IMAGESDIR_ABS} 
