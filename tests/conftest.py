"""
Shared pytest fixtures for GLIM test suite.

Scripts (glim-partition.sh, glim.sh) are run as the current user — they call
sudo internally for privileged operations.  The sudoers drop-in installed by
``sudo bash tests/setup-sudo.sh`` grants passwordless access to those specific
commands.

Fixtures that call privileged commands directly (losetup, mount, etc.) use the
sudo() helper which passes -n (non-interactive) so a missing sudoers entry
fails immediately with a clear error rather than hanging.
"""

import os
import re
import subprocess
import pytest

# Disk image size in MiB.
# Must accommodate: 1 MiB BIOS Boot + 256 MiB ESP + ext4 GLIM + GPT overhead.
# Minimum viable is ~360 MiB; 512 MiB gives a comfortable margin.
_DISK_SIZE_MIB = 512

# Minimum size for a legacy single-partition FAT32 image.
_LEGACY_DISK_SIZE_MIB = 128

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRUB_PARTITION_SH = os.path.join(REPO_ROOT, "glim-partition.sh")
GLIM_SH = os.path.join(REPO_ROOT, "glim.sh")


def sudo(*args, input=None, check=True, capture_output=True):
    """
    Run a command under sudo -n (non-interactive), returning CompletedProcess.

    -n causes sudo to fail immediately rather than prompting for a password.
    Run ``sudo bash tests/setup-sudo.sh`` once before using the test suite.
    """
    return subprocess.run(
        ["sudo", "-n", *args],
        input=input,
        text=True,
        check=check,
        capture_output=capture_output,
    )


def run_script(script, *args, input=None, capture_output=True):
    """
    Run a GLIM shell script as the current user (not via sudo).

    The scripts call sudo internally for privileged commands; those calls rely
    on the sudoers drop-in for passwordless access.
    """
    return subprocess.run(
        ["bash", script, *args],
        input=input,
        text=True,
        capture_output=capture_output,
    )


def part_name(device, num):
    """
    Return the partition device name for *device* partition *num*.
    Handles both /dev/sdXN and /dev/nvme0n1pN naming conventions.
    """
    if re.search(r"\d$", device):
        return f"{device}p{num}"
    return f"{device}{num}"


# ---------------------------------------------------------------------------
# Disk image + loop device
# ---------------------------------------------------------------------------


@pytest.fixture()
def disk_image(tmp_path):
    """Create a blank disk image in a temporary directory."""
    img = tmp_path / "glim-test.img"
    subprocess.run(
        ["dd", "if=/dev/zero", f"of={img}", "bs=1M", f"count={_DISK_SIZE_MIB}"],
        check=True,
        capture_output=True,
    )
    yield img


@pytest.fixture()
def legacy_disk_image(tmp_path):
    """Smaller blank image for single-partition FAT32 tests."""
    img = tmp_path / "glim-legacy-test.img"
    subprocess.run(
        ["dd", "if=/dev/zero", f"of={img}", "bs=1M", f"count={_LEGACY_DISK_SIZE_MIB}"],
        check=True,
        capture_output=True,
    )
    yield img


@pytest.fixture()
def loop_device(disk_image):
    """Attach *disk_image* as a loop device with automatic partition scanning."""
    result = sudo("losetup", "--find", "--show", "-P", str(disk_image))
    device = result.stdout.strip()
    assert device, "losetup did not return a device path"
    yield device
    sudo("losetup", "-d", device, check=False)


@pytest.fixture()
def disk_image_2(tmp_path):
    """Second independent blank disk image (used when a test needs two GPT devices)."""
    img = tmp_path / "glim-test-2.img"
    subprocess.run(
        ["dd", "if=/dev/zero", f"of={img}", "bs=1M", f"count={_DISK_SIZE_MIB}"],
        check=True,
        capture_output=True,
    )
    yield img


@pytest.fixture()
def loop_device_2(disk_image_2):
    """Second independent loop device backed by *disk_image_2*."""
    result = sudo("losetup", "--find", "--show", "-P", str(disk_image_2))
    device = result.stdout.strip()
    assert device, "losetup did not return a device path"
    yield device
    sudo("losetup", "-d", device, check=False)


@pytest.fixture()
def legacy_loop_device(legacy_disk_image):
    """Loop device for the single-partition FAT32 image."""
    result = sudo("losetup", "--find", "--show", "-P", str(legacy_disk_image))
    device = result.stdout.strip()
    assert device, "losetup did not return a device path"
    yield device
    sudo("losetup", "-d", device, check=False)


# ---------------------------------------------------------------------------
# Partitioned + formatted devices
# ---------------------------------------------------------------------------


@pytest.fixture()
def simple_device(legacy_loop_device):
    """
    Loop device partitioned by glim-partition.sh in default (simple FAT32) mode.
    Uses the legacy-sized (128 MiB) image since only one FAT32 partition is needed.
    """
    result = run_script(GRUB_PARTITION_SH, legacy_loop_device, input="yes\n")
    assert result.returncode == 0, (
        f"glim-partition.sh simple mode failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    sudo("udevadm", "settle")
    yield legacy_loop_device


@pytest.fixture()
def gpt_device(loop_device):
    """
    Loop device partitioned with glim-partition.sh (GPT, no data partition).
    """
    result = run_script(GRUB_PARTITION_SH, loop_device, "--gpt", input="yes\n")
    assert result.returncode == 0, (
        f"glim-partition.sh failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    sudo("udevadm", "settle")
    yield loop_device


@pytest.fixture()
def gpt_device_with_data(loop_device_2):
    """GPT layout including a 32 MiB GLIMDATA partition formatted as exFAT (default)."""
    result = run_script(GRUB_PARTITION_SH, loop_device_2, "--gpt", "--data-size", "32M", input="yes\n")
    assert result.returncode == 0, (
        f"glim-partition.sh failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    sudo("udevadm", "settle")
    yield loop_device_2


@pytest.fixture()
def disk_image_3(tmp_path):
    """Third independent blank disk image (used for --data-fs ext4 tests)."""
    img = tmp_path / "glim-test-3.img"
    subprocess.run(
        ["dd", "if=/dev/zero", f"of={img}", "bs=1M", f"count={_DISK_SIZE_MIB}"],
        check=True,
        capture_output=True,
    )
    yield img


@pytest.fixture()
def loop_device_3(disk_image_3):
    """Third independent loop device backed by *disk_image_3*."""
    result = sudo("losetup", "--find", "--show", "-P", str(disk_image_3))
    device = result.stdout.strip()
    assert device, "losetup did not return a device path"
    yield device
    sudo("losetup", "-d", device, check=False)


@pytest.fixture()
def gpt_device_with_data_ext4(loop_device_3):
    """GPT layout including a 32 MiB GLIMDATA partition formatted as ext4."""
    result = run_script(
        GRUB_PARTITION_SH, loop_device_3,
        "--gpt", "--data-size", "32M", "--data-fs", "ext4",
        input="yes\n",
    )
    assert result.returncode == 0, (
        f"glim-partition.sh failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    sudo("udevadm", "settle")
    yield loop_device_3


@pytest.fixture()
def legacy_device(legacy_loop_device):
    """
    Single-partition FAT32 device simulating the legacy GLIM layout.

    Uses an MBR partition table with one FAT32 partition — exactly what a
    real legacy GLIM USB stick looks like.  MBR allows GRUB BIOS to install
    its core image into the MBR gap (no BIOS Boot partition required).
    """
    glim_part = part_name(legacy_loop_device, 1)
    # Write an MBR partition table with a single FAT32 primary partition.
    # sfdisk accepts: <start>,<size>,<type> where type b = FAT32
    sudo("sfdisk", legacy_loop_device, input="2048,,b\n")
    sudo("partprobe", legacy_loop_device, check=False)
    sudo("udevadm", "settle")
    sudo("mkfs.vfat", "-F", "32", "-n", "GLIM", glim_part)
    sudo("udevadm", "settle")
    yield legacy_loop_device


# ---------------------------------------------------------------------------
# Mounted GLIM partition
# ---------------------------------------------------------------------------


@pytest.fixture()
def mounted_glim(gpt_device, tmp_path):
    """
    Mount the ext4 GLIM partition (P3) of a GPT device.
    Chowns the mount point so glim.sh can write without needing sudo for rsync.
    Yields the mount-point Path.
    """
    glim_part = part_name(gpt_device, 3)
    mount_point = tmp_path / "glim"
    mount_point.mkdir()
    sudo("mount", glim_part, str(mount_point))
    sudo("chown", "-R", f"{os.getuid()}:{os.getgid()}", str(mount_point))
    yield mount_point
    sudo("umount", str(mount_point), check=False)


@pytest.fixture()
def mounted_legacy_glim(legacy_device, tmp_path):
    """Mount the FAT32 partition of the legacy single-partition device."""
    glim_part = part_name(legacy_device, 1)
    mount_point = tmp_path / "glim-legacy"
    mount_point.mkdir()
    # Mount with uid/gid so all FAT32 files appear owned by the current user.
    # This lets glim.sh run rsync without sudo (same as a user-mounted USB stick).
    sudo("mount", "-o", f"uid={os.getuid()},gid={os.getgid()}",
         glim_part, str(mount_point))
    yield mount_point
    sudo("umount", str(mount_point), check=False)


# ---------------------------------------------------------------------------
# Installed GLIM (glim.sh has been run)
# ---------------------------------------------------------------------------


def _run_glim_sh(answers=b"yy"):
    """
    Run glim.sh as the current user, sending *answers* to interactive prompts.

    glim.sh prompts (in order, when both BIOS + EFI GRUB are installed):
      1. "Install for EFI in addition to standard BIOS? (Y/n)"  → 'y'
      2. "Ready to install GLIM. Continue? (Y/n)"               → 'y'
    """
    return subprocess.run(
        ["bash", GLIM_SH],
        input=answers,
        capture_output=True,
    )


@pytest.fixture()
def installed_glim(gpt_device, mounted_glim):
    """GPT device with GRUB installed via glim.sh (BIOS + EFI)."""
    result = _run_glim_sh()
    assert result.returncode == 0, (
        f"glim.sh failed:\nSTDOUT:\n{result.stdout.decode()}\n"
        f"STDERR:\n{result.stderr.decode()}"
    )
    yield gpt_device, mounted_glim


@pytest.fixture()
def installed_legacy_glim(legacy_device, mounted_legacy_glim):
    """Legacy FAT32 device with GRUB installed via glim.sh."""
    result = _run_glim_sh()
    assert result.returncode == 0, (
        f"glim.sh failed:\nSTDOUT:\n{result.stdout.decode()}\n"
        f"STDERR:\n{result.stderr.decode()}"
    )
    yield legacy_device, mounted_legacy_glim
