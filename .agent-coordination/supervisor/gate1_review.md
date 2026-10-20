# Gate 1 Technical Review: Synthesizable AXI4-Lite Timer RTL & Directed Verification

**Date:** 2026-10-20
**Reviewer:** Antigravity (Supervisor & Technical Reviewer)
**Target Milestone:** Gate 1 (AXI4-Lite timer RTL with directed tests)
**Verdict:** PASS

---

## 1. Specification Compliance & Protocol Review

### A. Channel Handshaking & Buffering
- **AW & W Independence:** The DUT implements independent one-entry buffers (`aw_full` and `w_full`). Write requests can arrive with AW before W, W before AW, or in the same clock cycle.
- **Commit Point:** A write commits strictly on the rising clock edge following the presence of both buffered halves (`commit_write = aw_full && w_full && !s_axi_bvalid`).
- **Response Persistence:** `s_axi_bvalid` and `s_axi_bresp` are held stable until the cycle `s_axi_bready` is observed.
- **Write Backpressure:** While `s_axi_bvalid` is asserted, both `s_axi_awready` and `s_axi_wready` remain deasserted (preventing buffer overflow and write hazard collisions).
- **Read Path Independence:** The AR channel operates concurrently and independently from write channels. Overlapping read and write transactions commit correctly with pre-edge register state sampled at AR acceptance (`s_axi_arvalid && s_axi_arready`).
- **Output Stability:** All READY signals and response outputs are driven from registered state (no direct combinational feedthrough from bus inputs).

### B. Register Map & Access Permissions
- **Address Decoding:** Exact 32-bit addresses are matched; unaligned addresses or unmapped high address spaces return `RESP_SLVERR` with zero data and no register modification.
- **Register Set:**
  - `0x00 CONTROL`: Bit 0 = START (write-1 pulse, reads 0); Bit 1 = IRQ_EN (RW, reset 0).
  - `0x04 PERIOD`: 32-bit RW counter period; reset 0. Supported full byte strobing.
  - `0x08 COUNT`: 32-bit RO elapsed counter; writes return `RESP_SLVERR`.
  - `0x0C STATUS`: Bit 0 = DONE (sticky, W1C); Bit 1 = BUSY (RO); reset 0.
  - `0x10 ID`: 32-bit RO constant `0xA11E0001`; writes return `RESP_SLVERR`.
- **Byte Strobes (WSTRB):** Full 16-pattern matrix tested. Zero-strobe write (`WSTRB = 4'b0000`) to legal writable registers completes with `RESP_OKAY` and produces no register side-effects.

### C. Timer & Interrupt Semantics
- **START Validation:** START command requires `PERIOD > 0` and `!busy`. START when BUSY or with `PERIOD == 0` is rejected with `RESP_SLVERR` and leaves existing state (including `irq_enabled` and ongoing counter progress) unaffected.
- **Snapshot Behavior:** Timer counter snapshots `active_period <= period_reg` at start. Writes to `PERIOD` while `BUSY` update `period_reg` without altering `active_period`.
- **Clock Precision:** Once running, `count_reg` increments on each subsequent clock edge, completing on exactly cycle `active_period`, setting `DONE = 1`, `BUSY = 0`, and retaining `COUNT = active_period`.
- **Collision Rules:** Completion strictly dominates simultaneous W1C clears; asynchronous reset actively dominates all pending states and buffered traffic.

---

## 2. Verification & Anti-Hardcoding Audit

- **Dynamic Evaluation:**
  - `timer_tb.sv` uses dynamically computed expectations (e.g., `merge_bytes` for strobed writes, cycle math for timer duration and count checks).
  - Seeded random stall delays are exercised on all five channels (`aw`, `w`, `ar`, `b`, `r`).
- **Assertions:**
  - Bus stability assertions in `tb/axi_assertions.sv` verify payload stability under stall for AW, W, AR, B, and R channels.
  - Protocol safety assertions verify paired write/read response generation and clear-on-reset behavior.
- **Test Executions:**
  - Standalone lint: Verilator `--lint-only --Wall` passes cleanly.
  - 3-seed regression (`scripts/rtl_regress.py` over seeds 42, 1042, 2026) executes 19 scenario groups and 7,795 explicit assertions with zero failures.

---

## 3. Risks & Guidance for Milestone Gate 2

1. **UVM Separation:** Ensure strict boundary separation between sequence items (`axi_txn`), driver, monitor, and scoreboard. The driver must not contain register decoding logic; the monitor must passively observe pin handshakes and reconstruct bus transfers.
2. **Reference Model Independence:** The UVM reference model (`timer_ref_model`) must maintain its own internal shadow state of registers and cycle counting based strictly on observed bus transactions and clocks, without peeking at DUT internal nets.
3. **Pipelined Channels in Driver:** The AXI driver should manage write address and write data threads independently using parallel processes or non-blocking sequences.
4. **Verilator UVM Compatibility:** Retain `+define+UVM_NO_DPI` and keep class inheritance standard to ensure seamless execution on the pinned Verilator 5.052 baseline.
