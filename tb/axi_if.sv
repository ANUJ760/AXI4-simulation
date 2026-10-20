interface axi_if(input logic aclk);
  timeunit 1ns;
  timeprecision 1ps;
  logic aresetn;
  logic [31:0] awaddr, wdata, araddr, rdata;
  logic [3:0] wstrb;
  logic [1:0] bresp, rresp;
  logic awvalid, awready, wvalid, wready, bvalid, bready;
  logic arvalid, arready, rvalid, rready, irq;

  modport manager(input aclk, awready, wready, bvalid, bresp, arready,
                  rvalid, rdata, rresp, irq,
                  output aresetn, awaddr, awvalid, wdata, wstrb, wvalid,
                  bready, araddr, arvalid, rready);
  modport monitor(input aclk, aresetn, awaddr, awvalid, awready,
                  wdata, wstrb, wvalid, wready, bresp, bvalid, bready,
                  araddr, arvalid, arready, rdata, rresp, rvalid, rready, irq);
endinterface
