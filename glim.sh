#!/bin/bash
#
# BASH. It's what I know best, sorry.
#

# Check that we are *NOT* running as root
if [[ `id -u` -eq 0 ]]; then
  echo "ERROR: Don't run as root, use a user with full sudo access." 2>&1
  exit 1
fi

export os=$(uname)
export os_ver=$(uname -r | grep -Po '\d+\.\d+')

if [[ "${os}" == "Linux" ]]; then
    if [[ "${os_ver}" -lt 5.4 ]]; then
        echo "Kernel version less than 5.4, no exFAT support."  2>&1
        echo 2>&1
        export exFAT="mkfs.fat -F32 "
    else
        echo "Kernel version greater than or equal to 5.4 found, exFAT support enabled."  2>&1
        echo 2>&1
        export exFAT="mkexfatfs "
    fi
#TODO add checks for other OSes here
else
    echo "ERROR:  This script is Linux-specific.  Please execute on Linux (5.4 or greater for exFAT support)." 2>&1
    echo 2>&1
    exit 1
fi
    

usage () {
    echo << EOF

    usage:  ${0} <top-level block device>

    GLIM will create a hybrid USB device (UEFI GPT + BIOS GPT/MBR) on the
    supplied top-level block device.  GLIM should not be run as root.

    WARNING:  ALL DATA ON THIS BLOCK DEVICE WILL BE DESTROYED!

    If the device supplied is not a top-level block device (i.e., a partition),
    GLIM will exit with an error.  Also, GLIM will exit with errors should any
    of the commands it needs (e.g. grub-install, lsblk, parted, etc.) not be found.

    Once complete you will be able to load ISO 9660 bootable disk images to
    boot/iso/ on the third partition created by GLIM (with label "GLIM").


EOF
}
blkdev="${1}"

if [[ -z "${blkdev}" ]]; then
    echo "ERROR:  Block device not supplied." 2>&1
    echo "Please supply top-level block device to operate on." 2>&1
    echo 2>&1
    usage 2>&1
    exit 1
fi

if [[ -b "${blkdev}" ]]; then
    echo "ERROR:  Supplied parameter (${blkdev}) is not a block device." 2>&1
    echo 2>&1
    usage 2>&1
    exit 1
fi

if [[ "${os}" == "Linux" ]]; then
# Sanity check : lsblk
    if ! command -v lsblk &> /dev/null; then
        echo "ERROR:  lsblk command not found.  Please install util-linux package." 2>&1
        echo 2>&1
        usage 2>&1
        exit 1
    fi

    if ! command -v blkid &> /dev/null; then
        echo "ERROR:  blkid command not found.  Please install util-linux package." 2>&1
        echo 2>&1
        usage 2>&1
        exit 1
    fi
# Sanity check : is ${blkdev} a whole disk?
    blkdev_type="$(lsblk -lno TYPE ${blkdev} | head -n 1)"
    if [[ "${blkdev_type}" != "disk" ]]; then
        echo "ERROR:  ${blkdev} is type '${blkdev_type}', not 'disk'" 2>&1
        echo "Please supply a top-level (disk) block device." 2>&1
        echo 2>&1
        usage 2>&1
        exit 1
    fi

# Sanity check : sfdisk
    if ! command -v sfdisk &> /dev/null; then
        echo "ERROR:  sfdisk not found.  Please install the util-linux package." 2>&1
        echo 2>&1
        usage 2>&1
        exit 1
    fi

# Sanity check : sgdisk
    if ! command -v sgdisk &> /dev/null; then
        echo "ERROR:  sgdisk not found.  Please install the gptfdisk package." 2>&1
        echo 2>&1
        exit 1
    fi

# Sanity check : mkexfatfs
    if ! command -v ${exFAT}; then
        if [[ "${os_ver}" -lt 5.4 ]]; then
            echo "ERROR: mkfs.fat not found.  Please install dosfstools package." 2>&1
            exit 1
        else
            echo "ERROR:  ${exFAT} not found.  Please install exfat-utils."  2>&1
            exit 1
        fi
    fi
    # Sanity check : parted
    if ! command -v parted &> /dev/null; then
        echo "ERROR:  parted not found.  Please install the parted package." 2>&1
        echo 2>&1
        usage 2>&1
        exit 1
    fi
#TODO put other OS program checks here.
fi

read -n 1 -p "WARNING:  ABOUT TO DESTROY PARTITION TABLE ON ${blkdev}!
Wipe partition table on ${blkdev} and set up HybridUSB? (y/N) " partition
case ${partition} in
    [Nn]|"")
        echo 2>&1
        echo "Partition table wipe NOT ACCEPTED.  Aborting..." 2>&1
        exit 128
        ;;
    [Yy])
        echo 2>&1
        echo "Paritition table wipe ACCEPTED.  Wiping partition table..." 2>&1
        echo 2>&1
        ;;
    *)
        echo 2>&1
        echo "Invalid answer to prompt.  Aborting..." 2>&1
        echo 2>&1
        exit 2
        ;;
esac


if [[ "${os}" == "Linux" ]]; then
    if ! sudo sfdisk --delete ${blkdev}; then
        ret=$?
        echo "ERROR:  Wiping partition table in ${blkdev} failed.  Aborting..." 2>&1
        echo 2>&1
        exit ${ret}
    fi
    
    echo "Wiping partition table on ${blkdev} succeeded.  Continuing with partitioning..."  2>&1
    
    if ! sudo parted -s ${blkdev} mklabel gpt; then
        ret=$?
        echo "ERROR:  Creating new GPT partition table on ${blkdev} failed.  Aborting..." 2>&1
        echo 2>&1
        exit ${ret}
    fi
    
    echo "Creating partition table on ${blkdev} succeeded.  Continuing with partitioning..."  2>&1
    
    if ! sudo parted -s ${blkdev} mkpart bios 2048s 4096s; then
        ret=$?
        echo "ERROR:  Creating BIOS partition on ${blkdev} failed.  Aborting..." 2>&1
        echo 2>&1
        exit 1
        exit ${ret}
    elif ! sudo parted -s ${blkdev} set 1 bios_grub on; then
        ret=$?
        echo "ERROR:  Setting bios_grub flag on ${blkdev}1 failed.  Aborting..." 2>&1
        echo 2>&1
        exit ${ret}
    fi
    
    echo "Creating BIOS paritition on ${blkdev} succeeded.  Continuing with partitioning..."  2>&1
    
    if ! sudo parted -s ${blkdev} mkpart EFI 4MiB 64MiB; then
        ret=$?
        echo "ERROR:  Creating EFI boot partition in ${blkdev} failed.  Aborting..." 2>&1
        echo 2>&1
        exit ${ret}
    elif ! sudo parted -s ${blkdev} set 2 esp on; then
        ret=$?
        echo "ERROR:  Setting UEFI boot flag on ${blkdev}2 failed.  Aborting..." 2>&1
        echo 2>&1
        exit ${ret}
    elif ! sudo mkfs.fat -F 32 ${blkdev}2; then
        ret=$?
        echo "ERROR:  Formatting ${blkdev}2 with FAT32 filesystem failed.  Aborting..." 2>&1
        echo 2>&1
        exit ${ret}
    fi
    
    echo "Creating EFI paritition on ${blkdev}2 succeeded.  Continuing with partitioning..."  2>&1
    
    if ! sudo parted -s ${blkdev} mkpart GLIM 64MiB 100%; then
        ret=$?
        echo "ERROR:  Creating GLIM partition in ${blkdev} failed.  Aborting..." 2>&1
        echo 2>&1
        exit 1
    elif ! sudo parted -s ${blkdev} set 3 boot on; then
        ret=$?
        echo "ERROR:  Setting boot flag on ${blkdev}3 failed.  Aborting..." 2>&1
        echo 2>&1
        exit 1
    elif ! sudo ${exFAT} ${blkdev}3; then
        ret=$?
        echo "ERROR:  Formatting ${blkdev}3 with FAT32/exFAT filesystem failed.  Aborting..." 2>&1
        echo 2>&1
        exit 1
    fi
    
    echo "Creating GLIM paritition on ${blkdev} succeeded."  2>&1
    
    echo "Setting ${blkdev} as Hybrid MBR/GPT..." 2>&1
    if ! sudo sgdisk --hybrid 1:2:3 ${blkdev}; then
        ret=$?
        echo "ERROR:  Setting ${blkdev} as Hybrid MBR/GPT failed.  Aborting..." 2>&1
        echo 2>&1
        echo ${ret}
    fi

# Sanity check : GRUB2
    if command -v grub2-install &> /dev/null; then
        GRUB2_INSTALL="grub2-install"
        GRUB2_DIR="grub2"
    elif command -v grub-install &> /dev/null; then
        GRUB2_INSTALL="grub-install"
        GRUB2_DIR="grub"
    else
        echo "ERROR: grub2-install or grub-install commands not found." 2>&1
        echo 2>&1
        exit 1
    fi

# Sanity check : Our GRUB2 configuration
    GRUB2_CONF="$(dirname $0)/grub2"
    if [[ ! -f ${GRUB2_CONF}/grub.cfg ]]; then
      echo "ERROR: grub2/grub.cfg to use not found." 2>&1
      echo 2>&1
      exit 1
    fi

#
# Find GLIM device (use the first if multiple found, you've asked for trouble!)
#

    USBDEV3=$(blkid -L GLIM | head -n 1)
    
    # Sanity check : we found one partition to use with matching label
    if [[ -z "$USBDEV3" ]]; then
      echo "ERROR: no partition found with label 'GLIM', please create one." 2>&1
      echo 2>&1
      exit 1
    fi
    echo "Found partition with label 'GLIM' : ${USBDEV3}" 2>&1

# Taking this check out, as we created a hybrid USB (UEFI GPT + BIOS GPT/MBR)
# above
# Sanity check : our partition is the first and only one on the block device
#USBDEV=${USBDEV1%1}
#if [[ ! -b "$USBDEV" ]]; then
#  echo "ERROR: ${USBDEV} block device not found."
#  exit 1
#fi
#echo "Found block device where to install GRUB2 : ${USBDEV}"
#if [[ `ls -1 ${USBDEV}* | wc -l` -ne 2 ]]; then
#  echo "ERROR: ${USBDEV1} isn't the only partition on ${USBDEV}"
#  exit 1
#fi

# mount GLIM device to /mnt, EFI to /mnt/boot/EFI
    if ! grep -q /mnt /proc/mounts; then
        sudo mount ${USBDEV3} /mnt
        sudo mkdir -p /mnt/boot/EFI
        sudo mount ${blkdev}2 /mnt/boot/EFI
    else
        echo "Something is already mounted at /mnt.  Aborting GLIM..." 2>&1
        echo 2>&1
        exit 1
    fi
# Sanity check : our partition is mounted
    if ! grep -q -w ${USBDEV3} /proc/mounts; then
        echo "ERROR: ${USBDEV3} isn't mounted" 2>&1
        echo 2>&1
        exit 1
    fi
    USBMNT=$(grep -w ${USBDEV3} /proc/mounts | cut -d ' ' -f 2)
    if [[ -z "$USBMNT" ]]; then
        echo "ERROR: Couldn't find mount point for ${USBDEV3}" 2>&1
        exit 1
    fi
    echo "Found mount point for GLIM filesystem : ${USBMNT}" 2>&1

    # Install GRUB2
    # Check BIOS support
    if [[ -d /usr/lib/grub/i386-pc ]]; then
        echo "ERROR: no /usr/lib/grub/i386-pc dir. Aborting..." 2>&1
        echo 2>&1
        exit 1
    else
        GRUB_TARGET="--target=i386-pc"
        echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${blkdev} (with sudo) ..." 2>&1
        if ! sudo ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${blkdev}; then
            ret=$?
            echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status installing ${GRUB_TARGET}." 2>&1
            exit ${ret}
        fi
    fi
    
    # Sanity check : for EFI, an additional package might be missing
    if [[ ! -d /usr/lib/grub/x86_64-efi ]]; then
        echo "ERROR: no /usr/lib/grub/x86_64-efi directory was found.  Aborting..." 2>&1
        echo 2>&1
        exit 1
    else
        GRUB_TARGET="--target=x86_64-efi --efi-directory=${USBMNT}/boot/EFI --removable"
        echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${blkdev} (with sudo) ..."
        if ! sudo ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${blkdev}; then
            ret=$?  
            echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
            exit ${ret}
        fi
    fi
    
    
    #
    # Get serious. If we get here, things are looking sane
    #
    
    # Sanity check : human will read the info and confirm
    #read -n 1 -s -p "Ready to install GLIM. Continue? (Y/n) " PROCEED

    
    # Check USB mount dir write permission, to use sudo if missing
    if [[ -w "${USBMNT}" ]]; then
      CMD_PREFIX=""
    else
      CMD_PREFIX="sudo"
    fi
#TODO:  Add other OS specific commands here.
fi    

# Copy GRUB2 configuration
echo "Running rsync -rpt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts --exclude=icons/originals ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR} ..."
if ! ${CMD_PREFIX} rsync -rpt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts --exclude=icons/originals ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR}; then
    ret=$?
    echo "ERROR: the rsync copy returned with an error exit status." 2>&1
    exit ${ret}
fi
    
# Be nice and pre-create the directory, and mention it
[[ -d ${USBMNT}/boot/iso ]] || ${CMD_PREFIX} mkdir -p ${USBMNT}/boot/iso
echo "GLIM installed! Time to populate the boot/iso directory." 2>&1
echo 2>&1

