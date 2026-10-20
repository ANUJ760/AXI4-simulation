"""Judge actual simulator output; no generated pass transcripts."""
import re


def smoke_passed(output, returncode):
    if returncode != 0:
        return False
    if "UVM running: factory item and virtual interface checked" not in output:
        return False
    for severity in ("UVM_ERROR", "UVM_FATAL"):
        summaries = re.findall(rf"^{severity}\s*:\s*(\d+)\s*$", output,
                               flags=re.MULTILINE)
        if not summaries or any(int(count) for count in summaries):
            return False
        if re.search(rf"^{severity}\s+@", output, re.MULTILINE):
            return False
    return "UVM Report Summary" in output
