#!/bin/sh
#
# 	Usage :
# 		loadOnDevice.sh /dev/ttyUSB0 u-boot.bin
#
BASEDIR=$(dirname $0)

if [ -z $1 ] || [ -z $2 ]; then
	echo "Usage : "
	echo "\t loadOnDevice.sh /dev/ttyUSB0 u-boot.bin"
	exit 1
fi

$BASEDIR/pserial -p $1 -f $BASEDIR/x-load-withukermitsupport.bin -v
$BASEDIR/ukermit -p $1 -f $2
