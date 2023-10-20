GLIM — GRUB2 Live ISO Multiboot
===============================

https://github.com/thias/glim | https://glee.thias.es/GLIM


Overview
--------

_Boot many differetn GNU/Linux live environments by putting their ISOs onto VFAT-formatted USB memory_.

 * A single USB memory can hold all live environments (the limit is its size).
 * ISOs stay available to burn real CDs or DVDs.
 * One file per distro is easy to handle (vs. 100+ files in the images).
 * No files to extract.
 * No special live USB-creation tools.

Disadvantages:

 * Each distro needs support as specific GRUB configuration files in GLIM. \
 * No persistent files for distributions which normally support it, \
   so putting aside space on the installation media for files that \
   survive a reboot (in for example Ubuntu) will not work.
 * Setting up isn't as easy as a simple `cat` from the ISO image to a block device.

FAT32 is the safest filesystem, though it means no 4 GB+ ISOs. \
Ext3/ext4 and other filesystems supported by GRUB 2 also work. \
\*exFAT means no Ubuntu, but Fedora works. \
\*NTFS means no Fedora, but Ubuntu works.

Screenshots
-----------

![Main Menu](https://github.com/thias/glim/raw/master/screenshots/GLIM-3.0-shot1.png)
![Ubuntu Submenu](https://github.com/thias/glim/raw/master/screenshots/GLIM-3.0-shot2.png)

Installation
------------

Once your USB memory has a single partition formatted as FAT32 with \
the filesystem label 'GLIM', mount it, clone this Git repository and \
just run (as a normal user):

    ./glim.sh

Once finished, optionally change the filesystem label.

The supported `boot/iso/` sub-directories (in A–Z order):
[//]: # (distro-list-start)

* [`almalinux`](https://almalinux.org/) - _Live Media only_
* [`antix`](https://antixlinux.com/)
* [`arch`](https://archlinux.org/)
* [`artix`](https://artixlinux.org/)
* [`bodhi`](https://www.bodhilinux.com/)
* [`calculate`](https://wiki.calculate-linux.org/desktop)
* ~~[`centos`](https://www.centos.org/)~~ - _Live was discontinued_
* [`clonezilla`](https://clonezilla.org/)
* [`debian`](https://www.debian.org/CD/live/) - _live & `mini.iso`_
* [`elementary`](https://elementary.io/)
* [`fedora`](https://fedoraproject.org/)
* [`finnix`](https://www.finnix.org/)
* [`gentoo`](https://www.gentoo.org/)
* [`gparted`](https://gparted.org/)
* [`grml`](https://grml.org/)
* [`ipxe`](https://ipxe.org/) - _.iso or .efi_
* [`kali`](https://www.kali.org/)
* [`kubuntu`](https://kubuntu.org/)
* ~~[`libreelec`](https://libreelec.tv/)~~ - currently broken
* [`linuxmint`](https://linuxmint.com/)
* [`lubuntu`](https://lubuntu.me/)
* [`manjaro`](https://manjaro.org/)
* [`memtest`](https://memtest.org/) - _Only .bin/.efi, not .iso_
* [`mxlinux`](https://mxlinux.org/)
* [`netrunner`](https://www.netrunner.com/)
* [`openbsd`](https://www.openbsd.org/)
* [`opensuse`](https://www.opensuse.org/) - _Live from Alternative Downloads only_
* [`peppermint`](https://peppermintos.com/)
* [`popos`](https://pop.system76.com/)
* [`porteus`](http://www.porteus.org/)
* [`rhel`](https://www.redhat.com/rhel) - _Installation only_
* [`rockylinux`](https://rockylinux.org/)
* [`slitaz`](https://slitaz.org/)
* [`supergrub2disk`](https://www.supergrubdisk.org/)
* [`systemrescue`](https://www.system-rescue.org/)
* [`tails`](https://tails.net/)
* [`ubuntubudgie`](https://ubuntubudgie.org/)
* [`ubuntu`](https://ubuntu.com/)
* [`void`](https://voidlinux.org/)
* [`xubuntu`](https://xubuntu.org/)
* [`zorinos`](https://zorin.com/os/)

[//]: # (distro-list-end)

Boot-menu entries are not shown when their respective folders are empty, \
so skip any distribution by not copying any files into it.

Download the ISO image(s) to the respective matching directory. \
Optionally, add boot parameter tweaks by editing the respective
`boot/grub2/inc-*.cfg` file.

Item order in the menu
----------------------

More recently edited ISO-files are listed first, and otherwise A–Z.

Kep it nicely ordered if you have multiple releases of a distro:

- Order by release date: `touch` your **release** ISO files with the release date.
- Prevent point releases from being listed above their successors:
  `touch` the **point release** (for example Debian 10.13.0 (released 10 Sep 2022)
  ISO files with the original release date, plus a day per point
  to keep it below newer Debian releases (like 11.0.0 (released 14 Aug 2021).
- Order anything A–Z: `touch` many ISOs with the same date to list them alphabetically.
  Useful for multiple flavours of one version of an ISO .
 
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

Use `.efi` files, as`.iso` files don't work when booting in EFI mode.

### Memtest86+

Use either the `.bin` or the `.efi` depending on the boot mode used, \
as the The `.iso` file doesn't work.

### Ubuntu

Removing the multiple Nvidia driver versions in recent Ubuntu desktop ISOs \
can help fit images into the 4 GiB allowed on FAT32 file systems.
`ubuntu-20.04.6-desktop-amd64.iso` is 4.1 GB, `ubuntu-22.04.2-desktop-amd64.iso` is 4.6 GB. \
(The driver is not required in a live system.) \
For example, with 22.04.2 image in the current dir:

```
mkdir slim
iso=ubuntu-22.04.2-desktop-amd64.iso

xorriso -indev "$iso" -outdev slim/"$iso" \
    -boot_image any replay -rm_r /pool/restricted/{l,n} --
```

Then copy new `slim/ubuntu-22.04.2-desktop-amd64.iso` to your FAT32-formatted \
GLIM USB-stick.

It also works for Kubuntu, \
but not with Xubuntu which does not have multiple Nvidia-driver versions.

Testing
-------

With KVM it should "just work". \
The `/dev/sdx` device should be configured as an IDE or SATA disk, \
that way you can easily and quickly test changes. \
(For some reason, as USB disk doesn't work on Fedora 17) \
Ensure you unmount the disk from the host OS before starting the KVM \
virtual machine that uses it. \
For UEFI testing, you need to use one of the `/usr/share/edk2/ovmf/*.fd` \
firmwares.

Troubleshooting
---------------

Try re-installing if booting is stuck at the GRUB prompt (before the GLIM menu). \
Re-format your USB memory from scratch for other exotic GRUB errors, \
such as garbage text read instead of the configuration directives,  \
and/or persist in your belief that you are of sound mind should strangeness \
increase or continue.

Contributing
------------

Add the configuration file for missing or outdated OSes:

Create a GitHub PR including:
 * All changes properly and fully tested.
 * New entries added similarly to the existing ones:
   * In A–Z order. \
   With all possible variants supported (i.e. not just the one spin you want).
 * An original icon of high quality, and a shrunk 24x24 PNG version. \
   `convert -size 24x24 -background 'rgba(0,0,0,0)' original.svg small.png`
   may work.
 * An updated supported directory list in this README file.

---
Copyleft 🄯 2012–2023 Matthias Saou https://matthias.saou.eu/

All configuration files included are public domain. \
The invader logo was made by me, so unless covered by \
copyright somewhere, do what you want with it. \
The background is "Wallpaper grey" © 2008 payalnic (DeviantArt) \
The `ascii.pf2` font comes from GRUB, which is GPLv3+ licensed. \
More details and source code on https://www.gnu.org/software/grub/
