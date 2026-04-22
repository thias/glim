#!/usr/bin/env bash
#
# GLIM USB Partitioning Script
#
# Default (simple) mode creates a single FAT32 partition — universal
# compatibility, works with all GRUB layouts:
#
#   P1: FAT32 (label GLIM, full disk)
#
# With --gpt, creates a multi-partition GPT layout that supports ISOs
# larger than the FAT32 4 GiB file-size limit:
#
#   P1: 1 MiB   BIOS Boot Partition (type ef02)
#   P2: 256 MiB EFI System Partition (type ef00, FAT32)
#   P3: [rest]  GLIM data partition  (ext4, label GLIM)
#   P4: [SIZE]  User storage         (exFAT by default, label GLIMDATA, optional)
#
# This script is destructive. All data on the target device will be lost.
#

set -euo pipefail

# Usage/help
# Output: prints usage text to stdout
usage() {
  cat <<EOF
Usage: $(basename "$0") /dev/sdX [--gpt] [--data-size SIZE] [--data-fs exfat|ext4]

  /dev/sdX             Target block device (entire disk, not a partition)
  --gpt                Create a GPT layout with a dedicated EFI System
                       Partition and an ext4 GLIM partition (required for
                       ISO files larger than 4 GiB).
  --data-size SIZE     Create an additional GLIMDATA partition (implies
                       --gpt). SIZE is passed to sgdisk (e.g. 32G, 16384M).
  --data-fs exfat|ext4 Filesystem for the GLIMDATA partition (default: exfat).
                       exFAT: readable on Windows, macOS, and Linux — no file
                       size limit. ext4: Linux-only, journaled.

Default layout (no --gpt):
  P1: FAT32 (label GLIM, full disk)   — simple, universal

GPT layout (--gpt):
  P1: 1 MiB   BIOS Boot Partition (type ef02, no filesystem)
  P2: 256 MiB EFI System Partition (type ef00, FAT32)
  P3: [rest]  GLIM (ext4, label GLIM)
  P4: [SIZE]  GLIMDATA (exFAT by default, label GLIMDATA) -- only with --data-size

WARNING: This script will erase all data on the target device.

Required packages:
  sfdisk      (util-linux)       — simple mode
  gdisk       (for sgdisk)       — GPT mode
  dosfstools  (for mkfs.vfat)    — both modes
  e2fsprogs   (for mkfs.ext4)    — GPT mode (GLIM partition)
  exfatprogs  (for mkfs.exfat)   — GLIMDATA with exFAT (default)
EOF
}

main() {
  # Check that we are *NOT* running as root
  if [[ $(id -u) -eq 0 ]]; then
    echo "ERROR: Don't run as root, use a user with full sudo access."
    exit 1
  fi

  local device=""
  local gpt=false
  local data_size=""
  local data_fs="exfat"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gpt)
        gpt=true
        shift
        ;;
      --data-size)
        data_size="$2"
        shift 2
        ;;
      --data-size=*)
        data_size="${1#*=}"
        shift
        ;;
      --data-fs)
        data_fs="$2"
        shift 2
        ;;
      --data-fs=*)
        data_fs="${1#*=}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        echo "ERROR: Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        if [[ -n "$device" ]]; then
          echo "ERROR: Unexpected argument: $1"
          usage
          exit 1
        fi
        device="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$device" ]]; then
    usage
    exit 1
  fi

  # Validate --data-fs value early, before doing any work
  if [[ "$data_fs" != "exfat" && "$data_fs" != "ext4" ]]; then
    echo "ERROR: --data-fs must be 'exfat' or 'ext4' (got: $data_fs)"
    usage
    exit 1
  fi

  # --data-size implies --gpt (data partition requires multi-partition GPT)
  if [[ -n "$data_size" && "$gpt" == false ]]; then
    echo "Note: --data-size implies --gpt; enabling GPT layout."
    gpt=true
  fi

  # Sanity check : required commands
  local -a required_cmds=(mkfs.vfat lsblk partprobe udevadm)
  if [[ "$gpt" == true ]]; then
    required_cmds+=(sgdisk mkfs.ext4)
  else
    required_cmds+=(sfdisk)
  fi
  if [[ -n "$data_size" && "$data_fs" == "exfat" ]]; then
    required_cmds+=(mkfs.exfat)
  fi
  local cmd
  for cmd in "${required_cmds[@]}"; do
    if ! which "$cmd" &>/dev/null; then
      echo "ERROR: Required command not found: $cmd"
      case "$cmd" in
        sgdisk)      echo "  Install the 'gdisk' package." ;;
        mkfs.vfat)   echo "  Install the 'dosfstools' package." ;;
        mkfs.ext4)   echo "  Install the 'e2fsprogs' package." ;;
        mkfs.exfat)  echo "  Install the 'exfatprogs' package." ;;
        sfdisk)      echo "  Install the 'util-linux' package." ;;
      esac
      exit 1
    fi
  done

  # Sanity check : block device
  if [[ ! -b "$device" ]]; then
    echo "ERROR: $device is not a block device."
    exit 1
  fi

  # Sanity check : not the system disk
  local root_part root_dev
  root_part=$(findmnt -n -o SOURCE / 2>/dev/null || true)
  if [[ -n "$root_part" ]]; then
    root_dev="/dev/$(lsblk -no PKNAME "$root_part" 2>/dev/null || true)"
    if [[ "$device" == "$root_dev" ]]; then
      echo "ERROR: $device appears to be your system disk. Refusing to proceed."
      exit 1
    fi
  fi

  # Show current partition table
  echo "Target device: $device"
  echo ""
  echo "Current partition table:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$device"
  echo ""

  # Layout summary
  if [[ "$gpt" == true ]]; then
    echo "This will create the following GPT layout on $device:"
    echo "  P1: 1 MiB   BIOS Boot Partition (type ef02)"
    echo "  P2: 256 MiB EFI System Partition (type ef00, FAT32)"
    echo "  P3: [remaining${data_size:+ minus $data_size}] GLIM (ext4, label GLIM)"
    if [[ -n "$data_size" ]]; then
      echo "  P4: $data_size  Data ($data_fs, label GLIMDATA)"
    fi
  else
    echo "This will create the following layout on $device:"
    echo "  P1: [full disk]  GLIM (FAT32, label GLIM)"
  fi
  echo ""
  echo "WARNING: ALL DATA ON $device WILL BE LOST!"
  echo ""
  local confirm
  read -r -p "Type 'yes' to proceed: " confirm || true
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 2
  fi

  echo ""
  echo "Partitioning $device ..."

  # Determine partition device names.
  # Devices ending in a digit (e.g. nvme0n1) use a 'p' separator: nvme0n1p1.
  local part_prefix
  if [[ "$device" =~ [0-9]$ ]]; then
    part_prefix="${device}p"
  else
    part_prefix="${device}"
  fi

  if [[ "$gpt" == true ]]; then
    _partition_gpt "$device" "$part_prefix" "$data_size" "$data_fs"
  else
    _partition_simple "$device" "$part_prefix"
  fi

  echo ""
  echo "Done! Final layout:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL "$device"
  echo ""
  echo "Next steps:"
  if [[ "$gpt" == true ]]; then
    local glim="${part_prefix}3"
    echo "  1. Mount the GLIM partition:  sudo mount $glim /mnt"
    echo "  2. Install GLIM:              ./glim.sh"
    echo "  3. Populate ISOs:             /mnt/boot/iso/<distro>/"
    if [[ -n "$data_size" ]]; then
      echo "  4. Data partition ready:      ${part_prefix}4 (label GLIMDATA, $data_fs)"
    fi
  else
    local glim="${part_prefix}1"
    echo "  1. Mount the GLIM partition:  sudo mount $glim /mnt"
    echo "  2. Install GLIM:              ./glim.sh"
    echo "  3. Populate ISOs:             /mnt/boot/iso/<distro>/"
  fi
}

# _partition_simple DEVICE PART_PREFIX
# Create a single FAT32 primary partition covering the whole disk (MBR).
_partition_simple() {
  local device="$1"
  local part_prefix="$2"
  local glim="${part_prefix}1"

  # Wipe any existing GPT/MBR signatures before writing the new layout.
  # Ignoring exit code: sgdisk --zap-all may return non-zero if the
  # existing table is already corrupt, but the wipe still succeeds.
  sudo sgdisk --zap-all "$device" || true
  sudo partprobe "$device" 2>/dev/null || true
  sudo udevadm settle

  # Write an MBR partition table with one FAT32 primary partition.
  # sfdisk format: <start>,<size>,<type>  (type b = FAT32)
  if ! echo "2048,,b" | sudo sfdisk "$device"; then
    echo "ERROR: sfdisk failed."
    exit 1
  fi

  sudo partprobe "$device"
  sudo udevadm settle

  echo ""
  echo "Formatting partition ..."
  echo "  GLIM (FAT32): $glim"
  if ! sudo mkfs.vfat -F 32 -n GLIM "$glim"; then
    echo "ERROR: Failed to format GLIM partition."
    exit 1
  fi

  sudo udevadm settle
}

# _partition_gpt DEVICE PART_PREFIX DATA_SIZE DATA_FS
# Create a GPT layout: BIOS Boot + ESP + ext4 GLIM [+ GLIMDATA in DATA_FS format].
# DATA_FS is only used when DATA_SIZE is non-empty; accepted values: exfat, ext4.
_partition_gpt() {
  local device="$1"
  local part_prefix="$2"
  local data_size="$3"
  local data_fs="$4"

  local esp="${part_prefix}2"
  local glim="${part_prefix}3"
  local data="${part_prefix}4"

  # Zap any existing partition table first, in a separate pass.
  # Combined -Z + partition args fail if the existing GPT is corrupted
  # (e.g. valid backup but invalid main header) because sgdisk exits
  # non-zero after printing warnings, before writing the new layout.
  # Ignoring the exit code here is intentional — the zap succeeds even
  # when sgdisk returns non-zero due to the pre-existing corruption.
  sudo sgdisk --zap-all "$device" || true
  sudo partprobe "$device" 2>/dev/null || true
  sudo udevadm settle

  # Build sgdisk arguments:
  #   -n num:start:end    New partition (0 = next free sector, +N = relative, -N = from end)
  #   -t num:type         Partition type GUID shorthand
  #   -c num:name         Partition name
  local -a sgdisk_args=(
    -n "1:2048:+1M"           # P1: BIOS Boot (2048-sector aligned start)
    -t "1:ef02"               # P1 type: BIOS Boot Partition
    -c "1:BIOS Boot"
    -n "2:0:+256M"            # P2: EFI System Partition
    -t "2:ef00"
    -c "2:ESP"
  )

  if [[ -n "$data_size" ]]; then
    sgdisk_args+=(
      -n "3:0:-${data_size}" # P3: GLIM (all remaining minus data partition)
      -t "3:8300"
      -c "3:GLIM"
      -n "4:0:0"             # P4: Data (fill the rest)
      -t "4:8300"
      -c "4:GLIMDATA"
    )
  else
    sgdisk_args+=(
      -n "3:0:0"             # P3: GLIM (fill all remaining space)
      -t "3:8300"
      -c "3:GLIM"
    )
  fi

  if ! sudo sgdisk "${sgdisk_args[@]}" "$device"; then
    echo "ERROR: sgdisk failed."
    exit 1
  fi

  # Re-read partition table and wait for udev to settle
  sudo partprobe "$device"
  sudo udevadm settle

  echo ""
  echo "Formatting partitions ..."

  echo "  ESP (FAT32): $esp"
  if ! sudo mkfs.vfat -F 32 "$esp"; then
    echo "ERROR: Failed to format ESP."
    exit 1
  fi

  echo "  GLIM (ext4): $glim"
  if ! sudo mkfs.ext4 -L GLIM "$glim"; then
    echo "ERROR: Failed to format GLIM partition."
    exit 1
  fi

  if [[ -n "$data_size" ]]; then
    echo "  GLIMDATA ($data_fs): $data"
    case "$data_fs" in
      exfat)
        if ! sudo mkfs.exfat -n GLIMDATA "$data"; then
          echo "ERROR: Failed to format data partition as exFAT."
          exit 1
        fi
        # exFAT does not support Unix permissions; the filesystem is
        # accessible to all users by default when auto-mounted.
        ;;
      ext4)
        if ! sudo mkfs.ext4 -L GLIMDATA "$data"; then
          echo "ERROR: Failed to format data partition as ext4."
          exit 1
        fi
        # Make the filesystem root world-writable (sticky bit) so any user
        # in any live environment can write to it regardless of UID/GID.
        # 1777 matches the /tmp convention: anyone can create, only owners delete.
        local tmp_mnt
        tmp_mnt=$(mktemp -d)
        # Trap ensures the mount is cleaned up even if chmod fails mid-way.
        # shellcheck disable=SC2064
        trap "sudo umount '$tmp_mnt' 2>/dev/null || true; rmdir '$tmp_mnt' 2>/dev/null || true" EXIT
        sudo mount "$data" "$tmp_mnt"
        sudo chmod 1777 "$tmp_mnt"
        sudo umount "$tmp_mnt"
        rmdir "$tmp_mnt"
        trap - EXIT
        ;;
    esac
  fi

  sudo udevadm settle
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
