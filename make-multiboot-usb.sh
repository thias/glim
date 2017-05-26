#!/bin/bash
# make-multiboot-usb.sh
# https://github.com/thias/glim
# Create a bootable USB drive allowing to boot multiple ISO images
# license: Public domain
set -e # abort on error
##############################
# Configuration

export USBDEV='/dev/sde'       #target USB drive
export USBMNT='/mnt'           #where to mount the USB drive (no trailing slash)
export WINDOWS7_INSTALLER="no" #set to yes to include Windows 7 installer
export WINDOWS7_ISO_FILE="/path/to/windows-7-installer.iso" #path to the windows 7 ISO image

##############################

export BLKDEV=$(echo "$USBDEV" | sed -e 's|^/dev/||g' )
lsblk -o NAME,VENDOR,REV,MODEL,SIZE,SERIAL | grep "$BLKDEV" | column -t
read -r -p "You've selected the device $USBDEV. Are you sure? Y/n " answer
if [ ! "$answer" == "Y" ]; then echo "Aborting."; exit 1; fi

#TODO [enh] make the user retype the device name and abort if different

#Unlock sudo credentials
sudo -v

echo "Creating a single primary MSDOS partition on USB memory, using all available space..."
echo -e "o\nn\np\n1\n\n\nw\n" | sudo fdisk "$USBDEV" > /dev/null

echo "Formatting main partition as FAT32..."
sudo mkfs.vfat -F 32 -n MULTIBOOT "${USBDEV}1"
sync

echo "Mount the newly created partition on $USBMNT..."
sudo mount "${USBDEV}1" ${USBMNT:-/mnt}

#TODO [enh] calculate free space on partition, compare with total iso directory size, warn/abort if not enough disk space

echo "Installing GRUB2 to the USB device's MBR, and onto the new filesystem..."
#TODO [enh]  --no-floppy option?
#TODO [enh]  --removable option?
sudo grub-install --boot-directory=${USBMNT:-/mnt}/boot "$USBDEV"

echo "Copying grub configuration..."
sudo rsync --recursive --links --times -D grub2/ ${USBMNT:-/mnt}/boot/grub

echo "Copying downloaded ISO images to USB memory..."
sudo cp -rv iso ${USBMNT:-/mnt}/boot/
#TODO [enh] add progress bar (pv)
sync

if [ "$WINDOWS7_INSTALLER" = "yes" ]; then
  echo "Copying contents of Windows 7 installer ISO to USB memory..."
  if [ ! -d /mnt2 ]; then sudo mkdir /mnt2; fi
  sudo mount "$WINDOWS7_ISO_FILE" /mnt2;
  sudo rsync --recursive --times --progress -D /mnt2/ ${USBMNT:-/mnt}
  sync
  sudo umount /mnt2/
  sudo rmdir /mnt2
  USBUUID=$(lsblk -n -o UUID "$USBDEV" |tail -n1)
  sudo sed -i "s/SAMPLEUUID/$USBUUID/g" ${USBMNT:-/mnt}/boot/grub/inc-windows.cfg
fi

echo "Unmount USB drive"
sudo umount ${USBMNT:-/mnt}

echo "Done"

##############################

#TODO [enh] create efi partition
#TODO [enh] update grub with efi: grub-install --boot-directory=/mnt/boot --efi-directory=/mnt/target/EFI/BOOT /dev/sde
#TODO detect if grub installation directory is /boot/grub/ (debian/ubuntu) or /boot/grub2 (others?)
#DOC Test resulting image in Virtualbox: sudo chown my_user:my_user "${USBDEV}"; vboxmanage internalcommands createrawvmdk -filename vmdk.vmdk -rawdisk "${USBDEV}" # then load vmdk.vmdk as storage device for your VM
#DOC Remove windows 7 installer files from USB drive: cd "$USBMNT"; rm -r upgrade/ support/ sources/ efi/ setup.exe  bootmgr.efi bootmgr autorun.inf boot/fonts/ boot/en-us/ boot/memtest.exe boot/memtest.efi boot/etfsboot.com boot/bootsect.exe boot/bootfix.bin boot/boot.sdi boot/bcd
