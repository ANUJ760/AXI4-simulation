`include "uvm_macros.svh"
package timer_tb_pkg;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import axi4lite_timer_pkg::*;
  `include "axi_txn.sv"
  `include "timer_ref_model.sv"
  `include "timer_scoreboard.sv"
  `include "axi_master_agent.sv"
  `include "timer_sequences.sv"
  `include "timer_env.sv"
  `include "timer_tests.sv"
endpackage
