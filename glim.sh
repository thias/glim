#!/usr/bin/env bash
#
# BASH. It's what I know best, sorry.
#

# Check that we are *NOT* running as root
if (( EUID != 0 )); then
  CMD_PREFIX='sudo'
else
  CMD_PREFIX=''
fi

# Sanity check : GRUB2
if command -v grub2-install &>/dev/null; then
  GRUB2_INSTALL='grub2-install'
  GRUB2_DIR='grub2'
elif command -v grub-install &>/dev/null; then
  GRUB2_INSTALL='grub-install'
  GRUB2_DIR='grub'
fi
if [[ -z "$GRUB2_INSTALL" ]]; then
  echo 'ERROR: grub2-install or grub-install commands not found.'
  exit 1
fi

# Sanity check : Our GRUB2 configuration
GRUB2_CONF="$(dirname "$0")/grub2"
if [[ ! -f "${GRUB2_CONF}/grub.cfg" ]]; then
  echo 'ERROR: grub2/grub.cfg to use not found.'
  exit 1
fi

#
# Find GLIM device (use the first if multiple found, you've asked for trouble!)
#

# Sanity check : blkid command
if ! command -v blkid &>/dev/null; then
  echo 'ERROR: blkid command not found.'
  exit 1
fi
USBDEV1="$(${CMD_PREFIX} blkid --label GLIM --list-one)"

# Sanity check : we found one partition to use with matching label
if [[ -z "$USBDEV1" ]]; then
  echo "ERROR: no partition found with label 'GLIM', please create one."
  exit 1
fi
echo "Found partition with label 'GLIM' : ${USBDEV1}"

# Sanity check : our partition is the first and only one on the block device
USBDEV="${USBDEV1%1}"
if [[ ! -b "$USBDEV" ]]; then
  echo "ERROR: ${USBDEV} block device not found."
  exit 1
fi
echo "Found block device where to install GRUB2 : ${USBDEV}"
if [[ "$(${CMD_PREFIX} lsblk --list --noheadings --output TYPE "${USBDEV}" | grep --count 'part')" -ne 1 ]]; then
  echo "ERROR: ${USBDEV1} isn't the only partition on ${USBDEV}"
  exit 1
fi

# Sanity check : our partition is mounted
if ! ${CMD_PREFIX} findmnt --noheadings --output TARGET "${USBDEV1}" &>/dev/null; then
  echo "ERROR: ${USBDEV1} isn't mounted"
  exit 1
fi
USBMNT="$(${CMD_PREFIX} findmnt --noheadings --output TARGET "${USBDEV1}")"
if [[ -z "$USBMNT" ]]; then
  echo "ERROR: Couldn't find mount point for ${USBDEV1}"
  exit 1
fi
echo "Found mount point for filesystem : ${USBMNT}"

BIOS=1
# Check BIOS support
if [[ -d '/usr/lib/grub/i386-pc' ]]; then
  BIOS=1
else
  echo "WARNING: no /usr/lib/grub/i386-pc dir. Skipping Grub BIOS support"
  BIOS=0
  EFI=1
fi

#
# EFI or regular?
#

if (( BIOS == 1 )); then
  # Set the target
  read -r -n 1 -s -p 'Install for EFI in addition to standard BIOS? (Y/n) ' EFI
  if [[ "$EFI" == 'n' ]]; then
      EFI=0
      echo 'n'
  else
    EFI=1
    echo 'y'
  fi
fi

# Sanity check : for EFI, an additional package might be missing
if [[ "$EFI" -ne 1 && ! -d '/usr/lib/grub/x86_64-efi' ]]; then
  if (( BIOS == 0 )); then
    echo 'ERROR: neither support for BIOS or EFI was found'
  else
    echo "WARNING: no /usr/lib/grub/x86_64-efi dir (grub2-efi-x64-modules rpm missing?)"
    exit 1
  fi
fi


#
# Get serious. If we get here, things are looking sane
#

# Sanity check : human will read the info and confirm
read -r -n 1 -s -p "Ready to install GLIM. Continue? (Y/n) " PROCEED
if [[ "$PROCEED" == 'n' ]]; then
  echo 'n'
  exit 2
else
  echo 'y'
fi

# Install GRUB2
GRUB_COMMON_ARGS=("--boot-directory=${USBMNT}/boot" '--themes=' '--recheck')
declare -a GRUB_TARGET
if (( BIOS == 1 )); then
  GRUB_TARGET=('--target=i386-pc')
  if ! (set -x; ${CMD_PREFIX} "${GRUB2_INSTALL}" "${GRUB_TARGET[@]}" "${GRUB_COMMON_ARGS[@]}" "${USBDEV}"); then
      echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
      exit 1
  fi
fi
if (( EFI == 1 )); then
  GRUB_TARGET=('--target=x86_64-efi' "--efi-directory=${USBMNT}" '--removable')
  if ! (set -x; ${CMD_PREFIX} "${GRUB2_INSTALL}" "${GRUB_TARGET[@]}" "${GRUB_COMMON_ARGS[@]}"); then
    echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
    exit 1
  fi
fi


# Copy GRUB2 configuration
if ! (set -x; ${CMD_PREFIX} rsync -rpt --delete --exclude='i386-pc' --exclude='x86_64-efi' --exclude='fonts' --exclude='icons/originals' "${GRUB2_CONF}/" "${USBMNT}/boot/${GRUB2_DIR}"); then
  echo "ERROR: the rsync copy returned with an error exit status."
  exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d "${USBMNT}/boot/iso" ]] || ${CMD_PREFIX} mkdir "${USBMNT}/boot/iso"
echo "GLIM installed! Time to populate the boot/iso directory."
