#!/bin/sh
#
# 	Usage :
# 		load-on-device.sh /dev/ttyUSB0 u-boot.bin
#
BASEDIR=$(dirname $0)
BUILDDIR=${BASEDIR}/../build

export PATH=$BUILDDIR:$PATH

if [ -z $1 ] || [ -z $2 ]; then
	echo "Usage : "
	echo "\t load-on-device.sh /dev/ttyUSB0 u-boot.bin"
	exit 1
fi

pserial -p $1 -f $BASEDIR/x-load-withukermitsupport.bin -v
ukermit -p $1 -f $2

echo "U-Boot starting, waiting for prompt, and sending command to avoid autoboot... "
ucmd -p $1 -c "pleaseDontAutoBoot" -e "PCA-102 #>" 
