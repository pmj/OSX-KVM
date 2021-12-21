#!/bin/bash

echo "Creating root disk image for VM with 128GB capacity."
echo qemu-img create -f qcow2 mac_hdd_ng.img 128G
if ! ( qemu-img create -f qcow2 mac_hdd_ng.img 128G ) ; then
	echo "Something went wrong, exiting"
	exit 1
fi

echo "Now run ./OpenCore-Boot.sh and select the installer/base system in the boot menu."
