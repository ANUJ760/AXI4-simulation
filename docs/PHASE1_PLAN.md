# Proposed Phase 1: RTL and directed verification

Begin after Gate 0, following the guide's instruction to deliver Phase 0 first.

Files:

- `rtl/axi4lite_timer_pkg.sv`: fixed 32-bit register offsets, encodings, ID.
- `rtl/axi4lite_timer.sv`: independent one-entry AW/W buffers; registered READY;
  persistent B/R responses; asynchronous reset; timer and register bank.
- `tests/rtl/timer_tb.sv`: self-checking pin-level directed tests.
- `tb/axi_assertions.sv`: payload stability and reset response checks.
- Make lint/test-rtl targets with real logs and nonzero failure exits.

Before RTL, encode the register contract in directed tests. Cover reset/ID,
RW strobes (including zero), RO rejection, invalid/misaligned addresses,
AW-before-W, W-before-AW, simultaneous AW/W, B/R backpressure, concurrent
read/write, zero-period and busy START rejection, exact edge counts, DONE/IRQ,
W1C, active PERIOD snapshot and reset with buffered requests/responses.

Define collision rules explicitly: reset dominates all effects; completion
beats DONE clear; reads sample state at AR acceptance; writes commit after
both buffered halves are available; invalid START must not change IRQ_EN.
Apply §5 address and access permissions before strobe handling: prohibited or
invalid writes return SLVERR; zero-strobe writes to legal writable registers
return OKAY without effects. START validation applies only to a selected bit 0.

Commands: `make lint`, `make test-rtl`. Acceptance: clean lint, all directed
cases executed successfully, real evidence retained. Gate 2 adds the reusable
class-based UVM bus agent, independent model and scoreboard. Smoke success
alone does not satisfy those later gates.
