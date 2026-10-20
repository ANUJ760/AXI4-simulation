"""Parse the simulator's real UVM severity summary."""
import re


def report_counts(output):
    counts = {}
    for severity in ("UVM_INFO", "UVM_WARNING", "UVM_ERROR", "UVM_FATAL"):
        matches = re.findall(rf"^{severity}\s*:\s*(\d+)\s*$", output, re.MULTILINE)
        if len(matches) != 1:
            return None
        counts[severity] = int(matches[0])
    return counts


def clean_report(output, returncode):
    counts = report_counts(output)
    return (returncode == 0 and counts is not None and "UVM Report Summary" in output
            and counts["UVM_ERROR"] == 0 and counts["UVM_FATAL"] == 0)
