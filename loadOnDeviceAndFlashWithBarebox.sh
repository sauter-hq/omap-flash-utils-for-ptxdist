#!/bin/bash
#
# 	Usage :
# 		loadOnDeviceAndFlashWithBarebox.sh /dev/someTty /path/to/platform-phyCARD-L/images path/to/images/on/tftpserv 192.168.10.50 
#
# 		
#
#
#
BASEDIR=$(dirname $0)

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
	echo "Usage : "
	echo "\t loadOnDeviceAndFlashWithBarebox.sh serial-device ptxdist-images-folder tftpserver-ipadress  tftpserver-prefix-to-images-folder"
	echo "\t \t serial-device - path to tty (e.g. /dev/ttyS0)"
	echo "\t \t ptxdist-images-folder - path to ptxdist generated images folder (e.g. workspace/ptxdistConfig/platform-phyCARD-L/images)"
	echo "\t \t tftpserver-ipadress - ip of the tftp server"
	echo "\t \t tftpserver-prefix-to-images-folder - path from tftp server to access the images folder provided as ptxdist-images-folder (i.e. usually the tftp server has a symlink to this images folder"
	exit 1
fi

SERIAL_PORT=$1
PTXDIST_IMAGES_DIR=$2
TFTP_SERVER_IP=$3

#
# \brief logs a message to the user in a colour which tells him neutrality
# \param $1 message
#
logMessage () {
	echo -en "\e[01;36m"
	echo "INFO: $1"
	echo -en "\e[00m" 

}

#
# \brief logs an error message to the user in a colour which tells him neutrality
# 	Note that the error messages are sent to the stderr
# \param $1 message
#
logError() {
	echo -en "\e[01;31m" 1>&2 
	echo "ERROR: $1" 1>&2 
	echo -en "\e[00m" 1>&2 
}

#
# \brief This function  doesn't accept any params and sends simply keystrokes over
# serial line. Useful to avoid autoboot.
#
sendKeystrokesToUBoot () {
	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "pleaseDontAutoBoot" -e "PCA-102 #>" 
	RETVAL=$?

	if [ $RETVAL -ne 0 ]; then
		logError "sending keystrokes failed"
	fi
}

#
# \brief This function  doesn't accept any params and sends simply keystrokes over
# serial line. Useful to avoid autoboot.
#
sendKeystrokesToBarebox() {
	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "pleaseDontAutoBoot" -e "barebox@" 
	RETVAL=$?

	if [ $RETVAL -ne 0 ]; then
		logError "sending keystrokes failed"
	fi
}

logMessage "Bringing x-loader with ukermit support on serial line"
$BASEDIR/pserial -p ${SERIAL_PORT} -f $BASEDIR/x-load-withukermitsupport.bin -v

logMessage "Bringing u-boot over serial line"
$BASEDIR/ukermit -p ${SERIAL_PORT} -f ${PTXDIST_IMAGES_DIR}/u-boot.bin

logMessage " u-boot starting, sending keystrokes to avoid autoboot... "
sendKeystrokesToUBoot

$BASEDIR/ucmd -p ${SERIAL_PORT} -c "loadb" -e "## Ready for binary (kermit) download to 0x82000000" 
RETVAL=$?

if [ $RETVAL -eq 0 ]; then
	$BASEDIR/ukermit -p ${SERIAL_PORT} -f ${PTXDIST_IMAGES_DIR}/barebox-image 

	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "go 0x82000000" -e "## Starting application at 0x82000000" 
	RETVAL=$?

	if [ $RETVAL -eq 0 ]; then
		logMessage "Barebox starting, sending keystrokes to avoid autoboot ... "
		sendKeystrokesToBarebox 

		# Print version
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "version" -e "barebox@" 

		logMessage "Load default environment and reinit" #Because barebox automatically takes what is stored on nand
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "loadenv /dev/defaultenv" -e "loading environment from /dev/defaultenv"
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "saveenv" -e "saving environment"
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "go 0x82000000" -e "## Starting application at 0x82000000" 
		RETVAL=$?

		if [ $RETVAL -eq 0 ]; then
			logMessage "Barebox reinitialization, sending keystrokes to avoid autoboot.."
			sendKeystrokesToBarebox 
		else
			logError "barebox didn't reinit."
			exit 1
		fi

	 	logMessage "Configure barebox to access current tftp"
		sed "s/eth0\.serverip=[0-9\.]\+/eth0.serverip=${TFTP_SERVER_IP}/g" barebox-envconfig > /tmp/barebox-envconfig-adapted

		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "loadb -f env/config -c" -e "## Ready for binary (kermit) download"
		$BASEDIR/ukermit -p ${SERIAL_PORT} -f /tmp/barebox-envconfig-adapted
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "saveenv" -e "saving environment"

		# Update partitions from configured tftp
		logMessage "Telling the device to update it's image through tftp."

		logMessage "Updating x-loader"
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "update -t x-loader -d nand -f imagesRecovery/x-load.bin.ift" -e "barebox@" 
		XLOADERFLASHED=$?

		if [ $XLOADERFLASHED -eq 0 ]; then
			logMessage "x-loader flashed successfully."
		else
			logError "Unable to flash x-loader."
			exit 1
		fi


		logMessage "Updating barebox"
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "update -t barebox -d nand -f imagesRecovery/barebox-image" -e "barebox@" 
		BAREBOXFLASHED=$?

		if [ $BAREBOXFLASHED -eq 0 ]; then
			logMessage "barebox flashed successfully."
		else
			exit 1
		fi

		
		logMessage "Updating kernel"
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "update -t kernel -d nand -f imagesRecovery/linuximage" -e "barebox@" 
		KERNELFLASHED=$?

		if [ $KERNELFLASHED -eq 0 ]; then
			logMessage "kernel flashed successfully."
		else
			exit 1
		fi


		logMessage "Updating rootfs"
		$BASEDIR/ucmd -p ${SERIAL_PORT} -c "update -t rootfs -d nand -f imagesRecovery/root.ubi" -e "barebox@" 
		ROOTFSFLASHED=$?

		if [ $ROOTFSFLASHED -eq 0 ]; then
			logMessage "rootfs flashed successfully."
		else
			exit 1
		fi

	fi
fi
