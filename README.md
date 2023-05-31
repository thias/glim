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

[//]: # (distro-list-start)

    almalinux
    antix
    arch
    artix
    bodhi
    centos
    clonezilla
    debian
    elementary
    fedora
    gentoo
    gparted
    grml
    ipxe
    kali
    kubuntu
    linuxmint
    manjaro
    memtest
    netrunner
    openbsd
    peppermint
    porteus
    rhel
    rockylinux
    supergrub2disk
    systemrescue
    tails
    ubuntu
    void
    xubuntu

[//]: # (distro-list-end)

Any unpopulated directory will have the matching boot menu entry automatically
disabled, so to skip any distribution, just don't copy any files into it.

Download the right ISO image(s) to the matching directory. If you require
boot parameter tweaks, edit the appropriate `boot/grub2/inc-*.cfg` file.

Items order in the menu
------------

Menu items for a distro are ordered by modification time of the iso files
starting from the most recent ones. If some iso files have the same mtime, their
menu items are ordered alphabetically.

Here is a generic idea how to keep it nicely ordered when you have multiple
releases of some distro:

- touch your **release** iso files with the release date
- touch your **point release** iso files with the original release date plus a
  day per point. This is a way to ensure point releases never pop above the next
  release like Debian 10.13.0 (released 10 Sep 2022) would still be below Debian
  11.0.0 (released 14 August 2021)
- in case there are multiple flavours of some iso but the version is the same,
  touch all of them with the same date for the whole group to be ordered
  alphabetically

Sample ordered menu:

|                                    | iso mtime               |
|------------------------------------|-------------------------|
| Debian Live 12.0.0 amd64 standard  | 10 June 2023            |
| Debian Live 11.7.0 amd64 gnome     | 14 August 2021 + 7 days |
| Debian Live 11.7.0 amd64 kde       | 14 August 2021 + 7 days |
| Debian Live 11.7.0 amd64 standard  | 14 August 2021 + 7 days |
| Debian Live 11.0.0 amd64 gnome     | 14 August 2021          |
| Debian Live 11.0.0 amd64 kde       | 14 August 2021          |
| Debian Live 11.0.0 amd64 standard  | 14 August 2021          |
| Debian Live 10.13.0 amd64 standard | 6 July 2019 + 13 days   |
| Debian Live 9.13.0 amd64 standard  | 17 June 2017 + 13 days  |

Special Cases
-------------

### iPXE

The `.iso` files don't work when booting using EFI, you simply need to use
`.efi` files instead.

### LibreELEC

LibreELEC isn't provided as ISO images, nor is it able to find the `KERNEL` and
`SYSTEM` files it needs anywhere else than at the root of a filesystem.
But it's useful to enable booting the installer by just copying both
files to the root of the USB memory stick.
Live booting is also supported, and the first launch will create a 512MB file
as /STORAGE.

### Memtest86+

The `.iso` file doesn't work. Use either the `.bin` or the `.efi` depending on
the boot mode used.

### Ubuntu

Recent Ubuntu desktop iso images bundle multiple versions on the Nvidia
driver. With that, the images are over 4GB, the FAT32 max file size. For example
`ubuntu-20.04.6-desktop-amd64.iso` is 4.1GB, `ubuntu-22.04.2-desktop-amd64.iso`
is 4.6GB. The driver is not required in a live system, it can be removed to make
an image fit into 4GB. For example, with 22.04.2 image in the current dir:

```
mkdir slim
iso=ubuntu-22.04.2-desktop-amd64.iso

xorriso -indev "$iso" -outdev slim/"$iso" \
    -boot_image any replay -rm_r /pool/restricted/{l,n} --
```

Now you can copy `slim/ubuntu-22.04.2-desktop-amd64.iso` to your FAT32 formatted
GLIM USB stick.

Some Ubuntu flavours also bundle the Nvidia driver (like Kubuntu), some don't
(like Xubuntu). The same trick can be used with the former.


Testing
-------

With KVM it should "just work". The `/dev/sdx` device should be configured as
an IDE or SATA disk (for some reason, as USB disk didn't work for me on Fedora
17), that way you can easily and quickly test changes.
Make sure you unmount the disk from the host OS before you start the KVM
virtual machine that uses it.
For UEFI testing, you'll need to use one of the `/usr/share/edk2/ovmf/*.fd`
firmwares.


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
or simply outdated, please feel free to contribute! What you will need is to
create a GitHub pull request which includes :
 * All changes properly and fully tested.
 * New entries added similarly to the existing ones :
   * In alphabetical order.
   * With all possible variants supported (i.e. not just the one spin you want).
 * An original icon of high quality, and a shrunk 24x24 png version. Using
   `convert -size 24x24 -background 'rgba(0,0,0,0)' original.svg small.png`
   may work.
 * An updated supported directories list in this README file.


---
Copyleft 2012-2023 Matthias Saou http://matthias.saou.eu/

All configuration files included are public domain. Do what you want with them.
The invader logo was made by me, so unless the exact shape is covered by
copyright somewhere, do what you want with it.
The background is "Wallpaper grey" © 2008 payalnic (DeviantArt)
The `ascii.pf2` font comes from GRUB, which is GPLv3+ licensed. For more
details as well as the source code, see http://www.gnu.org/software/grub/

