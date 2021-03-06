#!/bin/bash
#
# 	Usage :
# 		flash-device.sh /dev/someTty /path/to/platform-phyCARD-L/images path/to/images/on/tftpserv 192.168.10.50 
# 		flash-device.sh /dev/ttyUSB0 ~/workspace/recoverySystem/platform-phyCARD-L/images/ 192.168.10.50 imagesRecovery
#
BASEDIR=$(dirname $0)
BUILDDIR=${BASEDIR}/../build

export PATH=$BUILDDIR:$PATH

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] ; then
	echo "Usage : "
	echo -e "\t flash-device.sh serial-device ptxdist-images-folder tftpserver-ipadress  tftpserver-prefix-to-images-folder"
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
	ucmd -p ${SERIAL_PORT} -c "pleaseDontAutoBoot" -e "PCA-102 #>" 
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
	ucmd -p ${SERIAL_PORT} -c "pleaseDontAutoBoot" -e "barebox@" 
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

	logMessage "Load default environment" #Because barebox automatically takes what is stored on nand

	# On old system we have hamming for bootloader
	ucmd -p ${SERIAL_PORT} -c "loadenv /dev/defaultenv" -e "loading environment from /dev/defaultenv"

	logMessage "Configure barebox to access current tftp"

	cat > /tmp/barebox-envconfig-adapted << EOF
#!/bin/sh

machine=pcaal1
eccmode=software 
gpmc_nand0.eccmode=${eccmode}
eccmode=bch8_hw
#user=

# Enter MAC address here if not retrieved automatically
#eth0.ethaddr=de:ad:be:ef:00:00

# use 'dhcp' to do dhcp in barebox and in kernel
# use 'none' if you want to skip kernel ip autoconfiguration
#ip=dhcp

# or set your networking parameters here
eth0.ipaddr=192.168.10.64
eth0.netmask=255.255.255.0
eth0.serverip=${TFTP_SERVER_IP}
#eth0.gateway=a.b.c.d

# can be either 'tftp', 'nfs', 'nand' or 'disk'
kernel_loc=nand
# can be either 'net', 'nand', 'disk' or 'initrd'
rootfs_loc=nand

# for flash based rootfs: 'jffs2' or 'ubifs'
# in case of disk any regular filesystem like 'ext2', 'ext3', 'reiserfs'
rootfs_type=jffs2
rootfs_type=ubifs
# where is the rootfs in case of 'rootfs_loc=disk' (linux name)
rootfs_part_linux_dev=mmcblk0p4
rootfsimage=rootfs-\${machine}.\${rootfs_type}

# where is the kernel image in case of 'kernel_loc=disk'
kernel_part=disk0.2

# The image type of the kernel. Can be uimage, zimage, raw or raw_lzo
#kernelimage=zImage-\$machine
kernelimage=uImage-\$machine
#kernelimage=Image-\$machine
#kernelimage=Image-\$machine.lzo

bareboximage=barebox-\${machine}.bin
bareboxenvimage=barebox-\${machine}.bin

if [ -n \$user ]; then
	bareboximage="\$user"-"\$bareboximage"
	bareboxenvimage="\$user"-"\$bareboxenvimage"
	kernelimage="\$user"-"\$kernelimage"
	rootfsimage="\$user"-"\$rootfsimage"
	nfsroot="/home/\$user/nfsroot/\$machine"
elif [ -n "\$rootpath" ]; then
	nfsroot="\${eth0.serverip}:\${rootpath}"
else
	nfsroot="/path/to/nfs/root"
fi

autoboot_timeout=3

bootargs="console=ttyS0,115200"
bootargs="console=ttyO2,115200"

# the following displays are supported
# pd050vl1 (640 x 480)
# pd035vl1 (640 x 480)
# pd104slf (800 x 600)
# pm070wl4 (800 x 480)
#display="pd050vl1"
display="pd050vl1"

# omapfb.mode=<display>:<mode>,[,...]
# omapfb.debug=<y|n>
#        - Enable debug printing. You have to have OMAPFB debug support enabled
#          in kernel config.
#
bootargs="\$bootargs \${omap3_fb0.bootargs} omapdss.def_disp=\${display}"
#bootargs="\$bootargs omapdss.def_disp=pd035vl1"
#bootargs="\$bootargs omapdss.def_disp=pd104slf"
#bootargs="\$bootargs omapdss.def_disp=pm070wl4"

nand_parts="128k(x-loader)ro,128k(x-loader2)ro,128k(x-loader3)ro,128k(x-loader4)ro,1920k(barebox),128k(bareboxenv),4M(kernel),-(root)"
nand_device=omap2-nand
rootfs_mtdblock_nand=4

# set a fancy prompt (if support is compiled in)
PS1="\e[1;32mbarebox@\e[1;31m\h:\w\e[0m "

export display
EOF

	ucmd -p ${SERIAL_PORT} -c "loadb -f env/config -c" -e "## Ready for binary (kermit) download"
	ukermit -p ${SERIAL_PORT} -f /tmp/barebox-envconfig-adapted
	
	ucmd -p ${SERIAL_PORT} -c "source env/config" -e "barebox@"

	# Now sets up the devices we need
	ucmd -p ${SERIAL_PORT} -c "nand -d /dev/nand0.*.bb" -e "barebox@"
	ucmd -p ${SERIAL_PORT} -c "delpart /dev/nand0.*" -e "barebox@"
	ucmd -p ${SERIAL_PORT} -c "addpart /dev/nand0 \${nand_parts}" -e "barebox@"
	ucmd -p ${SERIAL_PORT} -c "nand -a /dev/nand0.*" -e "barebox@"

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
	
	ECCMODE=$1
	NANDPART=$2
	IMAGETOWRITE=$3


	logMessage "Setting ECC Mode"
	ucmd -p ${SERIAL_PORT} -c "gpmc_nand0.eccmode=${ECCMODE}" -e "barebox@"

	logMessage "Erasing device"
	ucmd -p ${SERIAL_PORT} -c "erase /dev/nand0.${NANDPART}.bb" -e "barebox@"

	logMessage "Download'n flashing ${NANDPART} with tfp file : ${IMAGETOWRITE}"
	ucmd -p ${SERIAL_PORT} -c "tftp ${IMAGETOWRITE} /dev/nand0.${NANDPART}.bb" -e "barebox@" 

	logMessage "${NANDPART} flashed the image ${IMAGETOWRITE}"
}

# Bringing xloader in response to asic
logMessage "Bringing x-loader with ukermit support on serial line"
pserial -p ${SERIAL_PORT} -f $BASEDIR/x-load-withukermitsupport.bin -v

# Bringing u-boot to xloader over serial line
logMessage "Bringing u-boot over serial line"
ukermit -p ${SERIAL_PORT} -f ${PTXDIST_IMAGES_DIR}/u-boot.bin
logMessage " u-boot starting, sending keystrokes to avoid autoboot... "
sendKeystrokesToUBoot

# Bringing barebox on memory with kermit
logMessage "Bringing barebox over serial line"
ucmd -p ${SERIAL_PORT} -c "loadb" -e "## Ready for binary (kermit) download to 0x82000000" 
ukermit -p ${SERIAL_PORT} -f $BASEDIR/barebox-flasher-image 

# Launching barebox 
ucmd -p ${SERIAL_PORT} -c "go 0x82000000" -e "## Starting application at 0x82000000" 

logMessage "Barebox starting, sending keystrokes to avoid autoboot ... "
sendKeystrokesToBarebox 

# Print version
ucmd -p ${SERIAL_PORT} -c "version" -e "barebox@" 

configureBareboxForFlashingNand	

# Flash nand partitions from configured tftp
logMessage "Flashing NAND from TFTP."
flashNandPartThroughTftp hamming_hw_romcode x-loader ${TFTP_SERVER_PTXDIST_IMAGES_DIR}MLO
flashNandPartThroughTftp hamming_hw_romcode x-loader2 ${TFTP_SERVER_PTXDIST_IMAGES_DIR}MLO
flashNandPartThroughTftp hamming_hw_romcode x-loader3 ${TFTP_SERVER_PTXDIST_IMAGES_DIR}MLO
flashNandPartThroughTftp hamming_hw_romcode x-loader4 ${TFTP_SERVER_PTXDIST_IMAGES_DIR}MLO
flashNandPartThroughTftp bch8_hw barebox ${TFTP_SERVER_PTXDIST_IMAGES_DIR}barebox-image
flashNandPartThroughTftp bch8_hw bareboxenv ${TFTP_SERVER_PTXDIST_IMAGES_DIR}barebox-default-environment 
flashNandPartThroughTftp bch8_hw kernel ${TFTP_SERVER_PTXDIST_IMAGES_DIR}linuximage
flashNandPartThroughTftp bch8_hw root ${TFTP_SERVER_PTXDIST_IMAGES_DIR}root.ubi
