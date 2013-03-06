#!/bin/bash
#
# 	Usage :
# 		loadOnDeviceAndFlashWithBarebox.sh /dev/someTty /path/to/platform-phyCARD-L/images path/to/images/on/tftpserv 192.168.10.50 
# 		loadOnDeviceAndFlashWithBarebox.sh /dev/ttyUSB0 ~/workspace/recoverySystem/platform-phyCARD-L/images/ 192.168.10.50 imagesRecovery
#
BASEDIR=$(dirname $0)

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ] ; then
	echo "Usage : "
	echo -e "\t loadOnDeviceAndFlashWithBarebox.sh serial-device ptxdist-images-folder tftpserver-ipadress  tftpserver-prefix-to-images-folder"
	echo ""
	echo -e "\t \t serial-device - path to tty (e.g. /dev/ttyS0)"
	echo -e "\t \t ptxdist-images-folder - path to ptxdist generated images folder (e.g. workspace/ptxdistConfig/platform-phyCARD-L/images)"
	echo -e "\t \t tftpserver-ipadress - ip of the tftp server"
	echo -e "\t \t tftpserver-prefix-to-images-folder - path from tftp server to access the images folder provided as ptxdist-images-folder (i.e. usually the tftp server has a symlink to this images folder"
	exit 1
fi

SERIAL_PORT=$1
PTXDIST_IMAGES_DIR=$2
TFTP_SERVER_IP=$3
TFTP_SERVER_PTXDIST_IMAGES_DIR=$4

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

#
# \brief Configure barebox for flashing the NAND, resetting it's default environment 
# and reinitializing itself in case the NAND was containing a barebox environment which
# was wrongly modified.
# 
configureBareboxForFlashingNand() {

	logMessage "Load default environment and reinit" #Because barebox automatically takes what is stored on nand

	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "loadenv /dev/defaultenv" -e "loading environment from /dev/defaultenv"
	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "saveenv" -e "saving environment"
	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "go 0x82000000" -e "## Starting application at 0x82000000" 

	logMessage "Barebox reinitialization, sending keystrokes to avoid autoboot.."
	sendKeystrokesToBarebox 

	logMessage "Configure barebox to access current tftp"
	sed "s/eth0\.serverip=[0-9\.]\+/eth0.serverip=${TFTP_SERVER_IP}/g" barebox-envconfig > /tmp/barebox-envconfig-adapted

	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "loadb -f env/config -c" -e "## Ready for binary (kermit) download"
	$BASEDIR/ukermit -p ${SERIAL_PORT} -f /tmp/barebox-envconfig-adapted
	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "saveenv" -e "saving environment"

	logMessage "Barebox ready for flashing over TFTP"
}

#
# \brief Flashes the given nand device, with the given image from the ptxdist image
# folder found (i.e. TFTP_SERVER_PTXDIST_IMAGES_DIR).
# 
# \param $1 The nand part, that is to say the name of the nand device in barebox (e.g. x-loader, barebox, kernel, rootfs)
# \param $2 Path of image to download on tftp server
#
flashNandPartThroughTftp() {
	
	NANDPART=$1
	IMAGETOWRITE=$2

	logMessage "Download'n flashing ${NANDPART} with tfp file : ${IMAGETOWRITE}"

	$BASEDIR/ucmd -p ${SERIAL_PORT} -c "update -t ${NANDPART} -d nand -f ${IMAGETOWRITE}" -e "barebox@" 

	logMessage "${NANDPART} flashed the image ${IMAGETOWRITE}"
}

# Bringing xloader in response to asic
logMessage "Bringing x-loader with ukermit support on serial line"
$BASEDIR/pserial -p ${SERIAL_PORT} -f $BASEDIR/x-load-withukermitsupport.bin -v

# Bringing u-boot to xloader over serial line
logMessage "Bringing u-boot over serial line"
$BASEDIR/ukermit -p ${SERIAL_PORT} -f ${PTXDIST_IMAGES_DIR}/u-boot.bin
logMessage " u-boot starting, sending keystrokes to avoid autoboot... "
sendKeystrokesToUBoot

# Bringing barebox on memory with kermit
logMessage "Bringing barebox over serial line"
$BASEDIR/ucmd -p ${SERIAL_PORT} -c "loadb" -e "## Ready for binary (kermit) download to 0x82000000" 
$BASEDIR/ukermit -p ${SERIAL_PORT} -f ${PTXDIST_IMAGES_DIR}/barebox-image 

# Launching barebox 
$BASEDIR/ucmd -p ${SERIAL_PORT} -c "go 0x82000000" -e "## Starting application at 0x82000000" 

logMessage "Barebox starting, sending keystrokes to avoid autoboot ... "
sendKeystrokesToBarebox 

# Print version
$BASEDIR/ucmd -p ${SERIAL_PORT} -c "version" -e "barebox@" 

configureBareboxForFlashingNand	

# Flash nand partitions from configured tftp
logMessage "Flashing NAND from TFTP."
flashNandPartThroughTftp x-loader ${TFTP_SERVER_PTXDIST_IMAGES_DIR}/x-load.bin.ift
flashNandPartThroughTftp barebox-image ${TFTP_SERVER_PTXDIST_IMAGES_DIR}/barebox-image
flashNandPartThroughTftp kernel ${TFTP_SERVER_PTXDIST_IMAGES_DIR}/linuximage
flashNandPartThroughTftp rootfs ${TFTP_SERVER_PTXDIST_IMAGES_DIR}/root.ubi
