GRUB2 Live ISO Multiboot
========================

https://github.com/thias/glim | http://glee.thias.es/GLIM


Overview
--------

GLIM is a set of grub configuration files to turn a simple VFAT formatted USB
memory stick with many GNU/Linux distribution ISO images into a neat device
from which many different Live environments can be used.

Advantages over extracting files or using special Live USB creation tools :

 * A single USB memory can hold all Live environments (the limit is its size)
 * ISO images stay available to burn real CDs or DVDs
 * ISO images are quick to manipulate (vs. hundreds+ files)

Disadvantages :

 * There is no persistence overlay for distributions which normally support it
 * Setting up isn't as easy as a simple cat from the ISO image to a block device

My experience has been that the safest filesystem to use is FAT32
(surprisingly!), though it will mean that ISO images greater than 4GB won't be
supported. Other filesystems supported by GRUB2 also work, such as ext3/ext4
and even NTFS, but the boot of the distributions must also support it, which
isn't the case for many with NTFS, for instance. So FAT32 stays the safe bet.


Screenshots
-----------

![Main Menu](https://github.com/thias/glim/raw/master/screenshots/GLIM-3.0-shot1.png)
![Ubuntu Submenu](https://github.com/thias/glim/raw/master/screenshots/GLIM-3.0-shot2.png)


Installation
------------

Once you have your USB memory with a single partition formatted as FAT32 with
the filesystem label 'GLIM', just run (as a normal user) :

    ./glim.sh

Once finished, you may change the filesystem label to anything you like.

The supported `boot/iso/` sub-directories (in alphabetical order) are :

    almalinux
    antergos
    antix
    arch
    bodhi
    centos
    clonezilla
    debian
    elementary
    fedora
    gparted
    grml
    ipxe
    kali
    linuxmint
    manjaro
    netrunner
    peppermint
    porteus
    rhel
    rockylinux
    sabayon
    supergrub2disk
    sysrescd
    tails
    ubuntu
    void
    xubuntu

Any missing sub-directory will have the matching boot menu entry automatically
disabled, so to skip any distribution, just don't create the directory.

Download the right ISO images to the newly created directory. If you require
different versions, or just part of a distribution, edit the appropriate
`boot/grub2/inc-*.cfg` file.

Note that on 32bit computers, all 64bit entries will be automatically hidden.


Special Cases
-------------

### LibreELEC

LibreELEC isn't provided as ISO images, nor is it able to find the `KERNEL` and
`SYSTEM` files it needs anywhere else than at the root of a filesystem.
But it's useful to enable booting the installer by just copying both
files to the root of the USB memory stick.
Live booting is also supported, and the first launch will create a 512MB file
as /STORAGE.


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
the menu, try re-installing.
If you have other exotic GRUB errors, such as garbage text read instead of the
configuration directives, try re-formatting your USB memory from scratch.
I've seen weird things happen...


Contributing
------------

If you find GLIM useful but the configuration of the OS you require is missing
or simply outdated, please feel free to contribute! What you will need is
create a GitHub pull request which includes :
 * All changes properly and fully tested.
 * New entries added similarly to the existing ones :
   * In alphabetical order.
   * With all possible relevant variants (i.e. not just the one spin you want).
 * An original icon of high quality, and a shrunk 24x24 px version.
 * An updated supported directories list in this README file.


---
Copyleft 2012-2017 Matthias Saou http://matthias.saou.eu/

All configuration files included are public domain. Do what you want with them.
The invader logo was made by me, so unless the exact shape is covered by
copyright somewhere, do what you want with it.
The background is "Wallpaper grey" © 2008 payalnic (DeviantArt)
The ascii.pf2 font comes from GRUB, which is GPLv3+ licensed. For more details 
as well as the source code, see http://www.gnu.org/software/grub/

