"""Run the full UVM matrix over reproducible seeds, stopping on failure."""
import argparse
import json
import sys

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--seeds", type=int, nargs="+")
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    seeds = args.seeds or [args.seed, args.seed + 1000, args.seed + 1984]
    if args.jobs < 1 or any(not 1 <= seed <= 0xFFFFFFFF for seed in seeds):
        parser.error("jobs must be positive; seeds must be in 1..4294967295")
    if len(set(seeds)) != len(seeds):
        parser.error("seeds must be unique")
    build = ROOT / "build/uvm/regression"
    build.mkdir(parents=True, exist_ok=True)
    summary = {"passed": False, "requested_seeds": seeds, "results": []}
    summary_file = build / "summary.json"
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    for seed in seeds:
        command = [sys.executable, "scripts/uvm_test.py", "--test", "timer_full_test",
                   "--seed", str(seed), "--jobs", str(args.jobs)]
        code = run_logged(command, build / f"{seed}.log", timeout=1900)
        result_file = ROOT / "build/uvm/timer_full_test" / str(seed) / "result.json"
        result = json.loads(result_file.read_text()) if result_file.is_file() else {}
        summary["results"].append(result)
        if code or result.get("passed") is not True or result.get("seed") != seed:
            summary["failed_seed"] = seed
            summary_file.write_text(json.dumps(summary, indent=2) + "\n")
            print(f"UVM regression FAIL seed={seed}; log={build / f'{seed}.log'}")
            return code or 1
        summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    summary["passed"] = True
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"UVM regression PASS seeds={seeds}; summary={summary_file.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
