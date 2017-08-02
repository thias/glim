#!/bin/bash
#
# BASH. It's what I know best, sorry.
#

# Check that we are *NOT* running as root
if [[ `id -u` -eq 0 ]]; then
  echo "ERROR: Don't run as root, use a user with full sudo access."
  exit 1
fi

# Sanity check : GRUB2
if which grub2-install &>/dev/null; then
  GRUB2_INSTALL="grub2-install"
  GRUB2_DIR="grub2"
elif which grub-install &>/dev/null; then
  GRUB2_INSTALL="grub-install"
  GRUB2_DIR="grub"
fi
if [[ -z "$GRUB2_INSTALL" ]]; then
  echo "ERROR: grub2-install or grub-install commands not found."
  exit 1
fi

# Sanity check : Our GRUB2 configuration
GRUB2_CONF="`dirname $0`/grub2"
echo $GRUB2_CONF
if [[ ! -f ${GRUB2_CONF}/grub.cfg ]]; then
  echo "ERROR: grub2/grub.cfg to use not found."
  exit 1
fi

#
# Find GLIM device (use the first if multiple found, you've asked for trouble!)
#

# Sanity check : blkid command
if ! which blkid &>/dev/null; then
  echo "ERROR: blkid command not found."
  exit 1
fi
USBDEV1=`blkid -L GLIM | head -n 1`

# Sanity check : we found one partition to use with matching label
if [[ -z "$USBDEV1" ]]; then
  echo "ERROR: no partition found with label 'GLIM', please create one."
  exit 1
fi
echo "Found partition with label 'GLIM' : ${USBDEV1}"

# Sanity check : our partition is the first and only one on the block device
USBDEV=${USBDEV1%1}
if [[ ! -b "$USBDEV" ]]; then
  echo "ERROR: ${USBDEV} block device not found."
  exit 1
fi
echo "Found block device where to install GRUB2 : ${USBDEV}"
if [[ `ls -1 ${USBDEV}* | wc -l` -ne 2 ]]; then
  echo "ERROR: ${USBDEV1} isn't the only partition on ${USBDEV}"
  exit 1
fi

# Sanity check : our partition is mounted
if ! grep -q -w ${USBDEV1} /proc/mounts; then
  echo "ERROR: ${USBDEV1} isn't mounted"
fi
USBMNT=`grep -w ${USBDEV1} /proc/mounts | cut -d ' ' -f 2`
if [[ -z "$USBMNT" ]]; then
  echo "ERROR: Couldn't find mount point for ${USBDEV1}"
fi
echo "Found mount point for filesystem : ${USBMNT}"


#
# EFI or regular?
#

# Set the target
read -n 1 -s -p "Install for EFI instead of standard BIOS? (y/N) " EFI
if [[ "$EFI" == "y" ]]; then
  GRUB_TARGET="--target=x86_64-efi --efi-directory=${USBMNT} --removable"
  echo "y"
else
  GRUB_TARGET="--target=i386-pc"
  echo "n"
fi

# Sanity check : for EFI, an additional package might be missing
if [[ $EFI == "y" && ! -d /usr/lib/grub/x86_64-efi ]]; then
  echo "ERROR: no /usr/lib/grub/x86_64-efi dir (grub2-efi-modules rpm missing?)"
  exit 1
fi


#
# Get serious. If we get here, things are looking sane
#

# Sanity check : human will read the info and confirm
read -n 1 -s -p "Ready to install GLIM. Continue? (y/N) " PROCEED
if [[ "$PROCEED" != "y" ]]; then
  echo "n"
  exit 2
else
  echo "y"
fi

# Install GRUB2
echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${USBDEV} (with sudo) ..."
sudo ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${USBDEV}
if [[ $? -ne 0 ]]; then
  "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
  exit 1
fi

# Copy GRUB2 configuration
echo "Running rsync -a --delete --exclude=i386-pc --exclude=x86_64-efi ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR} ..."
rsync -a --delete --exclude=i386-pc --exclude=x86_64-efi ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR}
if [[ $? -ne 0 ]]; then
  "ERROR: the rsync copy returned with an error exit status."
  exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d ${USBMNT}/boot/iso ]] || mkdir ${USBMNT}/boot/iso
echo "GLIM installed! Time to populate the boot/iso directory."

