# AXI4-Lite timer: final implementation report

Date: 2026-10-20. **Gates 0–4 have passed actual local execution.** The delivery
contains synthesizable timer RTL, real reusable UVM components, an independent
reference model/scoreboard, protocol SVA, functional covergroups, constrained
randomization, reproducible regressions, three detected RTL mutations,
synthesis/netlist checks, CI and a clean source-compilation check.

The authoritative behavior is the supplied DOCX Part A. No commercial tools,
Python verification substitutes, extra frameworks or physical hardware were
introduced. Detailed historical reports are preserved:
[Gate 0](PHASE0_REPORT.md), [Gate 1](PHASE1_REPORT.md),
[Gate 2](PHASE2_REPORT.md), [Gate 3](PHASE3_REPORT.md).

## Implementation and entry points

| Files | Purpose |
| --- | --- |
| `rtl/axi4lite_timer_pkg.sv` | Required offsets, encodings, fields, ID and byte merge helper |
| `rtl/axi4lite_timer.sv` | Independent AW/W buffers, held B/R responses, register bank and timer |
| `tb/axi_if.sv`, `tb/axi_assertions.sv` | Shared bus interface; stability, capacity, reset and pairing SVA; activity cover properties |
| `tb/uvm/axi_txn.sv` | Request types, bounded random constraints and immutable clock observations |
| `tb/uvm/axi_master_agent.sv` | Sequencer, independent AW/W driver threads, passive monitor and reset-cancel stimulus |
| `tb/uvm/timer_ref_model.sv` | Shadow registers and captured-period/deadline model from accepted bus requests |
| `tb/uvm/timer_scoreboard.sv` | Accepted/held response, READY, IRQ, cancellation and accounting checks |
| `tb/uvm/timer_coverage.sv` | Real covergroups and named observed-bin counters |
| `tb/uvm/timer_env.sv`, `timer_sequences.sv`, `timer_tests.sv`, `timer_tb_pkg.sv`, `files.f`, `tb/top.sv` | Connected UVM hierarchy, core/full scenarios, clock, watchdog and ordered compilation |
| `tests/rtl/timer_tb.sv` | Separate directed/seeded RTL suite and exact-edge/collision checks |
| `scripts/uvm_smoke.py`, `smoke_verdict.py`, `uvm_report.py` | Actual UVM smoke and strict severity parsing |
| `scripts/rtl_check.py`, `rtl_regress.py`, `uvm_test.py`, `uvm_regress.py`, `coverage.py` | Real lint/test execution, seeded regressions, traces, verdicts and native coverage merging |
| `scripts/rtl_mutations.py`, `mutation_checks.py`, `uvm_fault_check.py` | Guarded temporary RTL faults, actual detection and independent bus negative control |
| `scripts/synth.py`, `clean_checkout.py` | Verified syntax adapter, Yosys/netlist execution and source-only cold compilation |
| `scripts/common.py`, `env_check.py`, `check_packages.py`, `fetch_toolchain.py`, `build_verilator.py` | Logged commands/timeouts, dependencies and pinned local toolchain |
| `config/`, `Makefile`, `.github/workflows/ci.yml`, `.gitignore` | Pins, coverage scope, command entry points, CI and generated-output isolation |
| `docs/`, `README.md`, `AGENTS.md`, `.agent-coordination/COMMUNICATION.md` | Behavior, architecture, verification, setup and locked append-only coordination |
| `reports/phase0/` through `reports/phase4/` | Selected actual logs, native data, verdicts, traces, netlist and SHA256 manifests |

AW and W are accepted independently and paired once. Writes commit one clock
after the later handshake; B persists until consumed. Reads capture state before
the AR acceptance edge and hold RDATA/RRESP through backpressure. READY is
registered. One read and one write can overlap. START captures PERIOD and sets
COUNT=0; subsequent active edges increment to exact completion. DONE is sticky,
W1C clears it, IRQ follows DONE && IRQ_EN, and reset cancels requests/responses.
Completion dominates simultaneous DONE-clear; rejected START changes no written
fields. Full-address permission checks precede strobe handling. These choices
are documented in [RTL behavior](../docs/RTL_BEHAVIOR.md).

The driver has no register decoder. The monitor derives writes from actual
accepted AW/W events before looking at responses. The model uses clock-edge
timestamps instead of copying the DUT counter and uses its own bit-mask update
instead of the RTL helper. It has no DUT internal-net access. Expected read data
is latched at AR acceptance, then compared through stalls and consumption.

## Toolchain and environment

Fedora 44 x86_64; Verilator **5.052 (2026-09-05, v5.052)**; UVM
**Accellera:1800.2:UVM:2020.3.2**; Z3 **4.16.0**; Yosys **0.67+post**;
GCC/G++ **16.2.1**; Make **4.4.1**; Python **3.14.7**. Icarus 13.0 and GTKWave
are installed; RTL/UVM executions here use Verilator. Exact paths and remaining
build-tool versions are in [environment evidence](phase4/commands/environment.log).

Verilator commit: `ea338be98e1e838d3518809ce8899f85a009963c`.
Official UVM archive SHA256:
`4664ac015f23c72106dd785906aa874d70932ea63f74b85de1e32fa5339c15eb`.
The bootstrap verifies these identities and installs only under ignored `.tools/`.
Gate 0 built the toolchain from downloaded sources and ran actual UVM. The host's
minimal Perl initially lacked FindBin; the user installed Perl, and explicit
runtime-module preflights now pass. No Python packages were installed. No new
dependencies were added during Gates 1–4; shell startup/PATH files were not edited.

## Final commands and gate status

| Command/check | Actual result | Evidence |
| --- | --- | --- |
| `make packages`, `make env-check` | PASS | [packages](phase4/commands/packages.log), [environment](phase4/commands/environment.log) |
| `make uvm-smoke SEED=42 JOBS=2` | PASS; real factory/interface UVM execution | [smoke](phase4/commands/uvm-smoke.log) |
| `make lint` | PASS; `--Wall`, no warnings | [lint](phase4/rtl/lint.log) |
| `make regress-rtl JOBS=2` | PASS; seeds 42/1042/2026 | [RTL summary](phase4/rtl/regression.json) |
| `make regress SEED=42 JOBS=2` | PASS; full UVM matrix, seeds 42/1042/2026 | [UVM summary](phase4/uvm/regression.json) |
| `make coverage` | PASS; native merging and no planned misses | [coverage](phase4/coverage/summary.json) |
| `make test-uvm-negative SEED=42 JOBS=2` | PASS: ordinary test rejects actual RDATA corruption | [negative verdict](phase4/negative-control/negative-result.json) |
| `make mutation-checks SEED=42 JOBS=2` | PASS: three runtime detections and fixed rerun | [campaign](phase4/mutations/summary.json) |
| `make synth SEED=42 JOBS=2` | PASS through verified adapter; netlist simulation PASS | [synthesis](phase4/synth/result.json) |
| `make clean-checkout SEED=42 JOBS=2` | PASS from empty source/build storage; pinned tools reused | [cold compilation](phase4/clean-checkout/result.json) |
| Python syntax/import audit; Git whitespace; evidence hashes | PASS locally | [audit](phase4/python-audit.json), [hashes](phase4/SHA256SUMS.json) |
| GitHub Actions | Authored for all gates; NOT RUN remotely | [workflow](../.github/workflows/ci.yml) |

Gate 0 (toolchain), Gate 1 (RTL), Gate 2 (real UVM round-trip), Gate 3
(matrix/constraints/SVA/coverage) and Gate 4 (regressions/mutations/synthesis/
reproduction) are complete. The final command stack ran after mutation testing.
No supervisor verdict was used instead of executing a check.

## Measured positive results

Final full UVM matrix:

| Seed | Checked writes | Checked reads | IRQ samples | Timer completions | Reset epochs |
| --- | --- | --- | --- | --- | --- |
| 42 | 178 | 217 | 3105 | 10 | 9 |
| 1042 | 178 | 217 | 3130 | 10 | 9 |
| 2026 | 178 | 217 | 3144 | 10 | 9 |

**1185 completed transactions** in this final matrix, including 576
class-constrained read/write transactions (96 randomized duplex items per seed).
Each seed additionally cancels two pending B and two pending R responses through
reset; the scoreboard checks cancellation accounting. All positive runs have
zero UVM_ERROR/UVM_FATAL. Final compiles have no Verilator warnings. The two
UVM_NO_DPI warnings are recorded below.

The full sequence logs all 14 required functional scenario names: reset/ID,
strobes, AW-first, W-first, simultaneous AW/W, B/R backpressure, concurrent
read/write, invalid access, zero-period START, DONE/IRQ/W1C, period snapshot,
reset in flight and randomized stalls. The separate mutation campaign supplies
the required mutation_checks matrix row. All responses are checked by the model.

Separate RTL suite:

| Seed | Groups | Explicit checks | Completed writes | Completed reads |
| --- | --- | --- | --- | --- |
| 42 | 19 | 2523 | 136 | 157 |
| 1042 | 19 | 2704 | 136 | 157 |
| 2026 | 19 | 2568 | 136 | 157 |

Total **7795 explicit RTL checks**, plus enabled protocol assertions.
Additional cases verify asynchronous reset between edges, maximum-period early
counting, exact period-one completion, completion versus DONE clear, START on
completion and pre-edge read collisions. These counts are separate from the UVM
matrix and from adapter/netlist verification runs.

## Coverage scope and evidence

All **47/47 planned bins** have actual hits; missing bins: none.
Four simulator covergroups (address/operation, masks/order, responses, events)
report **100% each** on every recorded seed using get_inst_coverage(). This is
the defined functional scope. The 47 tracked bins count cross products without
double-counting marginal coverpoints; simulator group percentages retain their
normal coverpoint weighting. [Coverage plan](../config/coverage_plan.json) lists
exclusions. No code/toggle/FSM, formal or hardware coverage was measured.

Native merged SVA event counts: AW/W/AR stall antecedents 9/9/9; B stalls 2426;
R stalls 2516; accepted B/R responses 534/651; reset 81. Thus all five stability
antecedents and response/reset activity occur. Native [merged.dat](phase4/coverage/merged.dat)
and [LCOV data](phase4/coverage/merged.info) accompany the named hit counters.
Failed/injected-fault results are excluded from positive coverage aggregation.

Representative [UVM VCD](phase4/uvm/42/timer.vcd) is committed. Every seed also
has its raw local trace at `build/uvm/timer_full_test/<seed>/timer.vcd`; RTL traces
are `build/rtl/<seed>/timer.vcd`. Logs begin with exact compiler/runtime argv.
Failures retain seed, current scenario/transaction diagnostics and trace paths.

## Deliberate fault detection and repaired rerun

Each mutation is a generated copy of the real RTL, compiled into the actual UVM
simulator. Original/replacement text and SHA256 values are recorded. Compile or
preflight failures cannot count as detection. The tracked DUT is never edited.

| RTL fault | Causal model field | UVM errors / fatals | Test-runner exit | Result |
| --- | --- | --- | --- | --- |
| bad_strobes | RDATA | 288 / 0 | 1 | DETECTED |
| early_done | IRQ | 1946 / 0 | 1 | DETECTED |
| aw_w_coupling | AWREADY | 1035 / 1 | 1 | DETECTED |

The coupling case first reports AWREADY mismatches and later B_TIMEOUT. See
[actual first diagnostics](phase4/mutations/aw_w_coupling/first-diagnostics.log)
and its full run log; this is not an AW_TIMEOUT. The full normal design is
recompiled after the campaign and passes, followed by the final three-seed
regression. [Fixed rerun](phase4/mutations/fixed-rerun.log) and the campaign's
source_unchanged=true demonstrate restoration. The canonical RTL SHA256 remains
`cd22fefece84f55804d5d9fb20d12cb9e9cfa9edf2d51c1042127df96e4afbdd`.

The independent testbench-only RDATA bit flip produces 242 UVM errors and test
exit 1; its wrapper succeeds only after finding actual MODEL_MISMATCH RDATA.
It is separate from the three RTL faults. UVM may finish the simulator normally
after reporting errors, so runners require both process success and a clean
native UVM summary before a positive PASS verdict.

## Synthesis and source reproducibility

The installed Yosys native frontend rejects the canonical package function's
return syntax; [the failure is retained](phase4/synth/native-frontend.log).
A guarded adapter inlines exact package declarations and changes only the sole
final function return to its equivalent assignment form. The adapted RTL passes
all 19 groups / 2523 checks before synthesis. Yosys hierarchy checks, generic
synthesis and `check -assert` then pass.

The generic netlist has **728 cells**, including **208 flip-flops**,
with no latches or memories. [Statistics](phase4/synth/stat.json) and
[generated netlist](phase4/synth/netlist.v) are retained. The same RTL bench
passes 19 groups / 2523 checks against that netlist. These are generic synthesis
statistics and zero-delay functional tests; no process-specific area, clock
frequency, power, SDF timing or formal equivalence result is claimed.

The clean source check extracts git archive commit
`5ae253e8b157d0e64221f725b17ae5b16188e8d4` into a temporary directory with no .tools/ or build/
tree. It uses explicit paths to the pinned installed dependencies, executes
lint, RTL and full UVM compilation/run from empty object storage, and passes.
[Source integrity check](phase4/cold-source-integrity.json) confirms that the
current RTL/UVM source hashes are identical. It is not fresh-OS provisioning.
Diagnostics are retained, and temporary source/build storage is removed.
The retention helper is separately checked with actual saved diagnostic files.

## Resolved issues and known limits

Resolved: missing Perl FindBin runtime; explicit bench/randomize width and
lifetime declarations; packed-string padding in coverage names; FST compilation
requiring absent lz4.h (VCD used without an extra package); native Yosys syntax
limits; ABC history redirected into ignored build storage. Initial failures
are retained in the respective milestone folders, not relabeled as passing.

Remaining practical limits:

- The guide's UVM_NO_DPI mode reports NO_DPI_USED and NO_VISIT_CHECK. Component
  name validation and generic DPI-backed UVM CLI argument discovery are disabled.
  UVM_TESTNAME has the library's direct fallback; simulator seeds and explicit
  SystemVerilog plusargs work. An ineffective quit-count CLI option was removed.
- Verilator simulation is the executed backend; no second-simulator or four-state
  validation is claimed. Driver handshake watchdogs are 1000 cycles and the
  UVM top watchdog is 500 us. The full 0xffffffff timer duration was not simulated.
- Functional coverage is limited to the declared plan. No formal, CDC, physical
  timing, FPGA or silicon result is claimed. Synthesis needs the verified adapter
  on this Yosys version. Remote CI has not been executed.

## Reproduce and review

Start with [Fedora setup](../docs/SETUP.md), then execute the full command list in
[QUALITY.md](../docs/QUALITY.md). `make toolchain` fetches and verifies exact
upstream identities. No pip/npm framework or virtual environment is required.
Generated tools stay in .tools/ and compilation/traces in build/; both are
ignored. Selected actual evidence is versioned with integrity manifests.

The sole implementation agent owns code and Git state. Supervisor feedback is
read and assessed through the flock-protected append-only communication log,
including correction of a summary's timeout label. Review PASS never replaces
actual execution. The completed milestone is submitted for supervisor review;
all acceptance decisions above are backed by the retained tool results.
