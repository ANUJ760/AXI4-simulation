"""Lint or execute directed RTL tests without importing UVM."""
import argparse
import json
import os
import re

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("lint", "test"))
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    simulator = os.environ.get("VERILATOR", str(ROOT / ".tools/verilator/bin/verilator"))
    build = ROOT / "build/rtl" / str(args.seed)
    build.mkdir(parents=True, exist_ok=True)
    rtl = ["rtl/axi4lite_timer_pkg.sv", "rtl/axi4lite_timer.sv"]
    if args.mode == "lint":
        return run_logged([simulator, "--lint-only", "--Wall", *rtl,
                           "--top-module", "axi4lite_timer"], build / "lint.log")
    command = [simulator, "--binary", "--timing", "--assert", "--timescale", "1ns/1ps",
               "-j", str(args.jobs), *rtl, "tb/axi_if.sv", "tb/axi_assertions.sv",
               "tests/rtl/timer_tb.sv",
               "--top-module", "timer_tb", "--Mdir", str(build / "obj")]
    code = run_logged(command, build / "compile.log", timeout=600)
    if code:
        return code
    command = [str(build / "obj/Vtimer_tb"), f"+verilator+seed+{args.seed}",
               f"+SEED={args.seed}"]
    code = run_logged(command, build / "run.log", timeout=60)
    output = (build / "run.log").read_text()
    print(output)
    match = re.search(r"^RTL RESULT PASS seed=(\d+) groups=(\d+) checks=(\d+) "
                      r"writes=(\d+) reads=(\d+)$", output, re.MULTILINE)
    passed = code == 0 and match is not None and int(match[1]) == args.seed
    result = {"passed": passed, "seed": args.seed, "exit_status": code}
    if match:
        result.update(zip(("groups", "checks", "writes", "reads"),
                          map(int, match.groups()[1:])))
    (build / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
