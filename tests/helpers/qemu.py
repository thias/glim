"""
QEMU boot helper for GLIM tests.

Boots a disk image headlessly with serial console output, waits for a set of
expected strings to appear (or a timeout), then returns the collected output.

Usage::

    from helpers.qemu import QemuBoot

    with QemuBoot.bios(disk_image_path) as q:
        output = q.wait_for("GLIM", timeout=30)
    assert "Ubuntu" in output
"""

import os
import re
import select
import signal
import subprocess
import time

# OVMF firmware for UEFI testing
_OVMF_CANDIDATES = [
    "/usr/share/OVMF/OVMF_CODE_4M.fd",
    "/usr/share/OVMF/OVMF_CODE.fd",
    "/usr/share/ovmf/OVMF.fd",
    "/usr/share/qemu/OVMF.fd",
    "/usr/share/edk2/ovmf/OVMF_CODE.fd",
]

_QEMU = "qemu-system-x86_64"

# How long (seconds) to wait for expected strings before giving up
_DEFAULT_TIMEOUT = 45


def _find_ovmf():
    for path in _OVMF_CANDIDATES:
        if os.path.isfile(path):
            return path
    raise FileNotFoundError(
        "OVMF firmware not found. Install the 'ovmf' package.\n"
        f"Searched: {_OVMF_CANDIDATES}"
    )


class QemuBoot:
    """
    Context manager that boots a QEMU instance and captures its serial output.

    Do not instantiate directly — use the :meth:`bios` or :meth:`uefi` class
    methods.
    """

    def __init__(self, cmd):
        self._cmd = cmd
        self._proc = None
        self._output = ""

    # ------------------------------------------------------------------
    # Factory methods
    # ------------------------------------------------------------------

    @classmethod
    def bios(cls, disk_image):
        """Boot *disk_image* in legacy BIOS mode."""
        cmd = [
            _QEMU,
            "-drive", f"file={disk_image},format=raw,if=ide",
            "-m", "512",
            # -nographic disables VGA and redirects the first serial port to
            # stdin/stdout; no separate -serial flag needed (would conflict).
            "-nographic",
            "-no-reboot",
            "-boot", "c",
        ]
        return cls(cmd)

    @classmethod
    def uefi(cls, disk_image):
        """Boot *disk_image* in UEFI mode using OVMF."""
        ovmf = _find_ovmf()
        cmd = [
            _QEMU,
            "-drive", f"if=pflash,format=raw,readonly=on,file={ovmf}",
            "-drive", f"file={disk_image},format=raw,if=ide",
            "-m", "512",
            "-nographic",
            "-no-reboot",
        ]
        return cls(cmd)

    # ------------------------------------------------------------------
    # Context manager
    # ------------------------------------------------------------------

    def __enter__(self):
        self._proc = subprocess.Popen(
            self._cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
        )
        return self

    def __exit__(self, *_):
        if self._proc and self._proc.poll() is None:
            self._proc.send_signal(signal.SIGTERM)
            try:
                self._proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._proc.kill()
                self._proc.wait()

    # ------------------------------------------------------------------
    # Output collection
    # ------------------------------------------------------------------

    def wait_for(self, *expected, timeout=_DEFAULT_TIMEOUT):
        """
        Read serial output until *all* strings in *expected* have appeared,
        or *timeout* seconds have elapsed.

        Returns the full collected output string.
        Raises TimeoutError if the deadline is reached before all strings appear.
        """
        deadline = time.monotonic() + timeout
        found = set()
        needed = set(expected)

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break

            ready, _, _ = select.select([self._proc.stdout], [], [], min(remaining, 0.5))
            if ready:
                chunk = self._proc.stdout.read(4096)
                if not chunk:
                    break   # EOF — QEMU exited
                text = chunk.decode("utf-8", errors="replace")
                self._output += text
                for s in needed - found:
                    if s in self._output:
                        found.add(s)
                if found == needed:
                    return self._output

            if self._proc.poll() is not None:
                break   # QEMU exited unexpectedly

        missing = needed - found
        raise TimeoutError(
            f"Timed out after {timeout}s waiting for: {missing!r}\n"
            f"--- Collected output ---\n{self._output}"
        )

    @property
    def output(self):
        """Return all output collected so far."""
        return self._output
