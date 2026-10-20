"""Shared, standard-library-only build helpers."""
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PINS = json.loads((ROOT / "config/toolchain.json").read_text())


def run_logged(command, log, *, cwd=ROOT, timeout=600):
    """Preserve output and the actual exit status, including timeout failures."""
    log = Path(log)
    log.parent.mkdir(parents=True, exist_ok=True)
    print(f"$ {shlex.join(map(str, command))}", flush=True)
    with log.open("w") as output:
        output.write(f"$ {shlex.join(map(str, command))}\n")
        output.flush()
        try:
            result = subprocess.run(command, cwd=cwd, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=timeout,
                                    env={k: v for k, v in os.environ.items()
                                         if k != "VERILATOR_ROOT"})
            code = result.returncode
        except subprocess.TimeoutExpired:
            output.write(f"\nTIMEOUT after {timeout} seconds\n")
            code = 124
        except OSError as error:
            output.write(f"\n{error}\n")
            code = 127
        output.write(f"\nEXIT_STATUS={code}\n")
    print(f"exit={code}; log={log.relative_to(ROOT)}", flush=True)
    return code
