module top;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import timer_tb_pkg::*;
  bit clk = 0;
  always #5ns clk = ~clk;
  axi_if bus(clk);
  axi4lite_timer dut (
    .aclk(clk), .aresetn(bus.aresetn),
    .s_axi_awaddr(bus.awaddr), .s_axi_awvalid(bus.awvalid), .s_axi_awready(bus.awready),
    .s_axi_wdata(bus.wdata), .s_axi_wstrb(bus.wstrb),
    .s_axi_wvalid(bus.wvalid), .s_axi_wready(bus.wready),
    .s_axi_bresp(bus.bresp), .s_axi_bvalid(bus.bvalid), .s_axi_bready(bus.bready),
    .s_axi_araddr(bus.araddr), .s_axi_arvalid(bus.arvalid), .s_axi_arready(bus.arready),
    .s_axi_rdata(bus.rdata), .s_axi_rresp(bus.rresp),
    .s_axi_rvalid(bus.rvalid), .s_axi_rready(bus.rready), .irq(bus.irq)
  );
  axi_assertions protocol_checks(bus);

  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "*", "vif", bus);
    run_test();
  end

  initial begin : waveform
    string path;
    if ($value$plusargs("WAVE=%s", path)) begin
      $dumpfile(path);
      $dumpvars(0, top);
    end
  end

  initial begin
    #500us;
    $fatal(1, "UVM bus test watchdog expired");
  end
endmodule
