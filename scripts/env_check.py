"""Inspect tools without installing or modifying anything."""
import os
from pathlib import Path
import shutil
import subprocess

from common import PINS, ROOT

TOOLS = {
    "git": ["--version"], "gcc": ["--version"], "g++": ["--version"],
    "make": ["--version"], "autoconf": ["--version"],
    "automake": ["--version"], "flex": ["--version"],
    "bison": ["--version"], "help2man": ["--version"],
    "perl": ["-e", "print qq(perl $^V\n)"], "python3": ["--version"],
    "iverilog": ["-V"], "yosys": ["-V"], "z3": ["--version"],
    "curl": ["--version"], "tar": ["--version"],
}


def main():
    print(Path("/etc/os-release").read_text().strip())
    missing = []
    tools = dict(TOOLS)
    tools[os.environ.get("VERILATOR", "verilator")] = ["--version"]
    for tool, args in tools.items():
        path = shutil.which(tool)
        if not path:
            print(f"MISSING: {tool}")
            missing.append(tool)
            continue
        result = subprocess.run([path, *args], capture_output=True, text=True,
                                timeout=20)
        lines = (result.stdout + result.stderr).strip().splitlines()
        print(f"{tool}: {path}: {lines[0] if lines else '(no version output)'}")
        if result.returncode:
            missing.append(tool)
    # GUI applications should not be launched on a headless CI worker.
    print(f"gtkwave (optional GUI): {shutil.which('gtkwave') or 'MISSING'}")
    uvm = Path(os.environ.get("UVM_HOME", ROOT / ".tools/uvm/src"))
    print(f"UVM_HOME: {uvm}; uvm_pkg.sv exists: {(uvm / 'uvm_pkg.sv').is_file()}")
    version_file = uvm / "base/uvm_version.svh"
    expected = f'"Accellera:1800.2:UVM:{PINS["uvm"]["version"]}"'
    if not version_file.is_file() or expected not in version_file.read_text():
        print(f"MISSING/MISMATCH: UVM release {PINS['uvm']['version']}")
        missing.append("pinned UVM")
    if not (uvm / "uvm_pkg.sv").is_file():
        missing.append("UVM package")
    print(f"Environment {'BLOCKED' if missing else 'READY'}; missing={missing}")
    return bool(missing)


if __name__ == "__main__":
    raise SystemExit(main())
