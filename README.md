GRUB2 Live ISO Multiboot
========================

http://github.com/thias/glim | http://glee.thias.es/GLIM

Overview
--------

GLIM is a set of grub configuration files to turn a simple VFAT formatted USB
memory stick with many GNU/Linux distribution ISO images into a neat device
from which many different Live environments can be used.

Advantages over extracting files or using special Live USB creation tools :

 * A single USB memory can hold all Live environments (the limit is its size)
 * ISO images stay available to burn real CDs or DVDs

Disadvantages :

 * There is no persistence overlay for distributions which normally support it
 * Setting up isn't as easy as a simple cat from the ISO image to a block device

My experience has been that the safest filesystem to use is FAT32
(surprisingly!), though it will mean that ISO images greater than 4GB won't be
supported. Other filesystems supported by GRUB2 also work, such as ext3/ext4
and even NTFS, but the boot of the distributions must also support it, which
isn't the case for many with NTFS.

Screenshots
-----------

![Main Menu](https://github.com/thias/glim/raw/master/screenshots/GLIM-2.4-shot1.png)
![Ubuntu Submenu](https://github.com/thias/glim/raw/master/screenshots/GLIM-2.4-shot2.png)

Installation
------------

### Automated installation

The installation script attempts to install the bootloader and multiboot configuration to
a chosen USB drive, in a safe and automated manner. If you want to install the configuration
manually, please skip to the next section.

 * Insert the USB memory and find it's block device file using `lsblk, dmesg, gparted...`.
 * Clone the repository `git clone https://github.com/nodiscc/glim` or [download](https://github.com/nodiscc/glim/archive/master.zip) the ZIP archive
 * Edit the configuration values in `make-multiboot-usb.sh`:

```
export USBDEV='/dev/sde'       #target USB drive
export USBMNT='/mnt'           #where to mount the USB drive (no trailing slash)
export WINDOWS7_INSTALLER="no" #set to yes to include Windows 7 installer
export WINDOWS7_ISO_FILE="/path/to/windows-7-installer.iso" #path to the windows 7 ISO image
```
 * Copy your iso image files to the appropriate subdirectory in `iso/` (see list of supported subdirectories below).
 * Inside the base directory, run `./make-multiboot-usb.sh` and follow the instructions.
 * Wait for the script to complete without error, then remove the USB drive. It is ready to use.

### Manual installation


Setting up GRUB requires you to be root, while the rest doesn't.

Set the `USBMNT` variable so that copy/pasting examples will work
(replace `/mnt` and `sdb` with the appropriate values) :

    export USBMNT=/mnt
    export USBDEV=sdb

Preliminary steps (usually already completed on a newly purchased USB memory) :

 * Create a single primary MSDOS partition on your USB memory.
 * Format that partition as FAT32

Next, install GRUB2 to the USB device's MBR, and onto the new filesystem :

    grub2-install --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

On Debian/Ubuntu, replace `grub2-install` with `grub-install`:

    grub-install --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

If you get the following message :

    source_dir doesn't exist. Please specify --target or --directory

Just find your grub2 directory and specify it as asked. Example :

    grub2-install --directory=/usr/lib/grub/i386-pc --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

Use --force if your partitions start at 63 instead of more, such as 2048,
though you might want to repartition and reformat.

Next, copy over all the required files (`grub.cfg` and files it includes, theme, font) :

    rsync -avP grub2/ ${USBMNT:-/mnt}/boot/grub2

On Debian/Ubuntu, the correct destination directory is `${USBMNT:-/mnt}/boot/grub`:

    rsync -avP grub2/ ${USBMNT:-/mnt}/boot/grub

If you want to avoid keeping unused translations, themes, etc, use this instead :

    rsync -avP --delete --exclude=i386-pc grub2/ ${USBMNT:-/mnt}/boot/grub2

Now create and populate the `${USBMNT}/boot/iso/` sub-directories you want.
Example :

    mkdir ${USBMNT:-/mnt}/boot/iso
    mkdir ${USBMNT:-/mnt}/boot/iso/ubuntu

The supported sub-directories (in alphabetical order) are :

    antix
    arch
    bodhi
    debian
    fedora
    gparted
    grml
    ipxe
    kali
    knoppix
    linuxmint
    rhel
    sysrescd
    ubuntu
    xubuntu

Any missing sub-directory will have the matching boot menu entry automatically
disabled, so to skip any distribution, just don't create its directory.

Download the right ISO images to the newly created directory. If you require
different versions, or just part of a distribution, edit the appropriate
`inc-*.cfg file`.

Note that on 32bit computers, all 64bit entries will be automatically hidden.

Special Cases
-------------

### Red Hat Enterprise Linux

RHEL isn't "live" as such. And in order for the install to work, you need to
also copy the "images" directory from the DVD next to the DVD ISO, and keep
only "install.img" and "product.img".

### OpenELEC

OpenELEC isn't provided as ISO images, not is it able to find the `KERNEL` and
`SYSTEM` files it needs anywhere else than at the root of a filesystem.
But it's useful to enable booting the OpenELEC installer by just copying both
files from any single version (ION, Intel, Fusion, Generic, etc.) to the root
of the USB memory stick, instead of first having to create a new separate USB
memory just to run the installer.
As of OpenELEC 3.0, Live booting is also supported, but :
 * The FAT filesystem's label must be 'GLIM'
 * The first launch will create a 512MB file as /STORAGE
This can be tweaked as needed by editing inc-openelec.cfg.

### antiX

antiX kernel can't boot from an ISO image (it lacks options for iso file
handling). The ISO file content must be extracted to the directory
iso/antix/<ISO file name w/o extension>/ for GLIM to be able to launch it.

Note that antiX iso files contain a symlink, which is NOT supported by FAT
file systems. Just skip it and it will work fine, but ensure that every
other file is copied (the error caused by the symlink may stop extraction
prematurely when extracting files directly to the USB memory stick).

### Windows 7 installer

Booting the installer ISO directly is not supported. To boot a windows 7 
installer, just mount the original installer ISO image and copy all the 
files directly to the root of the USB memory (or use the installation script).

It is strongly advised to unplug all drives except the target drive before 
installing Windows. Installing windows on the same drive as another OS is 
currently NOT supported. It leads to inconsistencies in Windows boot 
mechanisms even when the installation appears successful.
(See https://github.com/thias/glim/pull/13/commits/f1ea6f203017c307e1da91eead916b146cf27fc0)
Windows installation may also overwrite already existing bootloaders.

Testing
-------

With KVM it should "just work". The `/dev/sdx` device should be configured as
an IDE or SATA disk (for some reason, as USB disk didn't work for me on Fedora
17), that way you can easily and quickly test changes.
Make sure you unmount the disk from the host OS before you start the KVM
virtual machine that uses it.

Troubleshooting
---------------

If you have any problem to boot, for instance stuck at the GRUB prompt before
the menu, try running grub-install again.  
If you have other exotic GRUB errors, such as garbage text read instead of the
configuration directives, try re-formatting your USB memory. I've seen weird
things happen...  

---
Copyleft 2012-2013 Matthias Saou http://matthias.saou.eu/

All configuration files included are public domain. Do what you want with them.
The invader logo was made by me, so unless the exact shape is covered by
copyright somewhere, do what you want with it.
The terminal_box_*.png files are CC-BY-SA-3.0 and come from the GRUB2 starfield
theme by Daniel Tschudi.
The ascii.pf2 font comes from GRUB, which is GPLv3+ licensed. For more details 
as well as the source code, see http://www.gnu.org/software/grub/

