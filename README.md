# AXI4-Lite timer verification

Implementation follows `AXI4_Lite_UVM_Agent_Guide_REPAIRED.docx`.
The current deliverable is **Phase 0: the real UVM toolchain gate**, as required
by the guide §18. The timer RTL and reusable verification agent are planned
for subsequent gates.

```sh
make packages
make toolchain JOBS=2
make env-check
make uvm-smoke SEED=42 JOBS=2
```

See [Fedora setup](docs/SETUP.md), [gate acceptance](docs/PHASE0_PLAN.md),
[Phase 1 plan](docs/PHASE1_PLAN.md), and [actual results](reports/FINAL_REPORT.md).
Use `make help` for current targets. Phase 1–4 commands are not yet implemented.

The smoke uses actual UVM 2020.3.2 classes, factory registration, config_db,
a sequence item, a virtual interface and timed run-phase objections. Expected
probe data comes from the generated item; no pass transcript is synthesized.
Compilation and execution must succeed with zero UVM errors/fatals. This test
establishes simulator viability; it does not verify the eventual timer.

No Python packages are required. Sources/install files stay in `.tools/` and
raw logs/generated C++ stay in `build/`; both are ignored by Git. Selected
execution evidence is retained in `reports/`.
