# Gate 2: real UVM agent and independent checking

Date: 2026-10-20. Gate 2 PASS from actual implementation-owned commands:
`make test-uvm SEED=42 JOBS=2`, `make test-uvm-negative SEED=42 JOBS=2`.
The environment check, RTL lint, three-seed RTL regression and original UVM
smoke also passed again; see their logs in phase2/.

The real UVM environment contains transaction/cycle observation types, a
sequencer, independent AW/W driver threads, a passive pairing monitor,
a deadline-based reference model, an analysis-port scoreboard, connected
environment, directed/seeded sequences, test and top. Files are in tb/uvm/,
tb/top.sv, scripts/uvm_test.py, scripts/uvm_fault_check.py and
scripts/uvm_report.py. Make exposes test-uvm and test-uvm-negative.

Sampling contract: requests and response handshakes before rising-edge NBA;
responses/READY/IRQ after 1 ps; driver changes at falling edges. AR reads use
pre-edge state. Write expectations derive from independently accepted AW/W
halves, not B responses. Model COUNT derives from elapsed edge timestamps,
without reading DUT internal nets or calling the DUT byte merge helper.
The scoreboard predicts READY, response availability, held/accepted payloads,
IRQ and request/response accounting; expected held read data remains latched.

Positive result: 38 writes, 59 reads, 587 IRQ checks, 2 modeled completions,
2 observed reset epochs; zero UVM errors/fatals. The two guide-prescribed
UVM_NO_DPI warnings remain (name validation unavailable). Final compilation
has no Verilator warnings. See [result](phase2/42/result.json),
[run](phase2/42/run.log) and [trace](phase2/42/timer.vcd).

The testbench-only negative control flips bit 0 of valid RDATA on the public
bus, leaving RTL and reference model unchanged. It produces 242 UVM errors,
including MODEL_MISMATCH RDATA, and the strict test runner exits 1. The
negative-control wrapper requires those actual diagnostics to declare the
fault detected. See [negative result](phase2/42/read-fault/negative-result.json)
and [negative run](phase2/42/read-fault/run.log). This is not counted as one
of the three later required RTL mutations.

Known limits at this gate: no functional covergroups yet, no class-constrained
random suite yet, and UVM bus-reset-in-flight cases remain for Gate 3.
The RTL-only suite already covers bus reset stages. No synthesis or RTL
mutation campaign has been executed. GitHub Actions has not run remotely.
Toolchain remains pinned Verilator 5.052 / UVM 2020.3.2 on Fedora 44. No new
packages were installed. Artifacts and SHA256 manifest are in phase2/.

Supervisor review requested in the locked append-only coordination log;
Gate 1 feedback was assessed without substituting PASS for actual execution.
Next: Gate 3 coverage, constrained randomization and full UVM matrix, then
Gate 4 mutations, regressions, synthesis where supported and final delivery.
