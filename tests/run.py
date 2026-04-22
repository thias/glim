#!/usr/bin/env python3
"""
GLIM test runner.

Dependencies are managed via pyproject.toml. Run with:

    uv run tests/run.py              # all tests
    uv run tests/run.py --fast       # partition + install only (no QEMU)
    uv run tests/run.py --boot       # QEMU boot tests only
    uv run tests/run.py -- -v -k test_p3_label_is_glim

Prerequisites (all tests)
-------------------------
- passwordless sudo for: losetup, sgdisk, mkfs.ext4, mkfs.exfat, mkfs.vfat,
  mount, umount, partprobe, udevadm, sync, dd, chown, chmod
- gdisk (sgdisk), dosfstools (mkfs.vfat), e2fsprogs (mkfs.ext4),
  exfatprogs (mkfs.exfat)

Additional prerequisites (boot tests)
--------------------------------------
- qemu-system-x86_64
- OVMF firmware package (ovmf on Debian/Ubuntu)
"""

import json
import os
import pathlib
import shutil
import subprocess
import sys
import argparse

# Make the tests/ directory importable when invoked as a script
_TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
if _TESTS_DIR not in sys.path:
    sys.path.insert(0, _TESTS_DIR)

import pytest

# Our exclusive basetemp directory — safe to wipe on startup.
_BASETEMP = pathlib.Path("/var/tmp/glim-tests")


def _sudo(*args):
    """Run a command under sudo -n (non-interactive). Returns True on success."""
    return subprocess.run(
        ["sudo", "-n", *args],
        capture_output=True,
    ).returncode == 0


def _force_cleanup(path: pathlib.Path):
    """
    Tear down any mounts and loop devices under *path*, then delete it.

    Safe to call on a clean directory — all steps are best-effort.
    """
    if not path.exists():
        return

    # 1. Unmount everything under this path (reverse order so nested mounts go first).
    with open("/proc/mounts") as f:
        mounts = [
            line.split()[1]
            for line in f
            if line.split()[1].startswith(str(path))
        ]
    for mount_point in sorted(mounts, reverse=True):
        _sudo("umount", "-l", mount_point)

    # 2. Detach loop devices whose backing file lives under *path*.
    #    We filter by back-file so we never touch loop devices belonging
    #    to other processes or mounted system images.
    result = subprocess.run(
        ["sudo", "-n", "losetup", "--json"],
        capture_output=True, text=True,
    )
    if result.returncode == 0 and result.stdout.strip():
        try:
            data = json.loads(result.stdout)
            for dev in data.get("loopdevices", []):
                backing = dev.get("back-file", "")
                if backing.startswith(str(path)):
                    _sudo("losetup", "-d", dev["name"])
        except (json.JSONDecodeError, KeyError):
            pass

    # 3. Delete the directory tree.
    shutil.rmtree(path, ignore_errors=True)

    if path.exists():
        print(f"WARNING: Could not fully remove {path} — some files may need manual cleanup.")


def _clean_stale_dirs():
    """Remove stale basetemp left behind by aborted runs."""
    if _BASETEMP.exists():
        print(f"Cleaning up stale temp dir: {_BASETEMP}")
        _force_cleanup(_BASETEMP)


def main():
    parser = argparse.ArgumentParser(description="GLIM automated test runner")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--fast",
        action="store_true",
        help="Partition + install tests only (no QEMU)",
    )
    mode.add_argument(
        "--boot",
        action="store_true",
        help="QEMU boot tests only",
    )
    parser.add_argument(
        "extra",
        nargs=argparse.REMAINDER,
        help="Extra arguments forwarded to pytest (after --)",
    )
    args = parser.parse_args()

    _clean_stale_dirs()

    pytest_args = [_TESTS_DIR, "-v"]

    if args.fast:
        pytest_args += ["-m", "not boot"]
    elif args.boot:
        pytest_args += ["-m", "boot"]

    extra = args.extra
    if extra and extra[0] == "--":
        extra = extra[1:]
    pytest_args += extra

    sys.exit(pytest.main(pytest_args))


if __name__ == "__main__":
    main()
