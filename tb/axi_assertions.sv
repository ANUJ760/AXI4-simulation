module axi_assertions(axi_if.monitor bus);
  timeunit 1ns;
  timeprecision 1ps;
  default clocking cb @(posedge bus.aclk); endclocking
  default disable iff (!bus.aresetn);

  aw_stable: assert property (bus.awvalid && !bus.awready |=>
                              bus.awvalid && $stable(bus.awaddr))
    else $fatal(1, "AW changed while stalled");
  w_stable: assert property (bus.wvalid && !bus.wready |=>
                             bus.wvalid && $stable({bus.wdata, bus.wstrb}))
    else $fatal(1, "W changed while stalled");
  ar_stable: assert property (bus.arvalid && !bus.arready |=>
                              bus.arvalid && $stable(bus.araddr))
    else $fatal(1, "AR changed while stalled");
  b_stable: assert property (bus.bvalid && !bus.bready |=>
                             bus.bvalid && $stable(bus.bresp))
    else $fatal(1, "B changed while stalled");
  r_stable: assert property (bus.rvalid && !bus.rready |=>
                             bus.rvalid && $stable({bus.rdata, bus.rresp}))
    else $fatal(1, "R changed while stalled");
  no_write_space: assert property (bus.bvalid |-> !bus.awready && !bus.wready)
    else $fatal(1, "Write accepted with outstanding response");
  no_read_space: assert property (bus.rvalid |-> !bus.arready)
    else $fatal(1, "Read accepted with outstanding response");
  reset_clears: assert property (@(posedge bus.aclk) disable iff (1'b0)
                                 !bus.aresetn |->
                                 !bus.bvalid && !bus.rvalid && !bus.irq &&
                                 !bus.awready && !bus.wready && !bus.arready)
    else $fatal(1, "Reset did not clear responses/READY/IRQ");

  logic saw_aw, saw_w, saw_ar;
  always_ff @(posedge bus.aclk or negedge bus.aresetn) begin
    if (!bus.aresetn) begin
      saw_aw <= 0;
      saw_w <= 0;
      saw_ar <= 0;
    end else begin
      if (bus.awvalid && bus.awready) saw_aw <= 1;
      if (bus.wvalid && bus.wready) saw_w <= 1;
      if (bus.bvalid && bus.bready) begin
        saw_aw <= 0;
        saw_w <= 0;
      end
      if (bus.arvalid && bus.arready) saw_ar <= 1;
      if (bus.rvalid && bus.rready) saw_ar <= 0;
    end
  end
  paired_write: assert property (bus.bvalid |-> saw_aw && saw_w)
    else $fatal(1, "B response without accepted AW and W");
  paired_read: assert property (bus.rvalid |-> saw_ar)
    else $fatal(1, "R response without accepted AR");
endmodule
