# GLIM Test Suite

Automated tests for `glim-partition.sh` and `glim.sh`.  Tests run
against real loop devices and (optionally) QEMU virtual machines — no
mocking of disk or filesystem operations.

## Quick start

```bash
# One-time setup: grant passwordless sudo for the required commands
sudo bash tests/setup-sudo.sh

# Run partition + install tests (no QEMU required, ~3 min)
uv run tests/run.py --fast

# Run QEMU boot tests only
uv run tests/run.py --boot

# Run everything
uv run tests/run.py
```

## Prerequisites

| Tool | Package | Required for |
|------|---------|-------------|
| `losetup`, `sfdisk` | `util-linux` | All tests |
| `sgdisk` | `gdisk` | GPT partition tests |
| `mkfs.vfat` | `dosfstools` | All tests |
| `mkfs.ext4` | `e2fsprogs` | GPT tests (GLIM partition + ext4 GLIMDATA) |
| `mkfs.exfat` | `exfatprogs` | GPT tests (exFAT GLIMDATA, default) |
| `udevadm`, `partprobe` | `udev`, `parted` | All tests |
| `qemu-system-x86_64` | `qemu-system-x86` | Boot tests |
| `OVMF_CODE_4M.fd` | `ovmf` | UEFI boot test |

The sudoers drop-in (`tests/setup-sudo.sh`) grants passwordless `sudo`
for the specific commands above.  Run it once after installing packages,
and re-run it whenever `setup-sudo.sh` itself changes (e.g. when new
commands are added).  To revoke access when you no longer need it:

```bash
sudo bash tests/setup-sudo.sh --remove
```

## How the tests work

### Disk images and loop devices

Every test that touches a disk creates a fresh blank image in a
temporary directory and attaches it as a loop device.  No physical
disk is ever required.

```
tmp_path/glim-test.img      (512 MiB) ─► /dev/loopX  (GPT tests)
tmp_path/glim-test-2.img    (512 MiB) ─► /dev/loopY  (exFAT GLIMDATA tests)
tmp_path/glim-test-3.img    (512 MiB) ─► /dev/loopZ  (ext4 GLIMDATA tests)
tmp_path/glim-legacy-test.img (128 MiB) ─► /dev/loopW (FAT32 / simple tests)
```

Fixtures in `conftest.py` create and tear down loop devices
automatically.  All temporary files land under
`/var/tmp/glim-tests/` (configured in `pyproject.toml`) rather than
`/tmp`, because disk images are too large for a tmpfs.

### Fixture hierarchy

```
tmp_path
└── disk_image ──────────────────► loop_device
    │                                   └── gpt_device ──────── mounted_glim
    │                                                                └── installed_glim
    disk_image_2 ────────────────► loop_device_2
    │                                   └── gpt_device_with_data        (exFAT, default)
    │
    disk_image_3 ────────────────► loop_device_3
    │                                   └── gpt_device_with_data_ext4   (ext4, explicit)
    │
    legacy_disk_image ───────────► legacy_loop_device
                                        ├── simple_device      (glim-partition.sh default mode)
                                        ├── legacy_device      (hand-crafted MBR via sfdisk)
                                        └── mounted_legacy_glim
                                                └── installed_legacy_glim
```

### Test files

| File | What it tests |
|------|--------------|
| `test_partition.py` | `glim-partition.sh` output: partition count, types, filesystem labels, MBR vs GPT |
| `test_install.py` | `glim.sh` install: GRUB files, grub.cfg content, EFI binary in ESP, boot/iso dirs |
| `test_boot.py` | QEMU smoke test: GRUB prompt appears over serial console (BIOS + UEFI) |

### Boot tests

Boot tests (`@pytest.mark.boot`) launch `qemu-system-x86_64` with the
installed disk image and watch the serial output for `"GRUB"`.  They
require QEMU and OVMF firmware but no network and no live ISO.

The GRUB config is patched before booting to redirect output to the
serial console (`terminal_output serial console`) so QEMU's
`-nographic` mode captures it.

Boot tests are excluded from `--fast` runs.  Use `--boot` to run them
in isolation or omit the flag to run everything.

## What each test class verifies

### `TestSimpleLayout` — default FAT32 mode

Verifies that `glim-partition.sh /dev/sdX` (no flags) produces:

- Exactly one partition
- MBR (not GPT) partition table
- FAT32 filesystem with label `GLIM`

### `TestGptLayout` — `--gpt` mode

Verifies the three-partition GPT layout:

- P1 BIOS Boot (type `ef02`)
- P2 EFI System Partition (type `ef00`, FAT32)
- P3 GLIM (Linux filesystem type, ext4, label `GLIM`)

### `TestGptLayoutWithData` — `--gpt --data-size` (exFAT default)

Verifies the four-partition layout with exFAT GLIMDATA (the default):

- P4 formatted as exFAT with label `GLIMDATA`
- P3 (GLIM) is smaller than in the three-partition case (space was reserved for P4)
- P4 size is within 5% of the requested size

### `TestGptLayoutWithDataExt4` — `--gpt --data-size --data-fs ext4`

Verifies the four-partition layout with an explicit ext4 GLIMDATA:

- P4 formatted as ext4 with label `GLIMDATA`

### `TestSafetyChecks`

- Abort on non-`yes` confirmation
- Reject a non-block-device path
- `--data-size` without `--gpt` auto-enables GPT
- `--data-fs` with an unsupported value (e.g. `ntfs`) is rejected before prompting

### `TestGptInstall` / `TestLegacyInstall`

Run `glim.sh` against a pre-partitioned loop device and check:

- Non-zero exit code means failure
- `grub.cfg` is installed under `boot/grub/` or `boot/grub2/`
- MBR is not all-zero (BIOS GRUB embedded)
- `EFI/BOOT/BOOTX64.EFI` exists in the ESP
- `boot/iso/` and at least 10 distro subdirectories are created
- `boot/grub/` contains ≥ 30 `inc-*.cfg` files

### `TestBiosBoot` / `TestUefiBoot`

Boot the disk image in QEMU and assert `"GRUB"` appears within 45–60
seconds on the serial console.

## Adding tests

1. Add fixtures to `conftest.py` if you need a new device configuration.
2. Add test classes/functions to the relevant `test_*.py` file.
3. Mark slow tests with `@pytest.mark.boot` if they require QEMU.
4. Run `uv run tests/run.py --fast` to validate before pushing.

## Cleaning up after interrupted runs

If a test run is interrupted, loop devices and mounts may be left
behind.  Clean up with:

```bash
grep '/var/tmp/glim-tests' /proc/mounts | awk '{print $2}' | sort -r | xargs -r sudo umount
sudo losetup -D
rm -rf /var/tmp/glim-tests
```

`tests/run.py` does this automatically at startup (unless active mounts
are detected, in which case it warns rather than wiping).

Note: `glim-partition.sh` also creates a short-lived mount in `/tmp` when
formatting an ext4 GLIMDATA partition (to `chmod 1777` the root).  If the
script is interrupted at that point, clean up with:

```bash
grep 'loop.*p4' /proc/mounts | awk '{print $2}' | xargs -r sudo umount
```
