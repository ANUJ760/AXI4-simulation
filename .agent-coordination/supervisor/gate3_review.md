# Gate 3 Technical Review: Protocol SVA, Functional Covergroups, Constrained Randomization & Regressions

**Date:** 2026-10-20
**Reviewer:** Antigravity (Supervisor & Technical Reviewer)
**Target Milestone:** Gate 3 (Assertions, randomized testing, coverage and regressions)
**Verdict:** PASS

---

## 1. Specification Compliance & Verification Review

### A. Protocol Assertions & Non-Vacuous Covers (`tb/axi_assertions.sv`)
- **Safety Properties:** AW/W/AR/B/R payload and valid stability assertions active with zero failures across all regressions.
- **Activity Proving:** Native cover properties verify that assertion antecedents are genuinely triggered and non-vacuous during execution:
  - AW/W/AR stalls observed: 9 / 9 / 9 across regression runs.
  - B/R backpressure stalls observed: 2,426 / 2,516 cycles.
  - Valid B/R transfers: 534 / 651 transactions.
  - Reset events: 81 clock cycles.

### B. Functional Coverage Model (`tb/uvm/timer_coverage.sv`, `config/coverage_plan.json`)
- **Covergroup Structure:**
  - `address_cg`: Cross of read/write operations against 7 address classes (control, period, count, status, id, unmapped, misaligned).
  - `write_cg`: Strobe masks (0 to 15) and channel arrival ordering (simultaneous, AW-first, W-first).
  - `response_cg`: Read/write responses (OKAY, SLVERR).
  - `event_cg`: 10 system and bus events (channel stalls, reset in flight, idle reset, DONE reads, IRQ rising/falling edges).
- **Measurement & Reporting:**
  - 47 tracked bins systematically hit with zero missed bins.
  - Per-seed covergroup coverage reports 100.0% across all 4 covergroups via `get_inst_coverage()`.
  - Merged coverage generated via `verilator_coverage` into `merged.dat` and `merged.info`.
  - Explicit exclusions properly documented (no out-of-scope AXI features, no false claims of code/toggle/gate coverage).

### C. Constrained Randomization & Robustness (`tb/uvm/timer_sequences.sv`)
- **Full Matrix Execution:** Covers all 15 scenarios specified in DOCX §15, including in-flight reset aborts across 6 distinct pipeline stages.
- **Constrained-Random Diversity:** 96 randomized duplex transactions per run solved via Z3 constraint solver, exercising randomized address distributions, byte masks, launch delays, and response backpressure stalls.
- **Accounting:** Scoreboard strictly verifies and accounts for in-flight transaction cancellations during asynchronous reset (2 write and 2 read cancellations per seed).
- **Multi-Seed Regression:** Completed across seeds 42, 1042, and 2026 with 1,185 total transactions, zero UVM errors, and zero UVM fatals.

---

## 2. Anti-Hardcoding Audit

- Verified that coverage bins are dynamically collected from actual monitor observations.
- All per-bin counters exhibit natural statistical variance across different random seeds.
- Scoreboard and reference model predict transaction expectations dynamically; failed or negative runs are explicitly excluded from merged coverage.

---

## 3. Risks & Guidance for Milestone Gate 4

1. **RTL Mutation Verification:** Implement at least three distinct, deliberate RTL faults (e.g., AW/W coupling, incorrect WSTRB byte masking, early/late completion) and demonstrate that the UVM scoreboard or protocol assertions fail on each mutation.
2. **Fixed Rerun Verification:** Ensure clean passing reruns upon restoring correct RTL.
3. **Synthesis Check:** Run Yosys high-level synthesis to report area and gate/register statistics without latches or combinational loops.
4. **Final Deliverable Report:** Consolidate all evidence into `reports/FINAL_REPORT.md` with complete reproduction instructions.
