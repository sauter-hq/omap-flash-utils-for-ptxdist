## Omap flashing utilities for ptxdist

[PTXdist](http://www.pengutronix.com/software/ptxdist/index_en.html) is a tool for Reproducible Embedded Linux Systems which generates complete linux systems from sources of different packages. The problem once this is all built is always getting the bootloaders, kernel images and root filesystem images on the target system.

This project provides utilities to flash all PTXdist generated images automatically on target boards thanks to the serial interface. It bases itself on the [omap-u-boot-utils](https://github.com/nmenon/omap-u-boot-utils) project from Nishanth Menon.

### How to use it ?
#### Flashing linux system on device

Simply build your linux system :
* `cd workspace/ptxdistConfig/`
* `ptxdist go && ptxdist images`

Plug your omap board with any serial interface and run :
* `loadOnDeviceAndFlashWithBarebox.sh /dev/someTty workspace/ptxdistConfig/platform-build/images/ yourIpAddress tftpPrefixPathToImages`

#### Booting over serial line
Please take a look at ``loadOnDevice.sh`` to know hot to load a second stage bootloader (i.e. third file) over serial line with the pserial and ukermit tools.

Additionally a documentation is available for these tools under docs/, you can also take a look to the originating project from which this fork comes, it provides more details in it's README about how to use the different pserial, ukermit... components.

### Credits
Thanks to Nishanth Menon for maintaining the [omap-u-boot-utils](https://github.com/nmenon/omap-u-boot-utils). 

At the start of writing this code, there was no git, no svn, just zip files,
so a couple of honorable mentions at this time:
Dirk Behme - general directions and initial usb discussion as here:
http://groups.google.com/group/beagleboard/browse_thread/thread/ae2c601ebe104a4
pusb is a scratch write but in general uses the same concepts

Rob Clark - Mac OS support, tons of cleanups in serial code, and in general a
willing experimenter with new ideas :)

Paul Baecher for writing liblcfg: http://liblcfg.carnivore.it/ - I recommend it
to anyone looking for a quiet simple config file handling parser
