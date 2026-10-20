"""Lint or execute directed RTL tests without importing UVM."""
import argparse
import json
import os
from pathlib import Path
import re

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("lint", "test"))
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--rtl-source", type=Path)
    parser.add_argument("--variant", default="baseline")
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9-]*", args.variant):
        parser.error("variant must be an identifier")
    if args.rtl_source is not None and not args.rtl_source.is_file():
        parser.error("RTL source does not exist")
    simulator = os.environ.get("VERILATOR", str(ROOT / ".tools/verilator/bin/verilator"))
    build = ROOT / "build/rtl" / str(args.seed)
    if args.variant != "baseline":
        build = ROOT / "build/rtl/variants" / args.variant / str(args.seed)
    build.mkdir(parents=True, exist_ok=True)
    rtl_source = str(args.rtl_source.resolve()) if args.rtl_source else "rtl/axi4lite_timer.sv"
    rtl = ["rtl/axi4lite_timer_pkg.sv", rtl_source]
    if args.mode == "lint":
        return run_logged([simulator, "--lint-only", "--Wall", *rtl,
                           "--top-module", "axi4lite_timer"], build / "lint.log")
    result_file = build / "result.json"
    waveform = build / "timer.vcd"
    waveform.unlink(missing_ok=True)
    result = {"passed": False, "seed": args.seed, "stage": "preflight"}
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    code = run_logged([simulator, "--version"], build / "versions.log", timeout=20)
    if code:
        result["exit_status"] = code
        result_file.write_text(json.dumps(result, indent=2) + "\n")
        return code
    result["stage"] = "compile"
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    command = [simulator, "--binary", "--timing", "--assert", "--trace-vcd",
               "--timescale", "1ns/1ps",
               "-j", str(args.jobs), *rtl, "tb/axi_if.sv", "tb/axi_assertions.sv",
               "tests/rtl/timer_tb.sv",
               "--top-module", "timer_tb", "--Mdir", str(build / "obj")]
    code = run_logged(command, build / "compile.log", timeout=600)
    if code:
        result["exit_status"] = code
        result_file.write_text(json.dumps(result, indent=2) + "\n")
        return code
    command = [str(build / "obj/Vtimer_tb"), f"+verilator+seed+{args.seed}",
               f"+SEED={args.seed}", f"+WAVE={build / 'timer.vcd'}"]
    code = run_logged(command, build / "run.log", timeout=60)
    output = (build / "run.log").read_text()
    print(output)
    match = re.search(r"^RTL RESULT PASS seed=(\d+) groups=(\d+) checks=(\d+) "
                      r"writes=(\d+) reads=(\d+)$", output, re.MULTILINE)
    passed = (code == 0 and match is not None and int(match[1]) == args.seed
              and waveform.is_file() and waveform.stat().st_size > 0)
    result = {"passed": passed, "seed": args.seed, "exit_status": code,
              "stage": "complete", "rtl_source": rtl_source, "variant": args.variant,
              "waveform": str(waveform.relative_to(ROOT))}
    if match:
        result.update(zip(("groups", "checks", "writes", "reads"),
                          map(int, match.groups()[1:])))
    stalls = re.search(r"^STALLS aw=(\d+) w=(\d+) ar=(\d+) b=(\d+) r=(\d+)$",
                       output, re.MULTILINE)
    if stalls:
        result["stalled_cycles"] = dict(zip(("aw", "w", "ar", "b", "r"),
                                           map(int, stalls.groups())))
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
