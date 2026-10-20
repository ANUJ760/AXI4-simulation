# AXI4-Lite timer with UVM verification

A synthesizable 32-bit AXI4-Lite one-shot timer and reusable SystemVerilog/UVM
environment, implemented to `AXI4_Lite_UVM_Agent_Guide_REPAIRED.docx`.

All five implementation gates have executed locally. The project includes
independent AW/W buffering, persistent B/R responses, byte strobes, precise
captured-period timing, reset cancellation, sticky DONE and IRQ gating.
Verification includes a passive monitor, independent timestamp-based model,
scoreboard, protocol SVA, real covergroups, constrained-random sequences,
three detected RTL mutations and a tested synthesized netlist.

| Offset | Register | Behavior |
| --- | --- | --- |
| 0x00 | CONTROL | START pulse bit 0; IRQ_EN RW bit 1 |
| 0x04 | PERIOD | 32-bit RW, byte-masked |
| 0x08 | COUNT | RO elapsed cycles; retains final count |
| 0x0C | STATUS | DONE W1C bit 0; BUSY RO bit 1 |
| 0x10 | ID | RO 0xA11E0001 |

## Setup and run

Use [Fedora setup](docs/SETUP.md) for system prerequisites. No Python packages
are needed. The project pins Verilator 5.052 and UVM 2020.3.2.

```sh
make packages
make toolchain JOBS=2
make env-check
make uvm-smoke SEED=42 JOBS=2
make lint
make regress-rtl JOBS=2
make regress SEED=42 JOBS=2
make mutation-checks SEED=42 JOBS=2
make coverage
make synth SEED=42 JOBS=2
make clean-checkout SEED=42 JOBS=2
```

For one full UVM run use `make test-uvm SEED=42`; for the core round-trip use
`make test-uvm TEST=timer_core_test SEED=42`. The separate
`make test-uvm-negative SEED=42` verifies deliberate RDATA corruption detection.
Use `make help` and [quality commands](docs/QUALITY.md) for details.

The final UVM matrix passes seeds 42, 1042 and 2026 with 1,185 completed
transactions. All 47 planned functional bins are hit; each defined covergroup
reports 100% from the simulator. This is scoped functional coverage, not code,
formal or hardware signoff. Two UVM_NO_DPI warnings remain. Yosys uses a
verified syntax adapter; its 728-cell generic netlist passes the RTL suite.

See the [final report](reports/FINAL_REPORT.md) for actual counts, logs, traces,
versions, faults, native coverage and limitations. A clean source checkout with
empty build directories also passes using the pinned installed toolchain.

## Source and evidence

- [Architecture and sampling](docs/ARCHITECTURE.md).
- [Register/timing priorities](docs/RTL_BEHAVIOR.md).
- [Verification matrix and exclusions](docs/VERIFICATION_PLAN.md).
- [Gate 4 evidence](reports/phase4/), including the [VCD trace](reports/phase4/uvm/42/timer.vcd).
- [Append-only coordination log](.agent-coordination/COMMUNICATION.md).

`.tools/` holds downloaded tool sources/installations; `build/` holds generated
C++, objects and raw outputs. Both are ignored. Selected actual evidence is
versioned in `reports/`. CI executes the same gates and uploads artifacts; a
remote CI run has not been performed as part of local delivery.
