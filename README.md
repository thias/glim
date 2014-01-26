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

Setting up GRUB require you to be root, while the rest doesn't.

Set the `USBMNT` variable so that copy/pasting examples will work
(replace `/mnt` and `sdb` with the appropriate values) :

    export USBMNT=/mnt
    export USBDEV=sdb

Preliminary steps (usually already completed on a newly purchased USB memory) :

 * Create a single primary MSDOS partition on your USB memory.
 * Format that partition as FAT32

Next, install GRUB2 to the USB device's MBR, and onto the new filesystem :

    grub2-install --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

 -or- (Ubuntu, for instance)

    grub-install --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

If you get the following message :

    source_dir doesn't exist. Please specify --target or --directory

Just find your grub2 directory and specify it as asked. Example :

    grub2-install --directory=/usr/lib/grub/i386-pc --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

Use --force if your partitions start at 63 instead of more, such as 2048,
though you might want to repartition and reformat.

Next, copy over all the required files (`grub.cfg` and files it includes, theme, font) :

    rsync -avP grub2/ ${USBMNT:-/mnt}/boot/grub2

If you want to avoid keeping unused translations, themes, etc, use this instead :

    rsync -avP --delete --exclude=i386-pc grub2/ ${USBMNT:-/mnt}/boot/grub2

Now create and populate the `${USBMNT}/boot/iso/` sub-directories you want.
Example :

    mkdir ${USBMNT:-/mnt}/boot/iso
    mkdir ${USBMNT:-/mnt}/boot/iso/ubuntu

The supported sub-directories (in alphabetical order) are :

    arch
    debian
    fedora
    gparted
    grml
    ipxe
    knoppix
    linuxmint
    rhel
    sysrescd
    ubuntu

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

### Debian DVD Installer

Like RHEL, the Debian DVD isn't a live distro, so special care is needed. 
You need to download the hd-media installer from debian's archive: 
[ftp://ftp.debian.org/debian/dists/wheezy/main/installer-amd64/current/images/] 
and place it in the /boot/iso/debian directory, renaming it for the version and
architecture, such as /boot/iso/debian/hd-media-7.0.3-amd64/...

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

