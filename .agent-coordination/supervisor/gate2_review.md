# Gate 2 Technical Review: Reusable AXI4-Lite UVM Agent, Independent Reference Model & Scoreboard

**Date:** 2026-10-20
**Reviewer:** Antigravity (Supervisor & Technical Reviewer)
**Target Milestone:** Gate 2 (Reusable UVM agent and scoreboard)
**Verdict:** PASS

---

## 1. Specification Compliance & Architecture Review

### A. UVM Component Hierarchy & Decoupling
- **Agent Architecture (`tb/uvm/axi_master_agent.sv`):**
  - Follows standard UVM structure with `axi_master_driver`, `uvm_sequencer #(axi_txn)`, and `axi_monitor`.
  - Supports configurable active/passive modes (`get_is_active() == UVM_ACTIVE`).
  - Active driver forks independent threads for AW (`send_aw`), W (`send_w`), and B (`receive_b`), driving pins on falling clock edges with configurable transaction-level delays and timeouts.
  - Driver supports write, read, concurrent duplex, idle, and reset operations without containing DUT register semantics.
- **Passive Monitor:**
  - Observes rising clock edges and reconstructs transaction events strictly from observed pin handshakes.
  - Correctly pairs independent AW and W handshakes before asserting `write_commit`.
  - Samples pre-edge state for read address requests (`arvalid && arready`) before clock updates.
  - Emits cycle-level observations (`axi_cycle`) via an analysis port to the scoreboard.

### B. Reference Model Independence (`tb/uvm/timer_ref_model.sv`)
- **No DUT Peeking:** Computes shadow register states, elapsed cycle counting, and timer deadlines exclusively from observed accepted requests and clock timestamps (`edge_number`).
- **Algorithm Independence:** Uses its own bit-wise strobe assignment for `ADDR_PERIOD` rather than calling the DUT package's `merge_bytes` function.
- **Cycle-Accurate Precision:**
  - Timer completion is predicted strictly when `edge_number - start_edge >= captured_period`.
  - Correctly implements priority semantics: completion takes precedence over simultaneous W1C status clears.

### C. Scoreboard Verification (`tb/uvm/timer_scoreboard.sv`)
- **Response & Payload Checking:** Checks write responses (`bresp`), read responses (`rresp`), and read data (`rdata`) for both immediate and stalled cycles.
- **Interrupt Checking:** Performs cycle-by-cycle IRQ verification against `model.expected_irq()`.
- **Ready Prediction:** Independently predicts registered channel readiness (`AWREADY`, `WREADY`, `ARREADY`) based on internal buffer capacity.
- **Accounting & Drain:** Enforces end-of-test accounting checks in `check_phase` to guarantee no unhandled or lost transactions exist.

---

## 2. Anti-Hardcoding & Negative Control Audit

- **Positive Run Evidence:**
  - `make test-uvm SEED=42 JOBS=2` completed with exit 0 and zero UVM errors/fatals.
  - Executed 38 writes, 59 reads, 587 IRQ checks, 2 completions, and 2 reset epochs.
  - VCD trace generated and retained in `reports/phase2/42/timer.vcd`.
- **Negative Control Execution (`scripts/uvm_fault_check.py`):**
  - Injected bit corruption on public bus `rdata` (`+INJECT_READ_FAULT`).
  - Scoreboard immediately caught the corruption, reporting 242 UVM errors (`MODEL_MISMATCH RDATA`) and returning exit code 1.
  - Confirms scoreboard sensitivity and verifies that test pass criteria are not hardcoded or bypassed.

---

## 3. Risks & Guidance for Milestone Gate 3

1. **Protocol Assertions & Coverage:** Integrate functional coverage (`covergroups`) tracking the transaction matrix (§15: address classes, AW/W arrival permutations, strobe patterns, backpressure stalls, and timer boundaries).
2. **Constrained-Random Stress:** Expand sequence generation to 100+ constrained-random transactions across multiple seeds to stress backpressure and interleaved operations.
3. **Bus Reset-in-Flight in UVM:** Exercise in-flight reset sequences within UVM to complement the directed pin-level reset coverage already demonstrated in Gate 1.
