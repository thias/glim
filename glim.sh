#!/usr/bin/env bash
#
# BASH. It's what I know best, sorry.
#

# Sanity check : partition is specified and exists
if [[ -z "$1" ]]; then
	echo 'ERROR: no partition specified.'
	echo "Usage: ${0##*/} /dev/path/to/target/partition "
	exit 1
elif [[ ! -b "$1" ]]; then
	echo "ERROR: $1 block device not found."
	exit 1
else
	USBPART="$(realpath -- "$1")"
fi


# Use `sudo` if user is not root
if (( EUID != 0 )); then
        PRIVILEGE_ELEVATION='sudo --'
else
        PRIVILEGE_ELEVATION=''
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
GRUB2_CONF="$(realpath -- "${0%/*}/grub2")"
if [[ ! -f "${GRUB2_CONF}/grub.cfg" ]]; then
	echo 'ERROR: grub2/grub.cfg to use not found.'
	exit 1
fi

#
# Find disk of GLIM partition
#

USBDEV="$(lsblk --list --nodeps --noheadings --output PKNAME --paths -- "$USBPART")"
echo "GRUB2 will be installed to: disk ${USBDEV} partition ${USBPART}"


# Sanity check : our partition is mounted
if ! findmnt --noheadings --output TARGET -- "${USBPART}" &>/dev/null; then
	echo "ERROR: ${USBPART} isn't mounted"
	exit 1
else
	USBMNT="$(findmnt --noheadings --output TARGET -- "${USBPART}")"
	echo "Found mount point for filesystem : ${USBMNT}"
fi


# Check supported targets
if [[ -d '/usr/lib/grub/i386-pc' ]]; then
	BIOS=1
else
	BIOS=0
	echo 'WARNING: no /usr/lib/grub/i386-pc dir. Skipping GRUB x86 BIOS support'
fi
if [[ -d '/usr/lib/grub/x86_64-efi' ]]; then
	EFI=1
else
	EFI=0
	echo 'WARNING: no /usr/lib/grub/x86_64-efi dir. Skipping GRUB x86_64 UEFI support'
fi
if [[ -d '/usr/lib/grub/i386-efi' ]]; then
	EFI32=1
else
	EFI32=0
	echo 'WARNING: no /usr/lib/grub/i386-efi dir. Skipping GRUB IA32 UEFI support'
fi

if (( BIOS == 0 && EFI == 0 && EFI32 == 0 )); then
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
if (( EFI32 == 1 )); then
	read -r -n 1 -s -p 'Install GRUB for IA32 UEFI? (Y/n) ' PROCEED
	if [[ "$PROCEED" == 'n' ]]; then
		EFI32=0
		echo 'n'
	else
		echo 'Y'
	fi
fi

if (( BIOS == 0 && EFI == 0 && EFI32 == 0 )); then
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
	if ! (set -x; ${PRIVILEGE_ELEVATION} "${GRUB2_INSTALL}" "${GRUB_TARGET[@]}" "${GRUB_COMMON_ARGS[@]}" -- "${USBDEV}"); then
		echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
		exit 1
	fi
fi
if (( EFI == 1 )); then
	GRUB_TARGET=('--target=x86_64-efi' "--efi-directory=${USBMNT}" '--removable')
	if ! (set -x; ${PRIVILEGE_ELEVATION} "${GRUB2_INSTALL}" "${GRUB_TARGET[@]}" "${GRUB_COMMON_ARGS[@]}"); then
		echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
		exit 1
	fi
fi
if (( EFI32 == 1 )); then
	GRUB_TARGET=('--target=i386-efi' "--efi-directory=${USBMNT}" '--removable')
	if ! (set -x; ${PRIVILEGE_ELEVATION} "${GRUB2_INSTALL}" "${GRUB_TARGET[@]}" "${GRUB_COMMON_ARGS[@]}"); then
		echo "ERROR: ${GRUB2_INSTALL} returned with an error exit status."
		exit 1
	fi
	# GRUB Bug: Remove unneded file, ${USBMNT}/EFI/BOOT/BOOTIA32.EFI provides the bootloader
	[[ -e "${USBMNT}/EFI/BOOT/grub.efi" ]] && ${PRIVILEGE_ELEVATION} rm -- "${USBMNT}/EFI/BOOT/grub.efi"
fi


# Copy GRUB2 configuration
if ! (set -x; rsync -rpt --delete --exclude='i386-pc' --exclude='x86_64-efi' --exclude='i386-efi' --exclude='fonts' --exclude='icons/originals' -- "${GRUB2_CONF}/" "${USBMNT}/boot/${GRUB2_DIR}"); then
	echo 'ERROR: the rsync copy returned with an error exit status.'
	exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d "${USBMNT}/boot/iso" ]] || mkdir -- "${USBMNT}/boot/iso"
echo 'GLIM installed! Time to populate the boot/iso directory.'
