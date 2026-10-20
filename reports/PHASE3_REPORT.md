# Gate 3: full UVM matrix, constraints and functional coverage

Date: 2026-10-20. Gate 3 PASS from actual `make regress SEED=42 JOBS=2`
and `make coverage`. Tests run on Verilator 5.052 / UVM 2020.3.2 with Z3.
No packages or Python frameworks were added.

Files: timer_full_sequence/test extend the core suite; the driver now cancels
AW-only, W-only, paired buffered, B pending, R pending and combined B/R traffic
through reset. The monitor records actual write order, stalls, read-response
addresses and reset cancellation. timer_coverage.sv subscribes independently
of the scoreboard. tb/axi_assertions.sv also has non-vacuous cover properties.
Scripts uvm_regress.py / coverage.py execute seeds and merge native data.
The explicit scope/exclusions are in config/coverage_plan.json and
[verification matrix](../docs/VERIFICATION_PLAN.md).

Each full run invokes item.randomize() with constraints 96 times (duplex
requests), not merely a scripted fixed-value trace. All requests are checked
through the independent model. Reads/writes are counted only when their actual
response handshakes complete; canceled responses are accounted separately.

| Seed | Checked writes | Checked reads | IRQ checks | Canceled B / R |
| --- | --- | --- | --- | --- |
| 42 | 178 | 217 | 3105 | 2 / 2 |
| 1042 | 178 | 217 | 3130 | 2 / 2 |
| 2026 | 178 | 217 | 3144 | 2 / 2 |

Total: 1185 completed transactions, including 576 class-constrained read/write
transactions across three seeds, plus the directed/core cases. Each run has
10 timer completions and 9 reset epochs; zero UVM errors/fatals. The two
UVM_NO_DPI warnings remain. Final compiles have no Verilator warnings.

[Coverage summary](phase3/coverage/summary.json): all 47 tracked bins hit,
zero misses. Four actual covergroups (address/operation, strobes/order,
responses, events) report 100% via get_inst_coverage() on every seed. This
percentage applies to these defined functional covergroups only. It is not
100% code/toggle/formal or hardware coverage. Native coverage.dat files are
merged using verilator_coverage into [merged.dat](phase3/coverage/merged.dat)
and [LCOV data](phase3/coverage/merged.info). Failed/injected-fault runs are
excluded by the coverage script.

Eight native SVA cover points are nonzero: AW/W/AR stalls=9/9/9, B stalls=2426,
R stalls=2516, B/R accepted responses=534/651, reset=81 (merged across seeds).
Thus the corresponding assertion antecedents are exercised, not just present.

[Regression results](phase3/regression.json), per-seed logs/JSON/native data,
[representative trace](phase3/42/timer.vcd), and integrity hashes are retained.
An initial randomize-return width warning was fixed with an explicit integer
result check. Initial coverage output exposed padded packed-string names;
dynamic string helpers fixed machine-readable identifiers. Those initial logs
remain as historical diagnostics; final results use the corrected code.

Gate 4 remains: three actual RTL mutations, fixed reruns, synthesis where
supported, CI completion and final reproducibility report. No mutation or
synthesis success is claimed by this gate. Supervisor review is requested
through the locked append-only communication log.
