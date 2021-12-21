#!/bin/bash

echo "Creating root disk image for VM with 128GB capacity."
echo qemu-img create -f qcow2 mac_hdd_ng.img 128G
qemu-img create -f qcow2 mac_hdd_ng.img 128G

echo "Now run ./OpenCore-Boot.sh and select the installer/base system in the boot menu."
