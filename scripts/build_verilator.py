"""Build the pinned simulator without changing global packages or shell files."""
import argparse
import os
import subprocess

from common import ROOT, run_logged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("jobs must be positive")
    src = ROOT / ".tools/verilator-src"
    prefix = ROOT / ".tools/verilator"
    logs = ROOT / "build/toolchain"
    if not (src / "configure.ac").is_file():
        parser.error("run fetch_toolchain.py first")
    # Configure records the absolute prefix, so moving the checkout needs a rebuild.
    commands = [(["autoconf"], "autoconf.log"),
                (["./configure", f"--prefix={prefix}"], "configure.log"),
                (["make", "-j", str(args.jobs)], "build.log"),
                (["make", "install"], "install.log")]
    for command, name in commands:
        code = run_logged(command, logs / name, cwd=src, timeout=3600)
        if code:
            return code
    env = {k: v for k, v in os.environ.items() if k != "VERILATOR_ROOT"}
    return subprocess.run([str(prefix / "bin/verilator"), "--version"],
                          env=env, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
