"""Synthesize the timer with Yosys and simulate the generated netlist."""
import argparse
import hashlib
import json
import sys

from common import ROOT, run_logged


def flatten_package(destination):
    """Inline only declaration scope and translate the helper's final return."""
    package = (ROOT / "rtl/axi4lite_timer_pkg.sv").read_text()
    source = (ROOT / "rtl/axi4lite_timer.sv").read_text()
    header = "package axi4lite_timer_pkg;"
    trailer = "endpackage"
    if not package.startswith(header) or not package.rstrip().endswith(trailer):
        raise ValueError("Unexpected package layout; adapter requires review")
    declarations = package[len(header):package.rfind(trailer)]
    if declarations.count("return merged;") != 1:
        raise ValueError("Unexpected function return; adapter requires review")
    declarations = declarations.replace("return merged;", "merge_bytes = merged;")
    import_line = "  import axi4lite_timer_pkg::*;"
    if source.count(import_line) != 1:
        raise ValueError("Unexpected package import; adapter requires review")
    destination.write_text(source.replace(import_line, declarations, 1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if args.jobs < 1 or not 1 <= args.seed <= 0xFFFFFFFF:
        parser.error("jobs must be positive; seed must be in 1..4294967295")
    build = ROOT / "build/synth"
    build.mkdir(parents=True, exist_ok=True)
    result = {"passed": False, "stage": "preflight", "seed": args.seed}
    result_file = build / "result.json"

    def save():
        result_file.write_text(json.dumps(result, indent=2) + "\n")

    save()
    code = run_logged(["yosys", "-V"], build / "versions.log")
    if code:
        return code
    native = "read_verilog -sv rtl/axi4lite_timer_pkg.sv rtl/axi4lite_timer.sv; hierarchy -check -top axi4lite_timer"
    native_code = run_logged(["yosys", "-Q", "-T", "-p", native], build / "native-frontend.log")
    result["native_package_supported"] = native_code == 0
    source = ROOT / "rtl/axi4lite_timer.sv"
    if native_code:
        source = build / "axi4lite_timer_flat.sv"
        flatten_package(source)
        result["adapter"] = "Inline package declarations; convert sole final function return to assignment"
        result["stage"] = "adapter_verification"
        save()
        command = [sys.executable, "scripts/rtl_check.py", "test", "--rtl-source", str(source),
                   "--variant", "synthesis-adapter", "--seed", str(args.seed), "--jobs", str(args.jobs)]
        code = run_logged(command, build / "adapter-verification.log", timeout=600)
        if code:
            return code
    else:
        result["adapter"] = None
    result["synthesis_source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
    result["stage"] = "synthesis"
    save()
    # All generated paths are controlled by this script, not shell interpolation.
    def quoted(path):
        return '"' + str(path).replace('\\', '\\\\').replace('"', '\\"') + '"'
    commands = []
    if native_code == 0:
        commands.append("read_verilog -sv rtl/axi4lite_timer_pkg.sv")
    commands += [f"read_verilog -sv {quoted(source)}", "hierarchy -check -top axi4lite_timer",
                 "synth -top axi4lite_timer", "check -assert",
                 f"tee -o {quoted(build / 'stat.json')} stat -json",
                 f"write_json {quoted(build / 'netlist.json')}",
                 f"write_verilog -noattr {quoted(build / 'netlist.v')}"]
    script = build / "synth.ys"
    script.write_text("\n".join(commands) + "\n")
    code = run_logged(["yosys", "-Q", "-T", "-s", str(script)], build / "synth.log")
    if code:
        return code
    result["statistics"] = json.loads((build / "stat.json").read_text())
    result["stage"] = "netlist_verification"
    save()
    command = [sys.executable, "scripts/rtl_check.py", "test", "--rtl-source", str(build / "netlist.v"),
               "--variant", "synthesized", "--seed", str(args.seed), "--jobs", str(args.jobs)]
    code = run_logged(command, build / "netlist-verification.log", timeout=600)
    result["passed"] = code == 0
    result["stage"] = "complete"
    result["netlist_verification_exit"] = code
    save()
    print(f"Synthesis and netlist verification {'PASS' if result['passed'] else 'FAIL'}; result={result_file.relative_to(ROOT)}")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
