"""Fetch exactly the pinned sources into ignored project storage."""
import hashlib
import json
import shutil
import subprocess
import tarfile

from common import PINS, ROOT, run_logged


def main():
    tools = ROOT / ".tools"
    tools.mkdir(exist_ok=True)
    lock = json.loads((ROOT / "config/sources.lock.json").read_text())
    src = tools / "verilator-src"
    if not src.exists():
        code = run_logged(["git", "clone", "--depth", "1", "--branch",
                           PINS["verilator"]["tag"],
                           PINS["verilator"]["repository"], str(src)],
                          ROOT / "build/toolchain/clone.log")
        if code:
            return code
    actual = subprocess.check_output(["git", "-C", str(src), "rev-parse", "HEAD"],
                                     text=True).strip()
    if actual != lock["verilator_commit"]:
        raise SystemExit("BLOCKED: Verilator commit differs from source lock")
    archive = tools / "downloads/uvm-2020.3.2.tar.gz"
    archive.parent.mkdir(exist_ok=True)
    if not archive.exists():
        partial = archive.with_suffix(".part")
        code = run_logged(["curl", "--fail", "--location", "--retry", "2",
                           "--output", str(partial), PINS["uvm"]["url"]],
                          ROOT / "build/toolchain/download.log")
        if code:
            return code
        partial.rename(archive)
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if digest != lock["uvm_archive_sha256"]:
        raise SystemExit("BLOCKED: UVM archive SHA256 mismatch; do not extract")
    target = tools / "uvm"
    if not target.exists():
        staging = tools / "uvm-extract"
        staging.mkdir(exist_ok=True)
        with tarfile.open(archive) as source:
            source.extractall(staging, filter="data")
        packages = list(staging.rglob("uvm_pkg.sv"))
        if len(packages) != 1:
            raise SystemExit("BLOCKED: expected exactly one UVM package")
        shutil.move(str(packages[0].parent.parent), target)
        staging.rmdir()
    version = target / "src/base/uvm_version.svh"
    if f'"Accellera:1800.2:UVM:{PINS["uvm"]["version"]}"' not in version.read_text():
        raise SystemExit("BLOCKED: extracted UVM library has wrong version")
    print(f"Verified Verilator {actual}; UVM archive SHA256 {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
