"""Run the mandatory real-SystemVerilog UVM gate."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

from common import PINS, ROOT, run_logged
from smoke_verdict import smoke_passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    build = ROOT / "build/uvm-smoke" / str(args.seed)
    build.mkdir(parents=True, exist_ok=True)
    simulator = os.environ.get("VERILATOR", str(ROOT / ".tools/verilator/bin/verilator"))
    uvm = Path(os.environ.get("UVM_HOME", ROOT / ".tools/uvm/src")).resolve()
    if not shutil.which(simulator) or not (uvm / "uvm_pkg.sv").is_file():
        (build / "preflight.log").write_text(
            f"BLOCKED: require Verilator at {simulator} and UVM package in {uvm}\n")
        print(f"BLOCKED: missing simulator/UVM; see {build / 'preflight.log'}")
        return 1
    version = subprocess.check_output([simulator, "--version"], text=True)
    if not re.search(rf"\b{re.escape(PINS['verilator']['version'])}\b", version):
        print(f"BLOCKED: expected pinned simulator; found {version.strip()}")
        return 1
    version_file = uvm / "base/uvm_version.svh"
    expected_uvm = f'UVM:{PINS["uvm"]["version"]}'
    if not version_file.is_file() or expected_uvm not in version_file.read_text():
        print(f"BLOCKED: UVM_HOME must contain pinned {expected_uvm}")
        return 1
    (build / "versions.log").write_text(
        f"{version.strip()}\nUVM_HOME={uvm}\n{expected_uvm}\nSEED={args.seed}\n")
    obj = build / "obj"
    compile_cmd = [simulator, "--binary", "--timing", "--assert", "-j", str(args.jobs),
                   "-Wno-fatal", "+define+UVM_NO_DPI", f"+incdir+{uvm}",
                   "+incdir+tb/smoke", str(uvm / "uvm_pkg.sv"),
                   "-f", "tb/smoke/files.f", "--top-module", "tb_top",
                   "--Mdir", str(obj)]
    code = run_logged(compile_cmd, build / "compile.log", timeout=1800)
    if code:
        print("FAIL: UVM compilation; inspect compile.log")
        return code
    code = run_logged([str(obj / "Vtb_top"), f"+verilator+seed+{args.seed}"],
                      build / "run.log", timeout=60)
    output = (build / "run.log").read_text()
    passed = smoke_passed(output, code)
    print(output)
    print(f"UVM smoke {'PASS' if passed else 'FAIL'}; seed={args.seed}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
