"""Summarize actual covergroup results and observed bins from the last regression."""
import json
import os
from pathlib import Path
import shutil

from common import ROOT, run_logged


def main():
    build = ROOT / "build/coverage"
    build.mkdir(parents=True, exist_ok=True)
    output = build / "summary.json"
    output.write_text(json.dumps({"passed": False, "stage": "preflight"}) + "\n")
    regression = ROOT / "build/uvm/regression/summary.json"
    if not regression.is_file():
        print("BLOCKED: run make regress before coverage")
        return 1
    runs = json.loads(regression.read_text())
    if runs.get("passed") is not True:
        print("FAIL: last UVM regression is incomplete or failed")
        return 1
    plan = json.loads((ROOT / "config/coverage_plan.json").read_text())
    bins = dict.fromkeys(plan["bins"], 0)
    raw = []
    percentages = []
    for result in runs["results"]:
        observed = result.get("coverage_bins", {})
        if set(observed) != set(bins):
            print(f"FAIL: planned/observed coverage bin names differ seed={result.get('seed')}")
            return 1
        if result.get("passed") is not True or result.get("injected_read_fault"):
            print("FAIL: failed or injected-fault runs cannot contribute coverage")
            return 1
        for name, count in observed.items():
            bins[name] += count
        percentages.append({"seed": result["seed"], "groups": result.get("covergroups", {})})
        raw_file = ROOT / "build/uvm/timer_full_test" / str(result["seed"]) / "coverage.dat"
        if not raw_file.is_file():
            print(f"FAIL: missing simulator-generated {raw_file}")
            return 1
        raw.append(str(raw_file))
    simulator = Path(os.environ.get("VERILATOR", ROOT / ".tools/verilator/bin/verilator"))
    coverage_tool = str(simulator.parent / "verilator_coverage")
    if not shutil.which(coverage_tool):
        print("BLOCKED: need verilator_coverage beside the simulator")
        return 1
    code = run_logged([coverage_tool, "--write", str(build / "merged.dat"), *raw],
                      build / "merge.log")
    if code:
        return code
    code = run_logged([coverage_tool, "--write-info", str(build / "merged.info"),
                       str(build / "merged.dat")], build / "lcov.log")
    if code:
        return code
    missing = sorted(name for name, hits in bins.items() if hits == 0)
    result = {"passed": not missing, "planned_bins": len(bins),
              "hit_bins": len(bins) - len(missing), "missing_bins": missing,
              "observed_bin_hits": bins, "per_run_simulator_covergroups": percentages,
              "exclusions": plan["exclusions"]}
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Coverage: {result['hit_bins']}/{len(bins)} tracked bins hit; missing={missing}")
    print(f"Simulator covergroup percentages: {percentages}")
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
