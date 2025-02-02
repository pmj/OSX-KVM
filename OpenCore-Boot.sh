#!/usr/bin/env bash

# Special thanks to:
# https://github.com/Leoyzen/KVM-Opencore
# https://github.com/thenickdude/KVM-Opencore/
# https://github.com/qemu/qemu/blob/master/docs/usb2.txt
#
# qemu-img create -f qcow2 mac_hdd_ng.img 128G
#
# echo 1 > /sys/module/kvm/parameters/ignore_msrs (this is required)

############################################################################
# NOTE: Tweak the "MY_OPTIONS" line in case you are having booting problems!
############################################################################

MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check"

# This script works for Big Sur, Catalina, Mojave, and High Sierra. Tested with
# macOS 10.15.6, macOS 10.14.6, and macOS 10.13.6

ALLOCATED_RAM="3072" # MiB
CPU_SOCKETS="1"
CPU_CORES="2"
CPU_THREADS="4"

REPO_PATH="."
OVMF_DIR="ovmf-2/"
QEMU_EXE="qemu-system-x86_64"
#QEMU_EXE=~/devel/qemu/build/x86_64-softmmu/qemu-system-x86_64

MAIN_DISK_IMAGE_PATH="$REPO_PATH/mac_hdd_ng.img"
#MAIN_DISK_IMAGE_PATH="/Volumes/devtools/virtual-machines/saucelabs/macos-bigsur-osx-kvm-mac-host-offline/mac_hdd_ng.img"

BASE_INSTALLER_IMAGE_PATH="$REPO_PATH/installer.qcow2"
#BASE_INSTALLER_IMAGE_PATH="/Volumes/devtools/macos-installers/11.6.1/macos-11.6.1-install-media.cdr"

# This causes high cpu usage on the *host* side
# qemu-system-x86_64 -enable-kvm -m 3072 -cpu Penryn,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,hypervisor=off,vmx=on,kvm=off,$MY_OPTIONS\

if [[ `uname` == "Darwin" ]]; then
	HYPERVISOR=hvf
else
	HYPERVISOR=kvm
fi

# shellcheck disable=SC2054
args=(
  -accel "$HYPERVISOR" -m "$ALLOCATED_RAM" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
  -machine q35
  -usb -device usb-kbd -device usb-tablet
  -smp "$CPU_THREADS",cores="$CPU_CORES",sockets="$CPU_SOCKETS"
  -device usb-ehci,id=ehci
  # -device usb-kbd,bus=ehci.0
  # -device usb-mouse,bus=ehci.0
  # -device nec-usb-xhci,id=xhci
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
  -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd"
  -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1024x768.fd"
  -smbios type=2
  -device ich9-intel-hda -device hda-duplex
  -device ich9-ahci,id=sata
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"
  -device ide-hd,bus=sata.2,drive=OpenCoreBoot
  -drive id=MacHDD,if=none,file="$MAIN_DISK_IMAGE_PATH",format=qcow2
  -device virtio-blk-pci,drive=MacHDD
  # -netdev tap,id=net0,ifname=tap0,script=no,downscript=no -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27
  -netdev user,id=net0 -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27
  -monitor stdio
  -device VGA,vgamem_mb=128
)

args+=( -drive id=InstallMedia,if=none,readonly=on,file="$BASE_INSTALLER_IMAGE_PATH",format=qcow2 )
args+=(  -device virtio-blk-pci,drive=InstallMedia )


echo Qemu command line:
echo "$QEMU_EXE" "${args[@]}"
"$QEMU_EXE" "${args[@]}"
