"""Judge actual smoke output; no generated pass transcripts."""
from uvm_report import clean_report


def smoke_passed(output, returncode):
    return (clean_report(output, returncode)
            and "UVM running: factory item and virtual interface checked" in output)
