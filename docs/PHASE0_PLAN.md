# Phase 0 execution plan

The supplied DOCX §§9A, 11, 13, 18 and 20–22 govern this implementation.
Implement Phase 0 first; do not write the full project before the gate passes.

Planned files: toolchain pins, dependency inspection and bootstrap scripts,
SystemVerilog smoke interface/item/test/top, Make targets, CI, setup docs,
and reports. Use Python's standard library only.

Commands: `make env-check`, `make toolchain`, `make uvm-smoke`.
Acceptance: pinned Verilator 5.052 and UVM 2020.3.2 provenance; actual compilation
and execution; factory-created item and virtual interface exercised; UVM report
with zero errors/fatals; explicit completion message; successful process exit.
Keep real command logs, including failures. A blocked gate stops the UVM track.

Next gate: register package, timer RTL, directed RTL tests, lint and handshake
checks. See PHASE1_PLAN.md. No RTL/UVM-agent completion is claimed in Phase 0.
