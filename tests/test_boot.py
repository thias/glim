"""
QEMU boot tests for GLIM.

These tests verify that GRUB loads and displays its menu in both BIOS and UEFI
boot modes, using headless QEMU with serial console output.

After glim.sh installs GRUB, the installed grub.cfg is patched to redirect
terminal output to the serial port so QEMU can capture it.  The patch is
applied only to the test image — the source grub.cfg in the repository is
untouched.

Marks
-----
Tests in this module are marked ``boot`` and require:
  - qemu-system-x86_64
  - OVMF firmware (for UEFI tests)
  - sudo access for losetup/mount operations (inherited from fixtures)

Run only boot tests::

    uv run pytest -m boot

Skip boot tests::

    uv run pytest -m "not boot"
"""

import os
import shutil
import pytest

from conftest import sudo
from helpers.qemu import QemuBoot

pytestmark = pytest.mark.boot

# Strings that should appear in the GRUB serial output regardless of which
# distros are present.  These come from grub.cfg itself.
_EXPECTED_BIOS = ["GRUB"]
_EXPECTED_UEFI = ["GRUB"]


def _patch_grub_cfg_for_serial(mount_point):
    """
    Modify the installed grub.cfg so GRUB sends output to the serial port.

    Replaces::

        terminal_output gfxterm

    With::

        serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
        terminal_input serial console
        terminal_output serial console

    This makes GRUB write its menu text to /dev/ttyS0 (captured by QEMU as
    stdout when run with ``-nographic -serial stdio``).
    """
    for grub_dir_name in ("grub2", "grub"):
        grub_cfg = mount_point / "boot" / grub_dir_name / "grub.cfg"
        if grub_cfg.is_file():
            break
    else:
        raise FileNotFoundError(f"grub.cfg not found under {mount_point}/boot/")

    original = grub_cfg.read_text()
    patched = original.replace(
        "terminal_output gfxterm",
        (
            "serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1\n"
            "terminal_input serial console\n"
            "terminal_output serial console"
        ),
    )
    assert patched != original, "grub.cfg patch had no effect — 'terminal_output gfxterm' not found"
    grub_cfg.write_text(patched)


def _disk_image_path(mount_point):
    """
    Return the path to the raw disk image file that backs the mounted
    GLIM partition.  We find it via /proc/mounts and losetup.
    """
    result = sudo("losetup", "--list", "--json")
    import json
    loops = json.loads(result.stdout).get("loopdevices", [])
    # Find the loop device whose mount point contains our GLIM mount
    for entry in loops:
        if mount_point.parts[1] in entry.get("back-file", ""):
            return entry["back-file"]

    # Fallback: derive from the mount point's block device via /proc/mounts
    with open("/proc/mounts") as f:
        for line in f:
            parts = line.split()
            if parts[1] == str(mount_point):
                dev = parts[0]
                break
        else:
            raise RuntimeError(f"Cannot find backing image for {mount_point}")

    # dev is something like /dev/loop0p3 — strip back to /dev/loop0
    import re
    m = re.match(r"(/dev/loop\d+)", dev)
    if not m:
        raise RuntimeError(f"Unexpected device format: {dev}")
    loop = m.group(1)

    for entry in loops:
        if entry["name"] == loop:
            return entry["back-file"]
    raise RuntimeError(f"Loop device {loop} not found in losetup output")


# ---------------------------------------------------------------------------
# BIOS boot test
# ---------------------------------------------------------------------------


class TestBiosBoot:
    @pytest.fixture(autouse=True)
    def _prepare(self, installed_glim):
        device, mount_point = installed_glim
        _patch_grub_cfg_for_serial(mount_point)
        # Flush writes before QEMU reads the image
        sudo("sync")
        sudo("umount", str(mount_point), check=False)

        self.image = _disk_image_path(mount_point)
        yield

    def test_grub_starts(self):
        with QemuBoot.bios(self.image) as q:
            output = q.wait_for(*_EXPECTED_BIOS, timeout=45)
        assert any(s in output for s in _EXPECTED_BIOS), (
            f"Expected one of {_EXPECTED_BIOS!r} in serial output.\n"
            f"Got:\n{output}"
        )


# ---------------------------------------------------------------------------
# UEFI boot test
# ---------------------------------------------------------------------------


class TestUefiBoot:
    @pytest.fixture(autouse=True)
    def _prepare(self, installed_glim):
        device, mount_point = installed_glim
        _patch_grub_cfg_for_serial(mount_point)
        sudo("sync")
        sudo("umount", str(mount_point), check=False)

        self.image = _disk_image_path(mount_point)
        yield

    def test_grub_starts(self):
        with QemuBoot.uefi(self.image) as q:
            output = q.wait_for(*_EXPECTED_UEFI, timeout=60)
        assert any(s in output for s in _EXPECTED_UEFI), (
            f"Expected one of {_EXPECTED_UEFI!r} in serial output.\n"
            f"Got:\n{output}"
        )
