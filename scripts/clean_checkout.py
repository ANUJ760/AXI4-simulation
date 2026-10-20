"""Verify committed sources in an empty temporary checkout using pinned installed tools."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    build = ROOT / "build/clean-checkout"
    build.mkdir(parents=True, exist_ok=True)
    result = {"passed": False, "stage": "preflight", "seed": args.seed,
              "tools_reused": True,
              "scope": "Empty checkout and build directories; same pinned installed toolchain"}
    result_file = build / "result.json"
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    result["source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    simulator = Path(os.environ.get("VERILATOR", ROOT / ".tools/verilator/bin/verilator")).resolve()
    uvm = Path(os.environ.get("UVM_HOME", ROOT / ".tools/uvm/src")).resolve()
    with tempfile.TemporaryDirectory(prefix="axi4lite-clean-") as temporary:
        location = Path(temporary)
        archive = location / "source.tar"
        with archive.open("wb") as stream:
            subprocess.run(["git", "archive", "HEAD"], cwd=ROOT, stdout=stream, check=True)
        checkout = location / "repo"
        checkout.mkdir()
        with tarfile.open(archive) as source:
            source.extractall(checkout, filter="data")
        if (checkout / "build").exists() or (checkout / ".tools").exists():
            raise RuntimeError("Clean archive unexpectedly contains generated outputs")
        variables = [f"VERILATOR={simulator}", f"UVM_HOME={uvm}",
                     f"SEED={args.seed}", f"JOBS={args.jobs}"]
        for target in ("env-check", "lint", "test-rtl", "test-uvm"):
            result["stage"] = target
            result_file.write_text(json.dumps(result, indent=2) + "\n")
            code = run_logged(["make", target, *variables], build / f"{target}.log",
                              cwd=checkout, timeout=1900)
            if code:
                result["exit_status"] = code
                result_file.write_text(json.dumps(result, indent=2) + "\n")
                return code
        for name, source_path in (
            ("rtl", checkout / "build/rtl" / str(args.seed)),
            ("uvm", checkout / "build/uvm/timer_full_test" / str(args.seed)),
        ):
            output = build / name
            output.mkdir(exist_ok=True)
            for filename in ("compile.log", "run.log", "result.json", "versions.log"):
                shutil.copyfile(source_path / filename, output / filename)
            checked = json.loads((source_path / "result.json").read_text())
            if checked.get("passed") is not True:
                raise RuntimeError(f"Clean {name} test did not pass")
            result[name] = checked
        result.update(passed=True, stage="complete", exit_status=0)
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Clean source checkout PASS commit={result['source_commit']}; reused pinned tools explicitly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
