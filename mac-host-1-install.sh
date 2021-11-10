#!/bin/bash

echo "This script installs the prerequisites for running Qemu VMs on macOS, i.e. Qemu itself. The script will also install out-of-tree prerequisites for building Qemu from source. Everything is installed via the Homebrew package manager."

if ! ( which brew > /dev/null ) ; then
	echo "Homebrew does not appear to be installed, please run the following command, then re-run this script."
	echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
	exit 1
fi

echo "Updating Homebrew, this might take a while…"
brew update

echo "Homebrew updated, in the next step we will install or update Qemu, the ninja build system, and GNU Make to the latest versions."
echo 'brew install qemu ninja make'

read -p 'OK? (y to continue) ' -n 1 -r
echo    # end line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	echo "Skipped installing Qemu, ninja and Make. Please ensure they are installed before attempting to run a VM."
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

echo Installing/updating Qemu, ninja and GNU Make…
if ! ( brew install qemu ninja make ) ; then
	echo "Something went wrong installing Qemu, ninja and GNU Make, please see log above for details."
	exit 1
fi

echo "All done! Next step: Obtain macOS Base System or Installer images for setting up macOS in a VM. Please run:"
echo './mac-host-2-download-image.sh'
