#!/bin/bash
#
# BASH. It's what I know best, sorry.
#

source inc/utils

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
    echo "WARNING: no /usr/lib/grub/x86_64-efi dir (grub2-efi-x64-modules rpm missing?)"
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
echo "Running rsync -rpt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts --exclude=icons/originals ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR} ..."
${CMD_PREFIX} rsync -rpt --delete --exclude=i386-pc --exclude=x86_64-efi --exclude=fonts --exclude=icons/originals ${GRUB2_CONF}/ ${USBMNT}/boot/${GRUB2_DIR}
if [[ $? -ne 0 ]]; then
  echo "ERROR: the rsync copy returned with an error exit status."
  exit 1
fi

# Be nice and pre-create the directory, and mention it
[[ -d ${USBMNT}/boot/iso ]] || ${CMD_PREFIX} mkdir ${USBMNT}/boot/iso
echo "GLIM installed! Time to populate the boot/iso directory."

