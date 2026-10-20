module timer_tb;
  timeunit 1ns;
  timeprecision 1ps;
  import axi4lite_timer_pkg::*;

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

  longint unsigned cycles = 0, last_write_cycle, last_read_cycle;
  int unsigned checks = 0, groups = 0, writes = 0, reads = 0;
  string scenario = "bringup";

  // A pin-only timing oracle: BVALID marks the documented commit edge.
  // write_reg independently verifies that edge against accepted AW/W requests.
  bit arm_timer_watch = 0, timer_watch = 0;
  longint unsigned timer_start;
  int unsigned watched_period;
  always @(posedge clk) begin
    cycles = cycles + 1;
    #2ps;
    if (!bus.aresetn) begin
      arm_timer_watch = 0;
      timer_watch = 0;
    end else begin
      if (arm_timer_watch && bus.bvalid) begin
        timer_start = cycles;
        timer_watch = 1;
        arm_timer_watch = 0;
      end
      if (timer_watch) begin
        if (cycles < timer_start + 64'(watched_period)) begin
          if (bus.irq !== 1'b0) $fatal(1, "early IRQ at cycle %0d", cycles);
        end else begin
          if (bus.irq !== 1'b1) $fatal(1, "late/missing IRQ at cycle %0d", cycles);
          timer_watch = 0;
        end
      end
    end
  end

  task automatic check(input bit condition, input string message);
    checks++;
    if (!condition) $fatal(1, "%s: %s (cycle=%0d)", scenario, message, cycles);
  endtask

  task automatic begin_case(input string name);
    scenario = name;
    groups++;
    $display("CASE %s", name);
  endtask

  task automatic cycle;
    @(posedge clk);
    #1ps;
  endtask

  task automatic reset_bus;
    @(negedge clk);
    bus.aresetn = 0;
    bus.awaddr = 0; bus.awvalid = 0;
    bus.wdata = 0; bus.wstrb = 0; bus.wvalid = 0; bus.bready = 0;
    bus.araddr = 0; bus.arvalid = 0; bus.rready = 0;
    #1ps;
    check(!bus.bvalid && !bus.rvalid && !bus.irq, "asynchronous response/IRQ reset");
    check(!bus.awready && !bus.wready && !bus.arready, "asynchronous READY reset");
    repeat (2) cycle();
    @(negedge clk); bus.aresetn = 1;
    cycle();
    @(negedge clk);
  endtask

  task automatic write_reg(input word_t address, input word_t data,
                           input strobe_t strobes = 4'hf,
                           input logic [1:0] response = RESP_OKAY,
                           input int unsigned aw_delay = 0,
                           input int unsigned w_delay = 0,
                           input int unsigned stall = 0);
    bit aw_done, w_done, aw_hit, w_hit;
    int unsigned elapsed;
    aw_done = 0; w_done = 0; elapsed = 0;
    @(negedge clk);
    bus.awaddr = address; bus.wdata = data; bus.wstrb = strobes; bus.bready = 0;
    while (!(aw_done && w_done)) begin
      bus.awvalid = !aw_done && elapsed >= aw_delay;
      bus.wvalid = !w_done && elapsed >= w_delay;
      @(posedge clk);
      aw_hit = bus.awvalid && bus.awready;
      w_hit = bus.wvalid && bus.wready;
      #1ps;
      aw_done |= aw_hit; w_done |= w_hit;
      check(!bus.bvalid, "B must wait until edge after both AW/W handshakes");
      @(negedge clk);
      if (aw_done) bus.awvalid = 0;
      if (w_done) bus.wvalid = 0;
      elapsed++;
    end
    cycle();
    last_write_cycle = cycles;
    check(bus.bvalid, "one response at write commit edge");
    check(bus.bresp == response, $sformatf("BRESP address=%h expected=%b got=%b",
                                         address, response, bus.bresp));
    repeat (stall) begin
      cycle();
      check(bus.bvalid && bus.bresp == response, "B response retained through stall");
      check(!bus.awready && !bus.wready, "no new write while B outstanding");
    end
    @(negedge clk); bus.bready = 1;
    cycle();
    check(!bus.bvalid, "B response consumed exactly once");
    writes++;
    @(negedge clk); bus.bready = 0;
  endtask

  task automatic read_reg(input word_t address, output word_t data,
                          input logic [1:0] response = RESP_OKAY,
                          input int unsigned stall = 0);
    bit accepted;
    @(negedge clk);
    bus.araddr = address; bus.arvalid = 1; bus.rready = 0;
    do begin
      @(posedge clk); accepted = bus.arvalid && bus.arready;
      #1ps;
    end while (!accepted);
    last_read_cycle = cycles;
    check(bus.rvalid, "read response produced at AR acceptance");
    data = bus.rdata;
    check(bus.rresp == response, $sformatf("RRESP address=%h", address));
    @(negedge clk); bus.arvalid = 0;
    repeat (stall) begin
      cycle();
      check(bus.rvalid && bus.rdata === data && bus.rresp == response,
            "R payload retained through stall");
      check(!bus.arready, "no new AR while R outstanding");
    end
    @(negedge clk); bus.rready = 1;
    cycle();
    check(!bus.rvalid, "R response consumed exactly once");
    reads++;
    @(negedge clk); bus.rready = 0;
  endtask

  task automatic expect_reg(input word_t address, input word_t expected,
                            input logic [1:0] response = RESP_OKAY,
                            input int unsigned stall = 0);
    word_t actual;
    read_reg(address, actual, response, stall);
    check(actual === expected, $sformatf("read address=%h expected=%h got=%h",
                                        address, expected, actual));
  endtask

  task automatic start_watched(input int unsigned period);
    write_reg(ADDR_PERIOD, period);
    watched_period = period;
    arm_timer_watch = 1;
    write_reg(ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
  endtask

  task automatic check_elapsed(input longint unsigned start_edge, input word_t period);
    word_t actual, expected;
    longint unsigned elapsed;
    read_reg(ADDR_COUNT, actual);
    // Reads sample BEFORE the acceptance edge's timer increment.
    elapsed = last_read_cycle > start_edge ? last_read_cycle - start_edge - 1 : 0;
    expected = elapsed >= 64'(period) ? period : word_t'(elapsed);
    check(actual == expected, $sformatf("COUNT from observed start edge expected=%0d got=%0d",
                                       expected, actual));
  endtask

  initial begin : directed_tests
    word_t expected, data;
    static word_t invalid[6] = '{32'h1, 32'h2, 32'h3, 32'h14, 32'h10000004, 32'hfffffffc};
    longint unsigned start_edge;
    int unsigned seed;
    seed = 42;
    if ($value$plusargs("SEED=%d", seed)) begin end
    $display("RTL seed=%0d", seed);
    bus.aresetn = 1;

    begin_case("smoke_reset_id");
    reset_bus();
    expect_reg(ADDR_CONTROL, 0); expect_reg(ADDR_PERIOD, 0);
    expect_reg(ADDR_COUNT, 0); expect_reg(ADDR_STATUS, 0); expect_reg(ADDR_ID, TIMER_ID);

    begin_case("register_rw_strobes");
    expected = 0;
    for (int unsigned strobe = 0; strobe < 16; strobe++) begin
      data = $urandom;
      write_reg(ADDR_PERIOD, data, strobe_t'(strobe));
      for (int lane = 0; lane < 4; lane++)
        if (strobe[lane]) expected[lane*8 +: 8] = data[lane*8 +: 8];
      expect_reg(ADDR_PERIOD, expected);
    end
    write_reg(ADDR_CONTROL, 32'hfffffffe, 4'h1);
    expect_reg(ADDR_CONTROL, 1 << IRQ_EN_BIT);
    write_reg(ADDR_CONTROL, 0, 4'he);
    expect_reg(ADDR_CONTROL, 1 << IRQ_EN_BIT);
    write_reg(ADDR_CONTROL, 1, 0);
    expect_reg(ADDR_CONTROL, 1 << IRQ_EN_BIT);

    begin_case("aw_before_w");
    write_reg(ADDR_PERIOD, 17, 4'hf, RESP_OKAY, 0, 5); expect_reg(ADDR_PERIOD, 17);
    begin_case("w_before_aw");
    write_reg(ADDR_PERIOD, 23, 4'hf, RESP_OKAY, 5, 0); expect_reg(ADDR_PERIOD, 23);
    begin_case("aw_w_same_cycle");
    write_reg(ADDR_PERIOD, 31); expect_reg(ADDR_PERIOD, 31);
    begin_case("b_backpressure");
    write_reg(ADDR_PERIOD, 37, 4'hf, RESP_OKAY, 0, 0, 9); expect_reg(ADDR_PERIOD, 37);
    begin_case("r_backpressure");
    expect_reg(ADDR_PERIOD, 37, RESP_OKAY, 9);

    begin_case("invalid_access");
    foreach (invalid[i]) begin
      expect_reg(invalid[i], 0, RESP_SLVERR);
      write_reg(invalid[i], '1, 4'hf, RESP_SLVERR);
      write_reg(invalid[i], '1, 0, RESP_SLVERR);
    end
    write_reg(ADDR_COUNT, '1, 4'hf, RESP_SLVERR);
    write_reg(ADDR_ID, '1, 4'hf, RESP_SLVERR);
    write_reg(ADDR_COUNT, '1, 0, RESP_SLVERR);
    write_reg(ADDR_ID, '1, 0, RESP_SLVERR);
    expect_reg(ADDR_PERIOD, 37); expect_reg(ADDR_ID, TIMER_ID); expect_reg(ADDR_COUNT, 0);

    begin_case("period_zero_start");
    write_reg(ADDR_PERIOD, 0);
    write_reg(ADDR_CONTROL, 1, 4'hf, RESP_SLVERR);
    expect_reg(ADDR_CONTROL, 1 << IRQ_EN_BIT);
    expect_reg(ADDR_STATUS, 0); expect_reg(ADDR_COUNT, 0);

    begin_case("timer_done_irq_w1c");
    start_watched(1);
    expect_reg(ADDR_COUNT, 1); expect_reg(ADDR_STATUS, 1 << DONE_BIT);
    check(bus.irq, "IRQ asserted after period=1 completion");
    write_reg(ADDR_CONTROL, 0); check(!bus.irq, "IRQ disable gates sticky DONE");
    expect_reg(ADDR_STATUS, 1 << DONE_BIT);
    write_reg(ADDR_CONTROL, 1 << IRQ_EN_BIT); check(bus.irq, "IRQ re-enable sees sticky DONE");
    write_reg(ADDR_STATUS, 1, 0); check(bus.irq, "zero-strobe W1C is a no-op");
    write_reg(ADDR_STATUS, 1, 4'he); check(bus.irq, "unselected DONE byte unchanged");
    write_reg(ADDR_STATUS, 1 << BUSY_BIT); check(bus.irq, "writing BUSY cannot clear DONE");
    write_reg(ADDR_STATUS, 1); check(!bus.irq, "W1C clears IRQ");
    expect_reg(ADDR_STATUS, 0); expect_reg(ADDR_COUNT, 1);
    start_watched(3);
    check_elapsed(last_write_cycle, 3);
    repeat (3) cycle();
    expect_reg(ADDR_COUNT, 3); expect_reg(ADDR_STATUS, 1 << DONE_BIT);

    begin_case("period_snapshot");
    start_watched(60); start_edge = last_write_cycle;
    check_elapsed(start_edge, 60);
    expect_reg(ADDR_STATUS, 1 << BUSY_BIT);
    write_reg(ADDR_PERIOD, 2);
    write_reg(ADDR_CONTROL, 1, 4'hf, RESP_SLVERR);
    expect_reg(ADDR_CONTROL, 1 << IRQ_EN_BIT);
    check_elapsed(start_edge, 60);
    repeat (60) cycle();
    expect_reg(ADDR_COUNT, 60); expect_reg(ADDR_PERIOD, 2);
    expect_reg(ADDR_STATUS, 1 << DONE_BIT); check(bus.irq, "snapshot timer completed");
    start_watched(2);
    expect_reg(ADDR_COUNT, 2);

    check(!timer_watch && !arm_timer_watch, "all exact-edge timer checks completed");
    $display("RTL RESULT PASS seed=%0d groups=%0d checks=%0d writes=%0d reads=%0d",
             seed, groups, checks, writes, reads);
    $finish;
  end

  initial begin
    #2ms;
    $fatal(1, "RTL watchdog: %s seed is printed at test start", scenario);
  end
endmodule
