"""
Tests for glim.sh installation on both GPT and legacy FAT32 layouts.

Verifies that GRUB core files, grub.cfg, and the boot/iso directory tree
are all present after a successful install — without booting anything.
"""

import os
import pytest

from conftest import REPO_ROOT, part_name, sudo


def _grub_dir(mount_point):
    """
    Return the GRUB2 config directory under *mount_point*.
    glim.sh writes to boot/grub2/ on Fedora-family and boot/grub/ on Debian-family.
    """
    for name in ("grub2", "grub"):
        candidate = mount_point / "boot" / name
        if candidate.is_dir():
            return candidate
    return None


# ---------------------------------------------------------------------------
# GPT layout install
# ---------------------------------------------------------------------------


class TestGptInstall:
    def test_glim_sh_succeeds(self, installed_glim):
        """Fixture creation asserts returncode == 0; reaching here means it passed."""
        pass

    def test_grub_cfg_installed(self, installed_glim):
        _, mount_point = installed_glim
        grub_dir = _grub_dir(mount_point)
        assert grub_dir is not None, "GRUB directory not found under boot/"
        assert (grub_dir / "grub.cfg").is_file()

    def test_bios_core_image_installed(self, installed_glim):
        device, _ = installed_glim
        # GRUB BIOS core image lives in the BIOS Boot partition (P1).
        # We verify GRUB wrote something to the MBR / gap area by checking
        # that the first 512 bytes are not all zeros.
        import subprocess
        result = subprocess.run(
            ["sudo", "-n", "dd", f"if={device}", "bs=512", "count=1", "status=none"],
            check=True,
            capture_output=True,
        )
        assert result.stdout != b"\x00" * 512, "MBR appears empty — BIOS GRUB not installed"

    def test_efi_binary_in_esp(self, installed_glim, gpt_device):
        _, mount_point = installed_glim
        esp_part = part_name(gpt_device, 2)
        esp_mount = mount_point.parent / "esp"
        esp_mount.mkdir(exist_ok=True)
        sudo("mount", esp_part, str(esp_mount))
        try:
            efi_binary = esp_mount / "EFI" / "BOOT" / "BOOTX64.EFI"
            assert efi_binary.is_file(), f"EFI binary not found at {efi_binary}"
        finally:
            sudo("umount", str(esp_mount), check=False)

    def test_boot_iso_directories_created(self, installed_glim):
        _, mount_point = installed_glim
        iso_root = mount_point / "boot" / "iso"
        assert iso_root.is_dir(), "boot/iso/ directory missing"
        # At least a few distro directories should be pre-created
        dirs = [d.name for d in iso_root.iterdir() if d.is_dir()]
        assert len(dirs) >= 10, f"Expected ≥10 distro dirs, found {len(dirs)}: {dirs}"

    def test_grub_cfg_references_isopath(self, installed_glim):
        _, mount_point = installed_glim
        grub_dir = _grub_dir(mount_point)
        cfg = (grub_dir / "grub.cfg").read_text()
        assert "isopath" in cfg
        assert "/boot/iso" in cfg

    def test_inc_cfgs_installed(self, installed_glim):
        _, mount_point = installed_glim
        grub_dir = _grub_dir(mount_point)
        inc_files = list(grub_dir.glob("inc-*.cfg"))
        assert len(inc_files) >= 30, (
            f"Expected ≥30 inc-*.cfg files, found {len(inc_files)}"
        )


# ---------------------------------------------------------------------------
# Legacy FAT32 install (backwards compatibility)
# ---------------------------------------------------------------------------


class TestLegacyInstall:
    def test_glim_sh_succeeds_on_legacy(self, installed_legacy_glim):
        pass

    def test_grub_cfg_installed_on_legacy(self, installed_legacy_glim):
        _, mount_point = installed_legacy_glim
        grub_dir = _grub_dir(mount_point)
        assert grub_dir is not None
        assert (grub_dir / "grub.cfg").is_file()

    def test_boot_iso_directories_on_legacy(self, installed_legacy_glim):
        _, mount_point = installed_legacy_glim
        iso_root = mount_point / "boot" / "iso"
        assert iso_root.is_dir()
