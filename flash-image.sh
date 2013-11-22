#!/bin/bash

BASEDIR=$(dirname $0)

if [ -z $1 ] || [ -z $2 ]; then
        echo "Usage : "
        echo -e "\t flash-image.sh <tty-path> <current-pc-ipaddr> <images-path>"
				echo -e "\t \t tty-path \t \t path to a serial device, e.g. /dev/ttyUSB0"
				echo -e "\t \t current-pc-ipaddr \t \t ip address which is accessible by the device (used for tftp)"
				echo -e "\t \t images-path \t \t Path where the images to flash are provided."
        exit 1
fi


TTY_PATH=$1
CURRENT_IPADDR=$2
IMAGESDIR=$3

IMAGESDIR_ABS=$(dirname $(readlink -e ${IMAGESDIR}))/$(basename ${IMAGESDIR}) 
echo "Opening TFTP Server for access to : ${IMAGESDIR_ABS}"
in.tftpd -u root -4 -v --verbosity 8 -p -a 0.0.0.0:69 -l --foreground --secure ${IMAGESDIR_ABS} &
TFTPD_PID=$! 
trap "kill -TERM ${TFTPD_PID}" 0

helpers/flash-device.sh ${TTY_PATH} ${IMAGESDIR_ABS} ${CURRENT_IPADDR}
