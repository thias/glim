#!/usr/bin/env bash
#
# BASH. It's what I know best, sorry.
#

# Check that we are *NOT* running as root
if (( EUID == 0 )); then
  echo 'ERROR: Do not run as root, use a user with full sudo access.'
  exit 1
fi

# Sanity check : GRUB2
if command -v grub2-install &>/dev/null; then
  GRUB2_INSTALL='grub2-install'
  GRUB2_DIR='grub2'
elif command -v grub-install &>/dev/null; then
  GRUB2_INSTALL='grub-install'
  GRUB2_DIR='grub'
else
  echo 'ERROR: grub2-install or grub-install commands not found.'
  exit 1
fi

# Sanity check : Our GRUB2 configuration
GRUB2_CONF="$(dirname -- "$0")/grub2"
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
USBDEV1="$(blkid -L GLIM)"

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
if [[ "$(lsblk --list --noheadings --output TYPE -- "${USBDEV}" | grep --count 'part')" -ne 1 ]]; then
  echo "ERROR: ${USBDEV1} isn't the only partition on ${USBDEV}"
  exit 1
fi

# Sanity check : our partition is mounted
if ! findmnt --noheadings --output TARGET -- "${USBDEV1}" &>/dev/null; then
  echo "ERROR: ${USBDEV1} isn't mounted"
  exit 1
fi
USBMNT="$(findmnt --noheadings --output TARGET -- "${USBDEV1}")"
if [[ -z "$USBMNT" ]]; then
  echo "ERROR: Couldn't find mount point for ${USBDEV1}"
  exit 1
fi
echo "Found mount point for filesystem : ${USBMNT}"


# Check supported targets
if [[ -d '/usr/lib/grub/i386-pc' ]]; then
  BIOS=1
else
  BIOS=0
  echo 'WARNING: no /usr/lib/grub/i386-pc dir. Skipping GRUB x86 BIOS support.'
fi
if [[ -d '/usr/lib/grub/x86_64-efi' ]]; then
  EFI=1
else
  EFI=0
  echo 'WARNING: no /usr/lib/grub/x86_64-efi dir, grub2-efi-x64-modules package missing? Skipping GRUB x86_64 UEFI support.'
fi

if (( BIOS == 0 && EFI == 0 )); then
  echo 'ERROR: No usable install targets found. Cannot proceed.'
  exit 1
fi

# Select the install targets

if (( BIOS == 1 )); then
  read -r -n 1 -s -p 'Install GRUB for x86 BIOS? (Y/n) ' PROCEED
  if [[ "$PROCEED" == 'n' ]]; then
    BIOS=0
    echo 'n'
  else
    echo 'Y'
  fi
fi
if (( EFI == 1 )); then
  read -r -n 1 -s -p 'Install GRUB for x86_64 UEFI? (Y/n) ' PROCEED
  if [[ "$PROCEED" == 'n' ]]; then
    EFI=0
    echo 'n'
  else
    echo 'Y'
  fi
fi
if (( BIOS == 0 && EFI == 0 )); then
  echo 'ERROR: No install targets selected. Cannot proceed.'
  exit 2
fi

#
# Get serious. If we get here, things are looking sane
#

# Sanity check : human will read the info and confirm
read -r -n 1 -s -p 'Ready to install GLIM. Continue? (Y/n) ' PROCEED
if [[ "$PROCEED" == 'n' ]]; then
  echo 'n'
  exit 2
else
  echo 'Y'
fi

# Install GRUB2
GRUB_COMMON_ARGS=("--boot-directory=${USBMNT}/boot" '--themes=' '--recheck')
declare -a GRUB_TARGET
if (( BIOS == 1 )); then
  GRUB_TARGET=('--target=i386-pc')
  if ! (set -x; ${CMD_PREFIX} "${GRUB2_INSTALL}" "${GRUB_TARGET[@]}" "${GRUB_COMMON_ARGS[@]}" -- "${USBDEV}"); then
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

# Check USB mount dir write permission, to use sudo if missing
if [[ -w "${USBMNT}" ]]; then
  CMD_PREFIX=''
else
  CMD_PREFIX='sudo'
fi

# Copy GRUB2 configuration
if ! (set -x; rsync -rpt --delete --exclude='i386-pc' --exclude='x86_64-efi' --exclude='fonts' --exclude='icons/originals' -- "${GRUB2_CONF}/" "${USBMNT}/boot/${GRUB2_DIR}"); then
  echo 'ERROR: the rsync copy returned with an error exit status.'
  exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d "${USBMNT}/boot/iso" ]] || mkdir -- "${USBMNT}/boot/iso"
echo 'GLIM installed! Time to populate the boot/iso directory.'
