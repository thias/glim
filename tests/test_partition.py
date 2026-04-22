"""
Tests for glim-partition.sh.

Verifies that the GPT layout produced by the script matches the expected
partition types, labels, and relative sizes — without booting anything.
"""

import json
import subprocess
import pytest

from conftest import sudo, part_name

# EFI System Partition type GUID (lowercase, as reported by lsblk)
_ESP_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
# BIOS Boot Partition type GUID
_BIOS_BOOT_GUID = "21686148-6449-6e6f-744e-656564454649"
# Linux filesystem type GUID
_LINUX_FS_GUID = "0fc63daf-8483-4772-8e79-3d69d8477de4"


def _lsblk(device):
    """
    Return lsblk JSON output for *device* as a list of partition dicts.
    Each dict has keys: name, parttype, fstype, label, size.
    """
    result = sudo(
        "lsblk", "--json", "--output",
        "NAME,PARTTYPE,FSTYPE,LABEL,SIZE,PARTLABEL",
        device,
    )
    data = json.loads(result.stdout)
    # Top-level entry is the device; children are the partitions
    children = data["blockdevices"][0].get("children", [])
    return children


# ---------------------------------------------------------------------------
# Simple default layout (single FAT32 partition, MBR)
# ---------------------------------------------------------------------------


class TestSimpleLayout:
    def test_single_partition_created(self, simple_device):
        parts = _lsblk(simple_device)
        assert len(parts) == 1, f"Expected 1 partition, got {len(parts)}: {parts}"

    def test_p1_formatted_fat32(self, simple_device):
        parts = _lsblk(simple_device)
        assert parts[0]["fstype"] == "vfat"

    def test_p1_label_is_glim(self, simple_device):
        parts = _lsblk(simple_device)
        assert parts[0]["label"] == "GLIM"

    def test_partition_table_is_mbr(self, simple_device):
        """Partition table must be MBR (dos), not GPT."""
        result = sudo("blkid", "-o", "value", "-s", "PTTYPE", simple_device)
        assert result.stdout.strip() == "dos", (
            f"Expected MBR (dos) partition table, got: {result.stdout.strip()!r}"
        )


# ---------------------------------------------------------------------------
# Basic GPT layout (no data partition)
# ---------------------------------------------------------------------------


class TestGptLayout:
    def test_four_partitions_not_created_without_data_flag(self, gpt_device):
        parts = _lsblk(gpt_device)
        # P1 BIOS Boot, P2 ESP, P3 GLIM — exactly 3
        assert len(parts) == 3, f"Expected 3 partitions, got {len(parts)}: {parts}"

    def test_p1_bios_boot_type(self, gpt_device):
        parts = _lsblk(gpt_device)
        assert parts[0]["parttype"].lower() == _BIOS_BOOT_GUID

    def test_p2_efi_system_partition_type(self, gpt_device):
        parts = _lsblk(gpt_device)
        assert parts[1]["parttype"].lower() == _ESP_GUID

    def test_p2_formatted_fat32(self, gpt_device):
        parts = _lsblk(gpt_device)
        assert parts[1]["fstype"] == "vfat"

    def test_p3_glim_type(self, gpt_device):
        parts = _lsblk(gpt_device)
        assert parts[2]["parttype"].lower() == _LINUX_FS_GUID

    def test_p3_formatted_ext4(self, gpt_device):
        parts = _lsblk(gpt_device)
        assert parts[2]["fstype"] == "ext4"

    def test_p3_label_is_glim(self, gpt_device):
        parts = _lsblk(gpt_device)
        assert parts[2]["label"] == "GLIM"


# ---------------------------------------------------------------------------
# GPT layout with optional data partition
# ---------------------------------------------------------------------------


class TestGptLayoutWithData:
    def test_four_partitions_created(self, gpt_device_with_data):
        parts = _lsblk(gpt_device_with_data)
        assert len(parts) == 4, f"Expected 4 partitions, got {len(parts)}: {parts}"

    def test_p4_formatted_exfat(self, gpt_device_with_data):
        """Default --data-fs is exFAT."""
        parts = _lsblk(gpt_device_with_data)
        assert parts[3]["fstype"] == "exfat"

    def test_p4_label_is_glimdata(self, gpt_device_with_data):
        parts = _lsblk(gpt_device_with_data)
        assert parts[3]["label"] == "GLIMDATA"

    def test_p3_is_smaller_than_without_data(self, gpt_device, gpt_device_with_data):
        """P3 (GLIM) must be smaller when a data partition is present."""
        result_no_data = sudo("sgdisk", "--print", gpt_device)
        result_with_data = sudo("sgdisk", "--print", gpt_device_with_data)

        def p3_sectors(sgdisk_output):
            for line in sgdisk_output.splitlines():
                if line.strip().startswith("3 "):
                    cols = line.split()
                    return int(cols[2]) - int(cols[1])
            return None

        sectors_no_data = p3_sectors(result_no_data.stdout)
        sectors_with_data = p3_sectors(result_with_data.stdout)
        assert sectors_no_data is not None
        assert sectors_with_data is not None
        assert sectors_with_data < sectors_no_data

    def test_p4_size_matches_requested(self, gpt_device_with_data):
        """P4 (GLIMDATA) sector count must be within 5% of the requested 32 MiB."""
        result = sudo("sgdisk", "--print", gpt_device_with_data)

        p4_sectors = None
        sector_size = 512  # default; overridden below if sgdisk reports otherwise
        for line in result.stdout.splitlines():
            # "Logical sector size: 512 bytes"
            if "logical sector size" in line.lower():
                sector_size = int(line.split()[-2])
            if line.strip().startswith("4 "):
                cols = line.split()
                p4_sectors = int(cols[2]) - int(cols[1])

        assert p4_sectors is not None, "P4 not found in sgdisk output"

        requested_bytes = 32 * 1024 * 1024   # 32 MiB passed as --data-size to the fixture
        actual_bytes = p4_sectors * sector_size
        # Allow up to 5% deviation for partition alignment rounding
        assert abs(actual_bytes - requested_bytes) / requested_bytes < 0.05, (
            f"P4 size {actual_bytes} bytes deviates >5% from requested {requested_bytes} bytes"
        )


# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------


class TestSafetyChecks:
    def test_aborts_on_non_yes_confirmation(self, loop_device):
        """Script must not partition the device if user types anything other than 'yes'."""
        from conftest import run_script, GRUB_PARTITION_SH
        result = run_script(GRUB_PARTITION_SH, loop_device, input="no\n")
        assert result.returncode != 0

        # Verify nothing was written (blkid sees no known partition table)
        check = sudo("blkid", "-o", "value", "-s", "PTTYPE", loop_device, check=False)
        assert check.stdout.strip() == ""

    def test_rejects_non_block_device(self, tmp_path):
        fake = tmp_path / "not-a-device"
        fake.write_text("")
        result = subprocess.run(
            ["bash", __import__("conftest").GRUB_PARTITION_SH, str(fake)],
            capture_output=True, text=True,
        )
        assert result.returncode != 0
        assert "not a block device" in result.stderr.lower() or \
               "not a block device" in result.stdout.lower()

    def test_data_size_without_gpt_enables_gpt(self, loop_device):
        """--data-size without --gpt should auto-enable GPT and succeed."""
        from conftest import run_script, GRUB_PARTITION_SH
        result = run_script(GRUB_PARTITION_SH, loop_device, "--data-size", "32M", input="yes\n")
        assert result.returncode == 0
        assert "implies --gpt" in result.stdout or "enabling gpt" in result.stdout.lower()
        # Verify GPT was created
        parts = _lsblk(loop_device)
        assert len(parts) == 4

    def test_invalid_data_fs_rejected(self, tmp_path):
        """--data-fs with an unsupported value must exit non-zero before prompting."""
        import conftest
        fake = tmp_path / "not-a-device"
        fake.write_text("")
        result = conftest.run_script(
            conftest.GRUB_PARTITION_SH,
            "/dev/null",
            "--data-fs", "ntfs",
        )
        assert result.returncode != 0
        assert "exfat" in result.stdout.lower() or "exfat" in result.stderr.lower()


# ---------------------------------------------------------------------------
# GPT layout with ext4 data partition (--data-fs ext4)
# ---------------------------------------------------------------------------


class TestGptLayoutWithDataExt4:
    def test_p4_formatted_ext4(self, gpt_device_with_data_ext4):
        parts = _lsblk(gpt_device_with_data_ext4)
        assert len(parts) == 4
        assert parts[3]["fstype"] == "ext4"

    def test_p4_label_is_glimdata(self, gpt_device_with_data_ext4):
        parts = _lsblk(gpt_device_with_data_ext4)
        assert parts[3]["label"] == "GLIMDATA"
