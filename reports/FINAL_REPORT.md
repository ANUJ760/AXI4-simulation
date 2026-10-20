# AXI4-Lite timer: Gates 0 and 1 delivery report

Date: 2026-10-20. Gate 0 passed before timer work began. This milestone
implements Gate 1: synthesizable RTL, directed/seeded RTL verification and
protocol assertions. The original [Phase 0 report](PHASE0_REPORT.md) and
[its evidence](phase0/) are preserved. Full-project completion is not claimed.

## Changed files and behavior

| Files | Purpose |
| --- | --- |
| `rtl/axi4lite_timer_pkg.sv` | Register offsets, response codes, field positions, ID and byte merge helper |
| `rtl/axi4lite_timer.sv` | Five-channel AXI4-Lite subordinate and one-shot timer |
| `tb/axi_if.sv` | Shared manager/monitor interface |
| `tb/axi_assertions.sv` | Payload/VALID stability, capacity, reset and response-pairing assertions |
| `tests/rtl/timer_tb.sv` | Pin-level directed cases and independent expected-value/timer checks |
| `scripts/rtl_check.py` | Strict lint, real RTL compilation/execution, VCD traces and structured verdicts |
| `scripts/rtl_regress.py` | Seed-list execution; stop on the first failure; retain actual result summary |
| `Makefile`, `.github/workflows/ci.yml` | RTL entry points and CI with log/JSON/VCD artifacts |
| `docs/RTL_BEHAVIOR.md`, setup/plans, `README.md` | Register timing, collision priorities, reproduction and next gate |
| `AGENTS.md`, `.agent-coordination/COMMUNICATION.md`, `.gitignore` | Persistent sole-agent rules and locked append-only review communication |
| `reports/phase1/` | Actual execution logs, seed results, representative trace and SHA256 manifest |

AW and W are buffered independently. Writes commit on the edge after both
handshakes, and B responses persist under backpressure. Reads sample register
state at AR acceptance and retain their response payload through stalls.
READY outputs are registered. One read and one write can overlap.

The timer captures PERIOD on accepted START, counts subsequent active edges,
retains its final count and produces sticky DONE with IRQ = DONE && IRQ_EN.
All 16 strobe masks are tested. Invalid/misaligned and RO writes return SLVERR;
zero-strobe writes to legal writable registers are no-ops. Rejected START
rejects the whole write, including any attempted IRQ_EN update.

Asynchronous reset clears registers, buffered requests, responses and IRQ.
A new completion dominates simultaneous DONE clear. START on the completion
edge is rejected because BUSY was set before that edge. Reads on a write or
completion edge return the state before that edge. These timing choices are
specified in [RTL_BEHAVIOR.md](../docs/RTL_BEHAVIOR.md) and exercised by tests.

## Commands and measured results

Simulator: **Verilator 5.052, 2026-09-05, v5.052**. RTL tests use SystemVerilog
without importing UVM. Host/dependencies are the Fedora 44 setup recorded in
Phase 0. No package or framework was installed during Phase 1.

Executed commands:

```sh
make lint
make test-rtl SEED=42 JOBS=2
make regress-rtl JOBS=2
```

`make lint` executes `--lint-only --Wall` on the synthesizable package/DUT and
passes with no warnings. Each final test compile also passes with no warnings.
Actual compiler and executable argument lists are at the beginning of each log.
The [regression summary](phase1/summary.json) contains these measured counts:

| Seed | Groups | Explicit checks | Completed writes | Completed reads | Result |
| --- | --- | --- | --- | --- | --- |
| 42 | 19 | 2523 | 136 | 157 | PASS |
| 1042 | 19 | 2704 | 136 | 157 | PASS |
| 2026 | 19 | 2568 | 136 | 157 | PASS |

Total: **7795 explicit checks and 879 completed transactions**.
Each seed includes 64 random write/read pairs (128 random transactions), with
random data, byte strobes, separate AW/W delays and B/R stalls. Seeds are passed
to the simulator's RNG and also printed in the test transcript. These are RTL
random tests; they do not satisfy the later constrained-random UVM requirement.

The 19 groups are: smoke_reset_id, register_rw_strobes, aw_before_w,
w_before_aw, aw_w_same_cycle, b_backpressure, r_backpressure, invalid_access,
concurrent_read_write, manager_request_stalls, period_zero_start,
timer_done_irq_w1c, period_snapshot, completion_clear_priority,
busy_start_completion_collision, read_completion_collision,
maximum_period_start, reset_in_flight, randomized_stalls.

Assertions compiled with `--assert` execute in every run. All five channels
have nonzero observed stalled cycles. Seed 42 observes AW=6, W=6, AR=5,
B=253 and R=347 stalled cycles. These counters show that the stability
antecedents occurred; they are not simulator functional-coverage percentages.
Reset is exercised with AW only, W only, both halves awaiting commit, a stalled
B response, a stalled R response and a running timer.

Exact-edge completion checks use only public pins and the documented commit
edge, which the write task checks against actual accepted AW/W requests.
Expected elapsed COUNT comes from the observed start edge, captured period
and pre-edge read-sampling rule, without access to DUT internal state.

Evidence:

- [Strict RTL lint](phase1/lint.log).
- [Seed 42 compile](phase1/42/compile.log), [run](phase1/42/run.log),
  [result](phase1/42/result.json), [committed VCD trace](phase1/42/timer.vcd).
- [Seed 1042 run](phase1/1042/run.log) and [result](phase1/1042/result.json).
- [Seed 2026 run](phase1/2026/run.log) and [result](phase1/2026/result.json).
- [Python syntax/import audit](phase1/python-audit.log).
- [Evidence integrity hashes](phase1/SHA256SUMS.json).

All seed traces also exist locally as `build/rtl/<seed>/timer.vcd`. Open a
trace using `gtkwave build/rtl/42/timer.vcd` from a desktop terminal. Builds,
raw logs and traces remain in ignored `build/`. Generated binaries are not
committed. Git whitespace checks pass. GitHub Actions was updated but has
not been executed remotely.

## Issues found and resolved

The first strict bench compile found an implicit static initializer and two
32/64-bit width warnings. Explicit lifetime and width declarations resolved
them; [the original diagnostics](phase1/compile-initial-warnings.log) remain.

An attempted FST build failed because Verilator's FST writer required absent
`lz4.h`. [That failure log](phase1/compile-fst-blocked.log) is retained. The
runner uses VCD, which the guide permits and which compiles with existing
dependencies. No LZ4 development package was downloaded. Final runs produce
nonempty VCD traces. Verdict JSON is cleared before each attempt so a later
compile failure cannot leave an old PASS verdict in place.

No functional RTL failure was observed in the executed cases. This statement
is limited to the recorded tests and does not imply exhaustive verification.

## Gate status and limitations

| Gate | Status |
| --- | --- |
| 0: pinned real UVM smoke | PASS; prior milestone, see Phase 0 evidence |
| 1: RTL, strict lint and directed tests | PASS |
| 2: real UVM bus agent/model/scoreboard | NOT STARTED |
| 3: complete SVA/covergroup/random UVM matrix | INCOMPLETE; basic protocol SVA now exists |
| 4: UVM regressions, three mutation detections, synthesis evidence | NOT COMPLETE |

UVM is still the real toolchain smoke, not a bus verification environment.
Its two previously documented `UVM_NO_DPI` warnings remain unchanged. The
full-period 0xffffffff case is tested for start/early counting/reset only;
completion over all 2^32-1 cycles was not simulated. This milestone has no
covergroup percentage, mutation campaign, synthesis result, formal proof or
hardware result. RTL execution used Verilator; another simulator was not used.

Supervisor review is requested via the append-only coordination log under
exclusive flock. Findings require specification/evidence assessment by Codex;
a supervisor PASS is not a substitute for these actual test runs.

Next gate: [real UVM agent/model/scoreboard plan](../docs/PHASE2_PLAN.md).
For a fresh checkout, follow [Fedora setup](../docs/SETUP.md), then run the
commands above. No Python packages are required.
