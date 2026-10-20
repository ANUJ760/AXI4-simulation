"""Run a reproducible RTL seed list, stopping at the first failed check."""
import argparse
import json
import sys

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=int, nargs="+", default=[42, 1042, 2026])
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1 or any(not 1 <= seed <= 0xFFFFFFFF for seed in args.seeds):
        parser.error("jobs must be positive; seeds must be in 1..4294967295")
    if len(set(args.seeds)) != len(args.seeds):
        parser.error("seeds must be unique")
    build = ROOT / "build/rtl/regression"
    build.mkdir(parents=True, exist_ok=True)
    results = []
    summary = {"passed": False, "requested_seeds": args.seeds, "results": results}
    summary_file = build / "summary.json"
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    for seed in args.seeds:
        command = [sys.executable, "scripts/rtl_check.py", "test", "--seed", str(seed),
                   "--jobs", str(args.jobs)]
        code = run_logged(command, build / f"{seed}.log", timeout=900)
        if code:
            summary["failed_seed"] = seed
            summary_file.write_text(json.dumps(summary, indent=2) + "\n")
            print(f"RTL regression FAIL seed={seed}; inspect {build / f'{seed}.log'}")
            return code
        result = json.loads((ROOT / "build/rtl" / str(seed) / "result.json").read_text())
        results.append(result)
        if result.get("passed") is not True or result.get("seed") != seed:
            summary["failed_seed"] = seed
            summary_file.write_text(json.dumps(summary, indent=2) + "\n")
            return 1
        summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    summary["passed"] = True
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"RTL regression PASS seeds={args.seeds}; summary={summary_file.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
