#!/bin/bash
set -e		# exit on error
#set -v		# print script lines to be executed
#set -x		# print commands being executed

GlimSize=100M
BiosBootSize=1M

# Check if necessary commands are installed
NeededCmds="fdisk sgdisk partprobe awk mkfs.fat lsblk blockdev"
for Cmd in $NeededCmds; do
	if [ -z "$(which $Cmd | cat)" ]; then
		# (command not installed)
		if [ -n "$(which apt | cat)" ]; then
			# (system uses 'apt') so offer to install missing command
			echo "This script needs the '$Cmd' command, so trying to install it:"
			if   [ "$Cmd" == "sgdisk" ]; then
				sudo apt install gdisk
			elif [ "$Cmd" == "partprobe" ]; then
				sudo apt install parted
			elif [ "$Cmd" == "awk" ]; then
				sudo apt install gawk
			elif [ "$Cmd" == "mkfs.fat" ]; then
				sudo apt install dosfstools
			elif [ "$Cmd" == "lsblk" ]; then
				sudo apt install util-linux		# this should always be installed
			elif [ "$Cmd" == "blockdev" ]; then
				sudo apt install util-linux		# ditto
			else
				sudo apt install $Cmd	# works for "fdisk"
			fi
		fi
	fi
done
for Cmd in $NeededCmds; do
	if [ -z "$(which $Cmd | cat)" ]; then
		# (command not installed)
		echo "ERROR: This script needs the '$Cmd' command, please install it."
		exit 1
	fi
done

# Show warning to user
echo "Please read the 'README.md' documentation before using this script."
echo ""
echo "WARNING: This script will format a chosen empty hard disk with GLIM's recommended set-up.  Although I've tried to be careful, a bug could potentially wipe your whole computer.  So make sure you have a recent backup before executing this script."
echo ""
echo 'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'
echo ""
read -p "If you have read, understood & fully accepted the above, then please enter 'yes' in capitals: " Ans
if [ "$Ans" != "YES" ]; then
	echo "Script cancelled by user."
	exit 0
fi
echo ""

# Specify disk to overwrite
read -p "Please enter path of disk to overwrite: " Disk
if [ -z "$Disk" ]; then echo "Script cancelled by user."; exit 0; fi
echo ""

# Check that disk is a block device
#if [[ ! "$Disk" == /dev/* ]]; then
#	echo "ERROR: '$Disk' does not start with /dev/"
#	exit 1
#fi
Devices="$(lsblk -o name -lpn --nodeps -e7)"
if [ -z "$(echo "$Devices" | grep "^${Disk}$")" ]; then
	echo "ERROR: '$Disk' is not a known block device:"
	echo "$Devices"
	exit 1
fi

# Check not overwriting the boot disk (but this is not foolproof)
if [[ "$(awk '$2 == "/boot" && $1 ~ /^\/dev\// { print $1 }' /proc/self/mounts)" == ${Disk}* ]]; then
	echo "ERROR: $Disk is the boot disk."
	exit 1
fi

## Check that disk has no mounted partitions
#if [ -n "$(grep ^$Disk /proc/self/mounts | cat)" ]; then
#	echo "ERROR: $Disk is has mounted partitions."
#	exit 1
#fi

# Check that disk has no partitions
set -x
Partitions="$(sudo fdisk -l $Disk | sed '1,/^$/d')"
set +x
if [ "$(echo "$Partitions" | wc -l)" -gt 1 ]; then
	echo "ERROR: $Disk is not empty, it has partitions:"
	echo "$Partitions"
	exit 1
fi

# Confirm using the correct disk
sudo sgdisk --print $Disk
echo ""
read -p "Is this the correct disk to overwrite? [y/N] " Ans
if [[ "$Ans" != "y" && "$Ans" != "Y" ]]; then echo "Script cancelled by user."; exit 1; fi
echo ""

# Create partitions on disk
trap "echo 'ERROR: Script did not finished partitioning.'" EXIT
set -x
#sudo sgdisk --zap-all $Disk	# erase any existing partition information from HD
sudo sgdisk --mbrtogpt $Disk	# use GPT not MBR
#sudo sgdisk --clear $Disk		# wipe any previous partition
#sudo partprobe $Disk			# request the OS re-reads the partition table
sudo blockdev --rereadpt $Disk	# request the OS re-reads the partition table', and errors if a partition is already mounted on the disk

sudo sgdisk --new=1:0:+$GlimSize $Disk # use first 100MB
sudo sgdisk --new=3:-${BiosBootSize}:0 --typecode=3:ef02 --partition-guid=3:21686148-6449-6E6F-744E-656564454649 $Disk # use last 1MB for BIOS Boot partition needed by GRUB
sudo sgdisk --new=2:0:0 $Disk # use rest of space
#sudo sgdisk --typecode=1:8300 --typecode=2:8300 $Disk
#sudo sgdisk --change-name=1:GLIM $Disk	# This is just a human-readable label, displayed by --print under the Name column
#sudo sgdisk --change-name=2:GLIMISO $Disk
sudo sgdisk --change-name=3:"BIOS Boot" $Disk
sudo partprobe $Disk	# ensure kernel is using the new partition table, before we format partitions
set +x

echo "Waiting a few seconds... "
sleep 2		# give OS time to auto-mount new partitions, if they happened to start at same location as a previously-deleted partition
sudo umount ${Disk}1 2>/dev/null | cat
sudo umount ${Disk}2 2>/dev/null | cat
sudo umount ${Disk}3 2>/dev/null | cat

# Format partitions
trap "echo 'ERROR: Script did not finished formatting.'" EXIT
set -x
sudo mkfs.fat -F 32 -n GLIM ${Disk}1
sudo mkfs.ext4 -L GLIMISO ${Disk}2
set +x

# Try to get OS to mount new partitions
sleep 1
sudo partprobe $Disk
#sudo blockdev --rereadpt $Disk

# Report success
echo ""
echo "Successfully finished creating the partitions needed by GLIM."
echo "Ensure ${Disk}1 (GLIM) & ${Disk}2 (GLIMISO) are mounted before running the 'glim.sh' script."
trap "" EXIT
