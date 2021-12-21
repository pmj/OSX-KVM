#!/bin/bash

echo 'This script helps you obtain and prepare the files necessary for installing macOS inside a Qemu VM. There are 2 options:'
echo '1. Obtain a Base System image, and use the macOS recovery environment to download and install macOS.'
echo '2. Use a full macOS installer image. This minimises the download time during setup and also avoids redownloading if things go wrong or you set up more than 1 VM.'
echo ''
echo 'In either case, this script can help you download an image or use one you downloaded earlier.'
read -p 'Please press 1 or 2 to choose an option, or something else to exit: ' -n 1 -r
echo    # end line
if [[ ! $REPLY =~ ^[12]$ ]]
then
	echo 'Neither option 1 nor 2 was selected, cancelling and exiting.'
	exit 1
elif [[ $REPLY == '1' ]] ; then
	# Base System (recovery environment) chosen
	echo 'Using Base System image. Would you like to download the macOS Big Sur (11.x) base system, or provide a previously downloaded BaseSystem.dmg file?'
	echo '(D)ownload'
	echo '(U)se existing base image'
	echo 'In either case, make sure you have around 3GB free disk space available before continuing.'
	
	read -p 'Please press d or u, or something else to exit: ' -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[dDuU]$ ]] ; then
		echo 'Exiting'
		exit 1
	elif [[ $REPLY =~ ^[dD]$ ]] ; then
		echo Downloading Big Sur base system:
		echo $ ./fetch-macOS-v2.py --action download  -os default
		if ! ( ./fetch-macOS-v2.py --action download  -os default ) ; then
			echo Download failed
			exit 1
		fi
		BASE_SYSTEM_DMG_PATH=`pwd`/BaseSystem.dmg
	else
		read -p "Please enter the base system image's full path (file name typically BaseSystem.dmg) or drag & drop the image here. " BASE_SYSTEM_DMG_PATH
	fi
	
	if ! [ -f $BASE_SYSTEM_DMG_PATH ]; then
		echo "Error: Base system disk image not found at expected location '$BASE_SYSTEM_DMG_PATH'."
		exit 1
	fi
	
	echo "Converting Base System in dmg format to raw image…"
	BASE_SYSTEM_IMG_BASENAME=`basename "$BASE_SYSTEM_DMG_PATH"`
	BASE_SYSTEM_IMG_BASENAME="${BASE_SYSTEM_IMG_BASENAME%.*}"
	# note: hdiutil will create it with .cdr whether we like it or not
	BASE_SYSTEM_RAW_PATH=`pwd`/$BASE_SYSTEM_IMG_BASENAME.cdr
	echo "$BASE_SYSTEM_DMG_PATH -> $BASE_SYSTEM_RAW_PATH"
	if ! ( hdiutil convert "$BASE_SYSTEM_DMG_PATH" -format UDTO -o "$BASE_SYSTEM_RAW_PATH" ) ; then
		echo "Image conversion failed"
		exit 1
	fi
	if ! [ -f "$BASE_SYSTEM_RAW_PATH" ]; then
		echo "Error: Cannot find converted image at $BASE_SYSTEM_RAW_PATH"
		exit 1
	fi
	
	echo "Creating shallow qcow2 image for base system"
	echo rm -f installer.qcow2
	rm -f installer.qcow2
	echo qemu-img create -f qcow2 -b "$BASE_SYSTEM_RAW_PATH" -F raw installer.qcow2
	qemu-img create -f qcow2 -b "$BASE_SYSTEM_RAW_PATH" -F raw installer.qcow2
	
	echo "Base system raw image is at $BASE_SYSTEM_RAW_PATH, installer.qcow2 references it"

	echo "Obtaining and converting base image succeeded, now create a root image by running ./mac-host-3-prepare-root-image.sh"
else
	# Download of full offline installer selected
	echo 'Using Full Install System image. Would you like to download the macOS Big Sur (11.x) installer, or provide a previously downloaded Install macOS Big Sur.app?'
	echo '(D)ownload'
	echo '(U)se existing base image'
	echo 'In either case, make sure you have around 45GB free disk space available before continuing.'
	
	read -p 'Please press d or u, or something else to exit: ' -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[dDuU]$ ]] ; then
		echo 'Exiting'
		exit 1

	elif [[ $REPLY =~ ^[dD]$ ]] ; then
		echo Downloading macOS 11 installer
		if ! ( softwareupdate -d --fetch-full-installer --full-installer-version 11.6 ) ; then
			echo Error: Download failed
			exit 1
		fi
		MACOS_INSTALLER_APP_PATH=/Applications/Install macOS Big Sur.app
	else
		read -p "Please enter the macOS installer app's full path or drag & drop the installer here. " MACOS_INSTALLER_APP_PATH
	fi

	# The installer app bundle is step 1. We then need to:
	# - Create a disk image
	# - Attach & mount it
	# - Create "install media" in that disk image
	# - Convert the disk image into a raw ("CD/DVD master") image
	# - Clean up

	temp_dir=`mktemp -d -t macos-virt`
	installer_image_path="$temp_dir/install-macos.sparseimage"
	installer_raw_image_path=`pwd`/install-macos.cdr
	
	echo "Creating disk image for installer at $installer_image_path"
	echo hdiutil create -size 14G -fs hfs+ -volname 'Install macOS' -type SPARSE "$installer_image_path"
	if ! ( hdiutil create -size 14G -fs hfs+ -volname 'Install macOS' -type SPARSE "$installer_image_path" ) ; then
		echo Exiting due to error during image creation.
		exit 1
	fi
	
	installer_image_mount_path="$temp_dir/install-macos-mount"
	echo "Mounting newly created image at $installer_image_mount_path"
	echo mkdir -p "$installer_image_mount_path" && hdiutil attach "$installer_image_path" -mountpoint "$installer_image_mount_path" -nobrowse
	
	if ! ( mkdir -p "$installer_image_mount_path" && hdiutil attach "$installer_image_path" -mountpoint "$installer_image_mount_path" -nobrowse > "$temp_dir/hdiutil-attach-output.txt" )  ; then
		echo Exiting due to error during image mount. Cleaning up...
		rm -f "$installer_image_path"
		exit 1
	fi
	
	disk_image_device=$( sed -n -E 's/(\/dev\/disk[0-9]+).*/\1/p' "$temp_dir/hdiutil-attach-output.txt" | tail -n 1 )
	echo "Image attached as $disk_image_device"
	
	echo "Creating install media in disk image. Admin privileges required…"
	echo sudo "$MACOS_INSTALLER_APP_PATH/Contents/Resources/createinstallmedia" --volume "$installer_image_mount_path" --nointeraction
	if ! ( sudo "$MACOS_INSTALLER_APP_PATH/Contents/Resources/createinstallmedia" --volume "$installer_image_mount_path" --nointeraction ) ; then
		echo Exiting due to error during createinstallmedia process. Cleaning up...
		echo hdiutil detach "$disk_image_device"
		hdiutil detach "$disk_image_device"
		echo rm -f "$installer_image_path"
		rm -f "$installer_image_path"
		exit 1
	fi
	
	echo "Detaching/unmounting disk images"
	for i in "/Volumes/Shared Support"* ; do
		echo hdiutil detach "$i"
		hdiutil detach "$i"
	done
	echo hdiutil detach "$disk_image_device"
	hdiutil detach "$disk_image_device"
	
	echo "Converting disk image to raw"
	echo hdiutil convert "$installer_image_path" -format UDTO -o "$installer_raw_image_path"
	hdiutil convert "$installer_image_path" -format UDTO -o "$installer_raw_image_path"
	
	echo "Cleaning up: deleting intermediate image file"
	echo rm -f "$installer_image_path"
	rm -f "$installer_image_path"
	
	echo "Creating shallow qcow2 installer image"
	echo rm -f installer.qcow2
	rm -f installer.qcow2
	echo qemu-img create -f qcow2 -b "$installer_raw_image_path" -F raw installer.qcow2
	qemu-img create -f qcow2 -b "$installer_raw_image_path" -F raw installer.qcow2
	
	echo "Raw installer image is at $installer_raw_image_path, installer.qcow2 references it"

	echo "Obtaining and converting macOS installer image succeeded, now create a root image by running ./mac-host-3-prepare-root-image.sh"
fi


