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
  exit 1
fi
USBMNT=`grep -w ${USBDEV1} /proc/mounts | cut -d ' ' -f 2`
if [[ -z "$USBMNT" ]]; then
  echo "ERROR: Couldn't find mount point for ${USBDEV1}"
  exit 1
fi
echo "Found mount point for filesystem : ${USBMNT}"

BIOS=true
# Check BIOS support
if [[ -d /usr/lib/grub/i386-pc ]]; then
  BIOS=true
else
  echo "WARNING: no /usr/lib/grub/i386-pc dir. Skipping Grub BIOS support"
  BIOS=false
  EFI=true
fi

#
# EFI or regular?
#

if [[ $BIOS == true ]]; then
  # Set the target
  read -n 1 -s -p "Install for EFI in addition to standard BIOS? (Y/n) " EFI
  if [[ "$EFI" == "n" ]]; then
      EFI=false
      echo "n"
  else
    EFI=true
    echo "y"
  fi
fi

# Sanity check : for EFI, an additional package might be missing
if [[ $EFI == true && ! -d /usr/lib/grub/x86_64-efi ]]; then
  if [[ $BIOS == false ]]; then
    echo "ERROR: neither support for BIOS or EFI was found"
    exit 1
  else
    echo "WARNING: no /usr/lib/grub/x86_64-efi dir (grub2-efi-x64-modules rpm or grub-efi-amd64-bin deb missing?)"
  fi
fi


#
# Get serious. If we get here, things are looking sane
#

# Sanity check : human will read the info and confirm
read -n 1 -s -p "Ready to install GLIM. Continue? (Y/n) " PROCEED
if [[ "$PROCEED" == "n" ]]; then
  echo "n"
  exit 2
else
  echo "y"
fi

# Install GRUB2
if [[ $BIOS == true ]]; then
  GRUB_TARGET="--target=i386-pc"
  echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${USBDEV} (with sudo) ..."
  sudo ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${USBDEV}
  if [[ $? -ne 0 ]]; then
      echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
      exit 1
  fi
fi
if [[ $EFI == true ]]; then
  GRUB_TARGET="--target=x86_64-efi --efi-directory=${USBMNT} --removable"
  echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${USBDEV} (with sudo) ..."
  sudo ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory=${USBMNT}/boot ${USBDEV}
  if [[ $? -ne 0 ]]; then
    echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
    exit 1
  fi
fi

# Check USB mount dir write permission, to use sudo if missing
if [[ -w "${USBMNT}" ]]; then
  CMD_PREFIX=""
else
  CMD_PREFIX="sudo"
fi

# Copy GRUB2 configuration
echo "Running rsync -rt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR} ..."
${CMD_PREFIX} rsync -rt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR}
if [[ $? -ne 0 ]]; then
  echo "ERROR: the rsync copy returned with an error exit status."
  exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d ${USBMNT}/boot/iso ]] || ${CMD_PREFIX} mkdir ${USBMNT}/boot/iso
echo "GLIM installed! Time to populate the boot/iso/ sub-directories."

# Now also pre-create all supported sub-directories since empty are ignored
args=(
  -E -n
  '/\(distro-list-start\)/,/\(distro-list-end\)/{s,^\s+([a-z]+)$,\1,p}'
)

for DIR in $(sed "${args[@]}" "$(dirname "$0")"/README.md); do
  [[ -d ${USBMNT}/boot/iso/${DIR} ]] || ${CMD_PREFIX} mkdir ${USBMNT}/boot/iso/${DIR}
done

