"""Compile and execute the real timer UVM environment with strict evidence checks."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil

from common import PINS, ROOT, run_logged
from uvm_report import clean_report, report_counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--test", default="timer_core_test")
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", args.test):
        parser.error("test must be a SystemVerilog identifier")
    build = ROOT / "build/uvm" / args.test / str(args.seed)
    build.mkdir(parents=True, exist_ok=True)
    result_file = build / "result.json"
    result = {"passed": False, "seed": args.seed, "test": args.test, "stage": "preflight"}

    def save_result():
        result_file.write_text(json.dumps(result, indent=2) + "\n")

    save_result()
    waveform = build / "timer.vcd"
    waveform.unlink(missing_ok=True)
    simulator = os.environ.get("VERILATOR", str(ROOT / ".tools/verilator/bin/verilator"))
    uvm = Path(os.environ.get("UVM_HOME", ROOT / ".tools/uvm/src")).resolve()
    version_file = uvm / "base/uvm_version.svh"
    expected_uvm = f'"Accellera:1800.2:UVM:{PINS["uvm"]["version"]}"'
    if (not shutil.which(simulator) or not (uvm / "uvm_pkg.sv").is_file()
            or not version_file.is_file() or expected_uvm not in version_file.read_text()):
        (build / "preflight.log").write_text(f"BLOCKED: require pinned Verilator/UVM at {simulator}, {uvm}\n")
        print(f"BLOCKED: missing pinned simulator/UVM; inspect {build / 'preflight.log'}")
        return 1
    code = run_logged([simulator, "--version"], build / "versions.log", timeout=20)
    if code:
        result["exit_status"] = code
        save_result()
        return code
    if not re.search(rf"\b{re.escape(PINS['verilator']['version'])}\b",
                     (build / "versions.log").read_text()):
        print("BLOCKED: simulator version differs from project pin")
        return 1
    with (build / "versions.log").open("a") as log:
        log.write(f"UVM_HOME={uvm}\nUVM_VERSION={PINS['uvm']['version']}\nSEED={args.seed}\n")
    result["stage"] = "compile"
    save_result()
    command = [simulator, "--binary", "--timing", "--assert", "--trace-vcd",
               "--timescale", "1ns/1ps", "-j", str(args.jobs), "-Wno-fatal",
               "+define+UVM_NO_DPI", f"+incdir+{uvm}", "+incdir+tb/uvm",
               str(uvm / "uvm_pkg.sv"), "-f", "tb/uvm/files.f",
               "--top-module", "top", "--Mdir", str(build / "obj")]
    code = run_logged(command, build / "compile.log", timeout=1800)
    if code:
        result["exit_status"] = code
        save_result()
        return code
    result["stage"] = "run"
    save_result()
    command = [str(build / "obj/Vtop"), f"+UVM_TESTNAME={args.test}",
               f"+verilator+seed+{args.seed}", f"+WAVE={waveform}"]
    code = run_logged(command, build / "run.log", timeout=60)
    output = (build / "run.log").read_text()
    print(output)
    match = re.search(r"SUMMARY writes=(\d+) reads=(\d+) irq_checks=(\d+) "
                      r"completions=(\d+) resets=(\d+) cancelled_writes=(\d+) "
                      r"cancelled_reads=(\d+)", output)
    scoreboard = None
    if match:
        scoreboard = dict(zip(("writes", "reads", "irq_checks", "completions", "resets",
                               "cancelled_writes", "cancelled_reads"),
                              map(int, match.groups())))
    passed = (clean_report(output, code) and scoreboard is not None
              and all(scoreboard[key] > 0 for key in ("writes", "reads", "irq_checks"))
              and "UVM bus sequences completed" in output
              and waveform.is_file() and waveform.stat().st_size > 0)
    result.update(passed=passed, stage="complete", exit_status=code,
                  uvm_report=report_counts(output), scoreboard=scoreboard,
                  waveform=str(waveform.relative_to(ROOT)))
    save_result()
    print(f"UVM timer {'PASS' if passed else 'FAIL'} test={args.test} seed={args.seed}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
