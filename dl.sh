#!/bin/bash
#
# BASH. It's what I know best, sorry.
#
# urls
UBUNTU_1804_ISO_URL='http://releases.ubuntu.com/18.04.1/ubuntu-18.04.1-desktop-amd64.iso http://reflection.oss.ou.edu/ubuntu-release/18.04.1/ubuntu-18.04.1-desktop-amd64.iso'
UBUNTU_1804_SERVER_ISO_URL='http://releases.ubuntu.com/18.04.1/ubuntu-18.04.1.0-live-server-amd64.iso http://reflection.oss.ou.edu/ubuntu-release/18.04.1/ubuntu-18.04.1.0-live-server-amd64.iso'
UBUNTU_1810_ISO_URL='http://releases.ubuntu.com/18.10/ubuntu-18.10-desktop-amd64.iso http://reflection.oss.ou.edu/ubuntu-release/18.10/ubuntu-18.10-desktop-amd64.iso'
UBUNTU_1810_SERVER_ISO_URL='http://releases.ubuntu.com/18.10/ubuntu-18.10-live-server-amd64.iso http://reflection.oss.ou.edu/ubuntu-release/18.10/ubuntu-18.10-live-server-amd64.iso'
CENTOS_7_LIVE_KDE='http://repos.dfw.quadranet.com/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-LiveKDE-1810.iso http://yum.tamu.edu/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-LiveKDE-1810.iso http://mirror.dal10.us.leaseweb.net/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-LiveKDE-1810.iso'
CENTOS_7_LIVE_GNOME='http://repos.dfw.quadranet.com/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-LiveGNOME-1810.iso http://yum.tamu.edu/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-LiveGNOME-1810.iso http://mirror.dal10.us.leaseweb.net/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-LiveGNOME-1810.iso'
ARCH_MAGNET='magnet:?xt=urn:btih:8bdeb550636d3b523b2d2b3bd49d7b0fc731176c&dn=archlinux-2019.01.01-x86_64.iso&tr=udp://tracker.archlinux.org:6969&tr=http://tracker.archlinux.org:6969/announce'
ANTERGOS_TORRENT='http://mirrors.antergos.com/iso/release/antergos-18.12-x86_64.iso.torrent'
ANTIX_TORRENT='https://linuxtracker.org/index.php?page=torrent-details&id=f9bb66ddd15dfbb50fe0d2be0f72b82a7671fa02'
ANTIX_32_TORRENT='https://linuxtracker.org/index.php?page=torrent-details&id=728f155c1192da03b07556cabdd0b7a0c7226bcd'
CLONEZILLA_URL='https://osdn.net/frs/redir.php?m=gigenet&f=clonezilla%2F69912%2Fclonezilla-live-2.5.6-22-amd64.iso'
CLONEZILLA_32_URL='https://osdn.net/frs/redir.php?m=constant&f=clonezilla%2F69912%2Fclonezilla-live-2.5.6-22-i686.iso'
DEBIAN_TORRENT='https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-9.6.0-amd64-netinst.iso.torrent'
BODHI_TORRENT='http://sourceforge.net/projects/bodhilinux/files/5.0.0/bodhi-5.0.0-64.iso.torrent/download'
BODHI_APPPACK='http://sourceforge.net/projects/bodhilinux/files/5.0.0/bodhi-5.0.0-apppack-64.iso.torrent/download'
BODHI_LEGACY='http://sourceforge.net/projects/bodhilinux/files/5.0.0/bodhi-5.0.0-apppack-64.iso.torrent/download'
GPARTED_URL='https://sourceforge.net/projects/gparted/files/gparted-live-stable/0.33.0-1/gparted-live-0.33.0-1-amd64.iso/download?use_mirror=superb-dca2#'
KALI_TORRENT='https://images.offensive-security.com/kali-linux-2018.4-amd64.iso.torrent'
TAILS_TORRENT='https://tails.boum.org/torrents/files/tails-amd64-3.11.torrent'
SYSRESCUECD_URL='https://downloads.sourceforge.net/project/systemrescuecd/sysresccd-x86/5.3.2/systemrescuecd-x86-5.3.2.iso?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fsystemrescuecd%2Ffiles%2Fsysresccd-x86%2F5.3.2%2Fsystemrescuecd-x86-5.3.2.iso%2Fdownload&ts=1546396872'

check_cmd () {
  if ! type "$1" > /dev/null; then
    echo "$1 was not found in your path!"
    echo "To proceed please install $1 to your path and try again!"
    exit 1
  fi
}

# Check that we are *NOT* running as root
if [[ `id -u` -eq 0 ]]; then
  echo "ERROR: Don't run as root, use a user with full sudo access."
  exit 1
fi

#
# Find GLIM device (use the first if multiple found, you've asked for trouble!)
#

# Sanity check : blkid command
if ! which blkid &>/dev/null; then
  echo "ERROR: blkid command not found."
  exit 1
fi
USBDEV1=`blkid -L GLIM | head -n 1`

# Sanity check : we found one partition to use with matching label
if [[ -z "$USBDEV1" ]]; then
  echo "ERROR: no partition found with label 'GLIM', please create one."
  exit 1
fi
echo "Found partition with label 'GLIM' : ${USBDEV1}"

# Sanity check : our partition is the first and only one on the block device
USBDEV=${USBDEV1%1}
if [[ ! -b "$USBDEV" ]]; then
  echo "ERROR: ${USBDEV} block device not found."
  exit 1
fi
echo "Found block device where to install GRUB2 : ${USBDEV}"
if [[ `ls -1 ${USBDEV}* | wc -l` -ne 2 ]]; then
  echo "ERROR: ${USBDEV1} isn't the only partition on ${USBDEV}"
  exit 1
fi

# Sanity check : our partition is mounted
if ! grep -q -w ${USBDEV1} /proc/mounts; then
  echo "ERROR: ${USBDEV1} isn't mounted"
  exit 1
fi
USBMNT=`grep -w ${USBDEV1} /proc/mounts | cut -d ' ' -f 2`
if [[ -z "$USBMNT" ]]; then
  echo "ERROR: Couldn't find mount point for ${USBDEV1}"
  exit 1
fi
echo "Found mount point for filesystem : ${USBMNT}"

#
# Get serious. If we get here, things are looking sane
#

# Sanity check : human will read the info and confirm
read -n 1 -s -p "Ready to install GLIM isoz. Continue? (Y/n) " PROCEED
if [[ "$PROCEED" == "n" ]]; then
  echo "n"
  exit 2
else
  echo "y"
fi

# Check USB mount dir write permission, to use sudo if missing
if [[ -w "${USBMNT}" ]]; then
  CMD_PREFIX=""
else
  CMD_PREFIX="sudo"
fi

check_cmd aria2c

# Be nice and pre-create the directory, and mention it
[[ -d ${USBMNT}/boot/iso ]] || ${CMD_PREFIX} mkdir ${USBMNT}/boot/iso
echo "GLIM installed! Time to populate the boot/iso directory."

# Ubuntu
$CMD_PREFIX mkdir -p${USBMNT}/boot/iso/ubuntu
cd ${USBMNT}/boot/iso/ubuntu
$CMD_PREFIX aria2c -x2 -c $UBUNTU_1804_ISO_URL
$CMD_PREFIX aria2c -x2 -c $UBUNTU_1804_SERVER_ISO_URL
$CMD_PREFIX aria2c -x2 -c $UBUNTU_1810_ISO_URL
$CMD_PREFIX aria2c -x2 -c $UBUNTU_1810_SERVER_ISO_URL
## Centos
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/centos
cd ${USBMNT}/boot/iso/centos
#$CMD_PREFIX aria2c -x2 -c $CENTOS_7_DVD
$CMD_PREFIX aria2c -x2 -c $CENTOS_7_LIVE_KDE
$CMD_PREFIX aria2c -x2 -c $CENTOS_7_LIVE_GNOME
## arch
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/arch
cd ${USBMNT}/boot/iso/arch
#$CMD_PREFIX aria2c -x2 -c $ARCH_ISO
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $ARCH_MAGNET

$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/antix
cd ${USBMNT}/boot/iso/antix
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $ANTIX_TORRENT
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $ANTIX_32_TORRENT

$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/clonezilla
cd ${USBMNT}/boot/iso/clonezilla
$CMD_PREFIX aria2c -x2 -c $CLONEZILLA_URL
$CMD_PREFIX aria2c -x2 -c $CLONEZILLA_32_URL
## debian
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/debian
cd ${USBMNT}/boot/iso/debian
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $DEBIAN_TORRENT

# bodhi
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/bodhi
cd ${USBMNT}/boot/iso/bodhi
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $BODHI_TORRENT
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $BODHI_APPPACK
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $BODHI_LEGACY

# gparted
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/bodhi
cd ${USBMNT}/boot/iso/bodhi
$CMD_PREFIX aria2c -x2 -c $GPARTED_URL

# kali
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/kali
cd ${USBMNT}/boot/iso/kali
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $KALI_TORRENT

# tails
$CMD_PREFIX mkdir -p ${USBMNT}/boot/iso/tails
cd ${USBMNT}/boot/iso/tails
$CMD_PREFIX aria2c --seed-time=1 --seed-ratio=1.0 -c --follow-torrent=mem $TAILS_TORRENT
