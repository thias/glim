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
# Find GLIM device
#

# Sanity check : blkid command
if ! which blkid &>/dev/null; then
  echo "ERROR: blkid command not found."
  exit 1
fi
USBDEV1=`blkid -L GLIM`

# Sanity check : we found one partition to use with matching label
if [[ -z "$USBDEV1" ]]; then
  echo "ERROR: no partition found with label 'GLIM', please create one."
  exit 1
elif [[ "$(echo "$USBDEV1" | wc -l)" -gt 1 ]]; then
  echo "ERROR: multiple partitions found with label 'GLIM', please disconnect/rename the unwanted ones."
  exit 1
fi
echo "Found partition with label 'GLIM' : ${USBDEV1}"

# Sanity check : our partition is the first one on the block device
if [[ ! "${USBDEV1}" == *[a-z]1 ]]; then
  echo "ERROR: $USBDEV1 is not the first partition on the block device."
  exit 1
fi
USBDEV=${USBDEV1%1}
if [[ ! -b "$USBDEV" ]]; then
  echo "ERROR: ${USBDEV} block device not found."
  exit 1
fi
echo "Found block device where to install GRUB2 : ${USBDEV}"
if [[ `ls -1 ${USBDEV}* | wc -l` -gt 3 ]]; then
  echo "WARNING: There are more than two partitions on ${USBDEV}"
fi

# Look for second partition
USBDEV2=`blkid -L GLIMISO`
if [[ -z "$USBDEV2" ]]; then
  echo "Did NOT find a second partition with label 'GLIMISO', so assuming ISO files will be stored on the main 'GLIM' partition."
elif [[ "$(echo "$USBDEV2" | wc -l)" -gt 1 ]]; then
  echo "ERROR: multiple partitions found with label 'GLIMISO', please disconnect/rename the unwanted ones."
  exit 1
else
  if [[ "$USBDEV2" != "${USBDEV}2" ]]; then
    USBDEV2=""
    echo "WARNING: Ignored 'GLIMISO' partition ${USBDEV2} because it is not the second partition on the block device."
  else
    echo "Found partition with label 'GLIMISO' : ${USBDEV2}"
  fi
fi

# Sanity check : our GLIM partition is mounted
if ! grep -q -w ${USBDEV1} /proc/mounts; then
  echo "ERROR: ${USBDEV1} isn't mounted"
  exit 1
fi
USBMNT="$(grep -w ${USBDEV1} /proc/mounts | cut -d ' ' -f 2)"
if [[ -z "$USBMNT" ]]; then
  echo "ERROR: Couldn't find mount point for ${USBDEV1}"
  exit 1
fi
echo "Found 'GLIM' mount point for filesystem : ${USBMNT}"

# Sanity check : our GLIMISO partition is mounted (if exists)
if [[ -z "$USBDEV2" ]]; then
  # (no second partition for ISOs)
  USBMNTISO="${USBMNT}"
  #USBMNTISO="${USBMNT}/boot"	# have ISOs where GLIM used to put them
else
  if ! grep -q -w ${USBDEV2} /proc/mounts; then
    echo "ERROR: ${USBDEV2} isn't mounted"
    exit 1
  fi
  USBMNTISO="$(grep -w ${USBDEV2} /proc/mounts | cut -d ' ' -f 2)"
  if [[ -z "$USBMNTISO" ]]; then
    echo "ERROR: Couldn't find mount point for ${USBDEV2}"
    exit 1
  fi
  echo "Found 'GLIMISO' mount point for filesystem : ${USBMNTISO}"
fi

# Check BIOS support
if [[ -d /usr/lib/grub/i386-pc ]]; then
  BIOS=true
else
  echo "WARNING: no /usr/lib/grub/i386-pc dir. Skipping Grub BIOS support"
  BIOS=false
  EFI=true
fi

# Check disk's partition table type
echo    "Running fdisk -l ${USBDEV} (with sudo) to check if using GPT or MBR..."
PartType="$(sudo fdisk -l ${USBDEV} | grep -iPo "Disklabel type:\s\K.*")"
if [[ $? -ne 0 ]]; then
  PartType="dos"	# Error, so assume the best case so don't give spurious warnings
elif [[ "$PartType" == "gpt" ]]; then
  echo "The ${USBDEV} block device uses GPT, which means you can only install for EFI (not BIOS) unless it has a 1MB BIOS Boot partition for Grub.  GLIM needs this after the GLIMISO partition (if there is one)."
else
  PartType="dos"	# Ensure script behaves sensibly if fdisk doesn't output "gpt" or "dos"
  echo "The ${USBDEV} block device uses GPT, which means Grub can install for both EFI & BIOS."
fi

#
# EFI or regular?
#

if [[ $BIOS == true ]]; then
  # Set the target
  read -n 1 -s -p "Install for EFI? (Y/n) " EFI
  if [[ "$EFI" == "n" || "$EFI" == "N" ]]; then
    EFI=false
    echo "n"
  else
    EFI=true
    echo "y"
    
    if [[ "$PartType" == "gpt" ]]; then
		BiosBootPartWarning="(Grub needs a BIOS Boot Partition) "
    fi
    read -n 1 -s -p "Also install for standard BIOS? $BiosBootPartWarning(y/N) " BIOS
    if [[ "$BIOS" == "y" || "$BIOS" == "Y" ]]; then
      BIOS=true
      echo "y"
    else
      BIOS=false
      echo "n"
    fi
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
echo ""
read -n 1 -s -p "Ready to install GLIM. Continue? (y/N) " PROCEED
if [[ "$PROCEED" == "y" || "$PROCEED" == "Y" ]]; then
  echo "y"
else
  echo "n"
  exit 2
fi

# Install GRUB2
if [[ $BIOS == true ]]; then
  GRUB_TARGET="--target=i386-pc"
  echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory '${USBMNT}/boot' ${USBDEV} (with sudo) ..."
  sudo          ${GRUB2_INSTALL} ${GRUB_TARGET} --boot-directory "${USBMNT}/boot" ${USBDEV}
  if [[ $? -ne 0 ]]; then
      echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
      exit 1
  fi
fi
if [[ $EFI == true ]]; then
  GRUB_TARGET="--target=x86_64-efi --removable"
  echo "Running ${GRUB2_INSTALL} ${GRUB_TARGET} --efi-directory '${USBMNT}' --boot-directory '${USBMNT}/boot' ${USBDEV} (with sudo) ..."
  sudo          ${GRUB2_INSTALL} ${GRUB_TARGET} --efi-directory "${USBMNT}" --boot-directory "${USBMNT}/boot" ${USBDEV}
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
if [[ -w "${USBMNTISO}" ]]; then
  ISOCMD_PREFIX=""
else
  ISOCMD_PREFIX="sudo"
fi

# Copy GRUB2 configuration
echo "Running rsync -rt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts -- ${GRUB2_CONF}/ '${USBMNT}/boot/${GRUB2_DIR}' ..."
${CMD_PREFIX} rsync -rt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts -- ${GRUB2_CONF}/ "${USBMNT}/boot/${GRUB2_DIR}"
if [[ $? -ne 0 ]]; then
  echo "ERROR: the rsync copy returned with an error exit status."
  exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d "${USBMNTISO}/iso" ]] || ${ISOCMD_PREFIX} mkdir "${USBMNTISO}/iso"
echo "GLIM installed! Time to populate the '${USBMNTISO}/iso' sub-directories."

# Now also pre-create all supported sub-directories since empty are ignored
args=(
  -E -n
  '/\(distro-list-start\)/,/\(distro-list-end\)/{s,^\* \[`([a-z0-9]+)`\].*$,\1,p}'
)

for DIR in $(sed "${args[@]}" "$(dirname "$0")"/README.md); do
  [[ -d "${USBMNTISO}/iso/${DIR}" ]] || ${ISOCMD_PREFIX} mkdir "${USBMNTISO}/iso/${DIR}"
done

echo "Finished!"
