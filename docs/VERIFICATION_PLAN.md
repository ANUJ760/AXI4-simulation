# Verification matrix

The DOCX §§5–8 and §15 define the behavioral and verification requirements.
The full UVM test logs the required scenario names and checks every observed
transaction through the independent scoreboard. The RTL suite remains separate.

| Scenario | Stimulus and checks |
| --- | --- |
| smoke_reset_id | Reset values, CONTROL/PERIOD/COUNT/STATUS and constant ID |
| register_rw_strobes | All 16 masks; independent byte-lane expectations; reserved bits and zero strobe |
| aw_before_w | Separate AW/W threads and actual AW-first acceptance |
| w_before_aw | Actual W-first acceptance without assuming simultaneous channels |
| aw_w_same_cycle | Same-edge acceptance of both write halves |
| b_backpressure | BVALID/BRESP retained; no extra outstanding write |
| r_backpressure | Latched RDATA/RRESP retained even while timer state changes |
| concurrent_read_write | Independent directions, including AR on write commit |
| invalid_access | RO writes, misaligned and high/unmapped addresses, specified response/data |
| period_zero_start | Rejected START without IRQ_EN or other write side effects |
| timer_done_irq_w1c | Exact edge completion, sticky DONE, W1C and IRQ enable gating |
| period_snapshot | PERIOD writes while BUSY preserve the active captured duration |
| reset_in_flight | AW-only, W-only, paired halves, B pending, R pending, and B/R pending together |
| randomized_stalls | Class-constrained data/strobes/addresses/delays; seeded timer periods |
| mutation_checks | Three deliberately changed RTL behaviors, real checker failures and a fixed rerun |

Additional RTL cases check maximum-period start/early counting, asynchronous
reset between edges, completion versus DONE clear, START on completion, and
pre-edge reads on completion. Completion over all 2^32-1 cycles is excluded
from runtime simulation; width and boundary logic remain covered by lint and
shorter-duration checks.

Coverage definitions live in config/coverage_plan.json and timer_coverage.sv.
The 47 tracked bins use operation/address and operation/response cross products,
16 masks, three accepted write orders and ten event classes. Simulator
covergroup percentages include their marginal coverpoints; the tracked-bin
count does not double-count those marginal points. No toggle, code, FSM,
formal or physical timing coverage is implied. EXOKAY/DECERR and full AXI
bursts/IDs are outside this peripheral's contract.

Protocol assertions check all five stalled-channel payloads and VALID retention,
response pairing, registered capacity and reset clearing. Non-vacuous cover
properties count the five stall antecedents, accepted B/R responses and reset.
Expected IRQ and READY are also checked by the model each clock. Measured
results and known misses belong in reports/, never as assigned pass values in
stimulus or model code.
