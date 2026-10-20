"""Detect three actual RTL faults, then restore and rerun the unchanged baseline."""
import argparse
import hashlib
import json
import sys

from common import ROOT, run_logged
from rtl_mutations import MUTATIONS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    build = ROOT / "build/mutations"
    build.mkdir(parents=True, exist_ok=True)
    original = ROOT / "rtl/axi4lite_timer.sv"
    baseline_hash = hashlib.sha256(original.read_bytes()).hexdigest()
    summary = {"passed": False, "seed": args.seed, "baseline_sha256": baseline_hash,
               "mutations": []}
    summary_file = build / "summary.json"
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    base = ROOT / "build/uvm/timer_full_test" / str(args.seed)
    for name, mutation in MUTATIONS.items():
        variant = base / "mutations" / name
        variant.mkdir(parents=True, exist_ok=True)
        (variant / "result.json").unlink(missing_ok=True)
        (variant / "run.log").unlink(missing_ok=True)
        command = [sys.executable, "scripts/uvm_test.py", "--test", "timer_full_test",
                   "--seed", str(args.seed), "--jobs", str(args.jobs), "--mutation", name]
        code = run_logged(command, build / f"{name}.log", timeout=1900)
        result_file = variant / "result.json"
        result = json.loads(result_file.read_text()) if result_file.is_file() else {}
        log = variant / "run.log"
        output = log.read_text() if log.is_file() else ""
        native = result.get("uvm_report") or {}
        detected = (code != 0 and result.get("stage") == "complete"
                    and result.get("passed") is False and result.get("mutation") == name
                    and native.get("UVM_ERROR", 0) > 0 and "[MODEL_MISMATCH]" in output
                    and mutation["diagnostic"] in output
                    and result.get("mutant", {}).get("baseline_sha256") == baseline_hash)
        summary["mutations"].append({"name": name, "detected": detected,
                                      "command_exit": code, "uvm_report": native,
                                      "mutant": result.get("mutant"),
                                      "evidence": str(variant.relative_to(ROOT))})
        summary_file.write_text(json.dumps(summary, indent=2) + "\n")
        print(f"Mutation {name}: {'DETECTED' if detected else 'NOT DETECTED'}")
        if hashlib.sha256(original.read_bytes()).hexdigest() != baseline_hash:
            raise RuntimeError("Tracked RTL changed during mutation campaign")
        if not detected:
            break
    # Restore the shared compiled simulator even if a mutant is not detected.
    command = [sys.executable, "scripts/uvm_test.py", "--test", "timer_full_test",
               "--seed", str(args.seed), "--jobs", str(args.jobs)]
    code = run_logged(command, build / "fixed-rerun.log", timeout=1900)
    fixed = json.loads((base / "result.json").read_text())
    summary["fixed_rerun"] = fixed
    summary["source_unchanged"] = hashlib.sha256(original.read_bytes()).hexdigest() == baseline_hash
    summary["passed"] = (len(summary["mutations"]) == len(MUTATIONS)
                         and all(r["detected"] for r in summary["mutations"])
                         and code == 0 and fixed.get("passed") is True
                         and summary["source_unchanged"])
    summary_file.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Mutation campaign {'PASS' if summary['passed'] else 'FAIL'}; summary={summary_file.relative_to(ROOT)}")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
