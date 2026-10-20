`include "uvm_macros.svh"
package smoke_pkg;
  import uvm_pkg::*;
  `include "smoke_item.svh"
  `include "smoke_test.svh"
endpackage

module tb_top;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import smoke_pkg::*;
  bit clk = 0;
  always #5ns clk = ~clk;
  smoke_if probe(clk);

  initial begin
    uvm_config_db#(virtual smoke_if)::set(null, "uvm_test_top", "vif", probe);
    run_test("smoke_test");
  end

  initial begin
    #10us;
    $fatal(1, "UVM smoke watchdog expired");
  end
endmodule
