"""Require the real scoreboard to reject an injected read-data corruption."""
import argparse
import json
import re
import sys

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    build = ROOT / "build/uvm/timer_core_test" / str(args.seed) / "read-fault"
    command = [sys.executable, "scripts/uvm_test.py", "--seed", str(args.seed),
               "--jobs", str(args.jobs), "--inject-read-fault"]
    code = run_logged(command, build / "check.log", timeout=1900)
    result_file = build / "result.json"
    result = json.loads(result_file.read_text()) if result_file.is_file() else {}
    output_file = build / "run.log"
    output = output_file.read_text() if output_file.is_file() else ""
    report = result.get("uvm_report") or {}
    detected = (code != 0 and result.get("stage") == "complete"
                and result.get("passed") is False and report.get("UVM_ERROR", 0) > 0
                and re.search(r"\[MODEL_MISMATCH\].*RDATA", output) is not None)
    evidence = {"detected": detected, "seed": args.seed, "test_command_exit": code,
                "uvm_report": report, "fault": "testbench RDATA bit flip"}
    (build / "negative-result.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"UVM negative control {'PASS' if detected else 'FAIL'} seed={args.seed}; "
          f"evidence={build.relative_to(ROOT)}")
    return 0 if detected else 1


if __name__ == "__main__":
    raise SystemExit(main())
