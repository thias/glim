GRUB2 Live ISO Multiboot
========================

https://github.com/thias/glim | https://glee.thias.es/GLIM


Overview
--------

GLIM is a set of grub configuration files to turn a simple VFAT formatted USB
memory stick with many GNU/Linux distribution ISO images into a neat device
from which many different live environments can be used.

Advantages over extracting files or using special live USB creation tools:

 * A single USB memory can hold all Live environments (the limit is its size)
 * ISO images stay available to burn real CDs or DVDs
 * ISO images are quick to manipulate (vs. hundreds+ files)

Disadvantages:

 * There is no persistence overlay for distributions which normally support it
 * Setting up isn't as easy as a simple cat from the ISO image to a block device

The safest filesystem to use is FAT32 (surprisingly!), though it means no 4 GB+ ISOs.
Other filesystems supported by GRUB 2 also work, such as ext3/ext4,
NTFS and exFAT, but the boot of the distributions must also support it,
so no Fedora, but Ubuntu support on NTFS, and the opposite with exFAT.


Screenshots
-----------

![Main Menu](https://github.com/thias/glim/raw/master/screenshots/GLIM-3.0-shot1.png)
![Ubuntu Submenu](https://github.com/thias/glim/raw/master/screenshots/GLIM-3.0-shot2.png)


Installation
------------

Once your USB memory has a single partition formatted as FAT32 with
the filesystem label 'GLIM', mount it, clone this Git repository and
just run (as a normal user):

    ./glim.sh

Once finished, you may change the filesystem label to anything you like.

The supported `boot/iso/` sub-directories (in A–Z order) are:

[//]: # (distro-list-start)

* [`almalinux`](https://almalinux.org/) - _Live Media_ only
* [`antix`](https://antixlinux.com/)
* [`arch`](https://archlinux.org/)
* [`artix`](https://artixlinux.org/)
* [`bodhi`](https://www.bodhilinux.com/)
* [`calculate`](https://wiki.calculate-linux.org/desktop)
* ~~[`centos`](https://www.centos.org/)~~ - _Live_ was discontinued
* [`clonezilla`](https://clonezilla.org/)
* [`debian`](https://www.debian.org/CD/live/) - _live_ & `mini.iso`
* [`elementary`](https://elementary.io/)
* [`fedora`](https://fedoraproject.org/)
* [`finnix`](https://www.finnix.org/)
* [`gentoo`](https://www.gentoo.org/)
* [`gparted`](https://gparted.org/)
* [`grml`](https://grml.org/)
* [`ipxe`](https://ipxe.org/)
* [`kali`](https://www.kali.org/)
* [`kubuntu`](https://kubuntu.org/)
* [`libreelec`](https://libreelec.tv/)
* [`linuxmint`](https://linuxmint.com/)
* [`lubuntu`](https://lubuntu.me/)
* [`manjaro`](https://manjaro.org/)
* [`memtest`](https://memtest.org/) - _Binary Files (.bin/.efi)_
* [`netrunner`](https://www.netrunner.com/)
* [`openbsd`](https://www.openbsd.org/)
* [`opensuse`](https://www.opensuse.org/) - _Tumbleweed_
* [`peppermint`](https://peppermintos.com/)
* [`porteus`](http://www.porteus.org/)
* [`rhel`](https://www.redhat.com/rhel) - installation only
* [`rockylinux`](https://rockylinux.org/)
* [`slitaz`](https://slitaz.org/)
* [`supergrub2disk`](https://www.supergrubdisk.org/)
* [`systemrescue`](https://www.system-rescue.org/)
* [`tails`](https://tails.net/)
* [`ubuntu`](https://ubuntu.com/)
* [`void`](https://voidlinux.org/)
* [`xubuntu`](https://xubuntu.org/)

[//]: # (distro-list-end)

Unpopulated directories turns off the matching boot menu entry,
so skip any distribution by not copying any files into it.

Download the right ISO image(s) to the matching directory.
If you require boot parameter tweaks, edit the appropriate
`boot/grub2/inc-*.cfg` file.

Item order in the menu
----------------------

Distros as menu items are ordered by the modification time of their ISO files,
starting with the most recent. If some ISO files have the same mtime,
their menu items are ordered A–Z.

Here is a generic idea of how to keep it nicely ordered with multiple
releases of some distro:

- `touch` your **release** ISO files with the release date
- `touch` your **point release** ISO files with the original release date, plus a
  day per point. This is a way to ensure point releases never pop above the next
  release like Debian 10.13.0 (released 10 Sep 2022) would still be below Debian
  11.0.0 (released 14 Aug 2021)
- In case there are multiple flavours of some ISO, but the version is the same
 `touch` all of them with the same date to order the whole group A–Z
  
Sample-ordered menu:

|                                    | ISO mtime               |
|------------------------------------|-------------------------|
| Debian Live 12.0.0 amd64 standard  | 10 June 2023            |
| Debian Live 11.7.0 amd64 GNOME     | 14 August 2021 + 7 days |
| Debian Live 11.7.0 amd64 KDE       | 14 August 2021 + 7 days |
| Debian Live 11.7.0 amd64 standard  | 14 August 2021 + 7 days |
| Debian Live 11.0.0 amd64 GNOME     | 14 August 2021          |
| Debian Live 11.0.0 amd64 KDE       | 14 August 2021          |
| Debian Live 11.0.0 amd64 standard  | 14 August 2021          |
| Debian Live 10.13.0 amd64 standard | 6 July 2019 + 13 days   |
| Debian Live 9.13.0 amd64 standard  | 17 June 2017 + 13 days  |

Special Cases
-------------

### iPXE

The `.iso` files don't work when booting using EFI, you simply need to use
`.efi` files instead.

### LibreELEC

LibreELEC provide no ISO images, nor is able to find the `KERNEL` and
`SYSTEM` files it needs, other than if placed at the root of a filesystem.
But it's useful to enable booting the installer by just copying both
files to the root of the USB memory stick.
Live booting is also supported, and the first launch will create a 512 MB
file as /STORAGE.

### Memtest86+

The `.iso` file doesn't work.
Use either the `.bin` or the `.efi` depending on the boot mode used.

### Ubuntu

Recent Ubuntu desktop ISO images bundle multiple versions on the Nvidia
driver. With that, the images are 4 GB+, the max FAT32 file size. For example
`ubuntu-20.04.6-desktop-amd64.iso` is 4.1 GB, `ubuntu-22.04.2-desktop-amd64.iso` is 4.6 GB.
The driver is not required in a live system. Removing it can make an image fit into 4 GB.
For example, with 22.04.2 image in the current dir:

```
mkdir slim
iso=ubuntu-22.04.2-desktop-amd64.iso

xorriso -indev "$iso" -outdev slim/"$iso" \
    -boot_image any replay -rm_r /pool/restricted/{l,n} --
```

Now you can copy `slim/ubuntu-22.04.2-desktop-amd64.iso` to your FAT32-formatted
GLIM USB stick.

Some Ubuntus bundle the Nvidia driver (like Kubuntu), some don't (like Xubuntu).
The same trick can be used with the former.


Testing
-------

With KVM it should "just work". The `/dev/sdx` device should be configured as
an IDE or SATA disk (for some reason, as USB disk doesn't work on Fedora
17), that way you can easily and quickly test changes.
Ensure you unmount the disk from the host OS before starting the KVM
virtual machine that uses it.
For UEFI testing, you need to use one of the `/usr/share/edk2/ovmf/*.fd`
firmwares.


Troubleshooting
---------------

If you have any problem booting, for instance being stuck at the GRUB prompt before
the menu, try re-installing.
If you have other exotic GRUB errors, such as garbage text read instead of the
configuration directives, try re-formatting your USB memory from scratch
and/or persist in your belief that you are of sound mind should strangeness
increase or continue.

Contributing
------------

If you find GLIM useful, but the configuration of the OS you picked is missing
or simply outdated, please contribute! 
Create a GitHub pull request including:
 * All changes properly and fully tested.
 * New entries added similarly to the existing ones:
   * In A–Z order.
   * With all possible variants supported (i.e. not just the one spin you want).
 * An original icon of high quality, and a shrunk 24x24 PNG version. Using
   `convert -size 24x24 -background 'rgba(0,0,0,0)' original.svg small.png`
   may work.
 * An updated supported directories list in this README file.


---
Copyleft 🄯 2012–2023 Matthias Saou https://matthias.saou.eu/

All configuration files included are public domain.
The invader logo was made by me, so unless covered by
copyright somewhere, do what you want with it.
The background is "Wallpaper grey" © 2008 payalnic (DeviantArt)
The `ascii.pf2` font comes from GRUB, which is GPLv3+ licensed.
More details and source code on https://www.gnu.org/software/grub/
