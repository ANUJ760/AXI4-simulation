"""Deliberate, guarded RTL faults. Never alter the tracked DUT."""
import hashlib

from common import ROOT

MUTATIONS = {
    "bad_strobes": {
        "before": "period_reg <= merge_bytes(period_reg, write_data, write_strobes);",
        "after": "period_reg <= write_data;",
        "diagnostic": "RDATA",
        "description": "Ignore PERIOD byte selection on nonzero-strobe writes",
    },
    "early_done": {
        "before": "count_reg == active_period - 32'd1",
        "after": "count_reg == active_period - 32'd2",
        "diagnostic": "IRQ",
        "description": "Complete one edge early (and break period-one completion)",
    },
    "aw_w_coupling": {
        "before": "if (!aw_full && !s_axi_bvalid) s_axi_awready <= 1;",
        "after": "if (!aw_full && !s_axi_bvalid) s_axi_awready <= s_axi_wvalid;",
        "diagnostic": "AWREADY",
        "description": "Incorrectly gate free AW space with manager WVALID",
    },
}


def write_mutant(name, directory):
    source = ROOT / "rtl/axi4lite_timer.sv"
    original = source.read_text()
    mutation = MUTATIONS[name]
    if original.count(mutation["before"]) != 1:
        raise ValueError(f"Mutation {name} requires exactly one source match")
    changed = original.replace(mutation["before"], mutation["after"], 1)
    output = directory / "axi4lite_timer.sv"
    output.write_text(changed)
    return {"name": name, "description": mutation["description"],
            "before": mutation["before"], "after": mutation["after"],
            "diagnostic": mutation["diagnostic"],
            "baseline_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "mutant_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "source": str(output.relative_to(ROOT))}
