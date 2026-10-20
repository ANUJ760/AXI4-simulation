# Phase 2: real UVM bus agent and independent checking

Status: implemented and executed; see ../reports/PHASE2_REPORT.md.

Prerequisites: Gate 0's real UVM smoke and Gate 1's RTL lint/directed tests pass.
Read the shared coordination log before starting. Follow the DOCX Part A,
`RTL_BEHAVIOR.md` and the guide's Gate 2 acceptance criterion.

Planned files:

- `tb/uvm/axi_txn.sv`: read/write request and observed-event types; address,
  data, strobes, channel delays, response stalls and cycle timestamps.
- `tb/uvm/axi_master_agent.sv`: sequencer, pin-level manager driver and passive
  monitor. Observe AW and W independently; preserve payloads until acceptance.
- `tb/uvm/timer_ref_model.sv`: independent state model driven by observed
  accepted requests and clock edges. Compute elapsed cycles from the captured
  period and start edge; do not read DUT internals or use observed responses
  to define expected results.
- `tb/uvm/timer_scoreboard.sv`: expected response queues, ordering, register data,
  reset cancellation and IRQ comparisons at documented sampling points.
- `tb/uvm/timer_env.sv`: connect monitor analysis ports to checking components.
- `tb/uvm/timer_sequences.sv`, `tb/uvm/timer_tests.sv`, `tb/top.sv`: actual
  end-to-end UVM write/read scenarios, independent directions and reset.
- Build/CI/report updates: `make test-uvm` must execute the real UVM environment.

Before implementation, make sampling order explicit: drivers change pins on
falling edges; monitor accepted payloads before rising-edge DUT updates; reads
sample the state from before that edge; write commit occurs one edge after the
later accepted half. Compare settled response outputs and IRQ after updates.
Process reset before queued events and discard canceled requests/responses.

Gate 2 acceptance: real UVM write/read round-trip, reconstructed by the monitor
and checked entirely by the independent scoreboard; no UVM errors/fatals;
reproducible seed and real logs. Preserve Gate 1 tests as an independent suite.
Run the checks, append results under flock, assess supervisor feedback and then
report the gate. SVA, covergroups, full random matrix and mutation campaigns
remain later gate requirements.
