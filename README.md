# AXI4-Lite timer verification

A 32-bit AXI4-Lite one-shot timer, implemented to
`AXI4_Lite_UVM_Agent_Guide_REPAIRED.docx`.

**Gates 0 and 1 pass locally:** pinned Verilator 5.052 / UVM 2020.3.2 smoke,
strict RTL lint, synthesizable timer, protocol assertions and 19 directed/seeded
RTL groups across seeds 42, 1042 and 2026. The reusable UVM bus agent and
independent scoreboard are the next gate.

```sh
make packages
make toolchain JOBS=2
make env-check
make uvm-smoke SEED=42 JOBS=2
make lint
make test-rtl SEED=42 JOBS=2
make regress-rtl RTL_SEEDS="42 1042 2026" JOBS=2
```

The timer has independent AW/W buffering, persistent B/R responses, byte-masked
register writes, a captured one-shot period, sticky DONE and IRQ gating.
See [clock-edge and collision behavior](docs/RTL_BEHAVIOR.md).

RTL tests are separate from UVM. The real UVM smoke exercises the factory,
config_db, a sequence item, a virtual interface and timed objections. It does
not replace the still-pending UVM agent/model/scoreboard or functional coverage.
Two documented UVM warnings remain from the guide's `UVM_NO_DPI` setting.

See [Fedora setup](docs/SETUP.md), [current results](reports/FINAL_REPORT.md),
[Phase 2 plan](docs/PHASE2_PLAN.md), and [coordination log](.agent-coordination/COMMUNICATION.md).
Use `make help` for supported commands. `test-uvm`, UVM `regress`, functional
`coverage`, and `synth` targets are not implemented yet.

No Python packages are required. Sources/install files stay in `.tools/`;
generated C++, binaries and raw traces/logs stay in `build/`. Both are ignored
by Git. Selected actual evidence is retained in `reports/`, including
[seed 42's VCD trace](reports/phase1/42/timer.vcd).
