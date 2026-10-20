class timer_core_sequence extends uvm_sequence #(axi_txn);
  `uvm_object_utils(timer_core_sequence)
  longint unsigned issued_writes = 0, issued_reads = 0;

  function new(string name = "timer_core_sequence");
    super.new(name);
  endfunction

  task issue(axi_operation operation, word_t address = 0, word_t data = 0,
              strobe_t strobes = 4'hf, word_t read_address = ADDR_ID,
              int unsigned aw_delay = 0, int unsigned w_delay = 0,
              int unsigned ar_delay = 0, int unsigned b_stall = 0,
              int unsigned r_stall = 0, int unsigned idle_cycles = 1);
    axi_txn item;
    item = axi_txn::type_id::create("request");
    start_item(item);
    item.operation = operation; item.address = address; item.data = data;
    item.strobes = strobes; item.read_address = read_address;
    item.aw_delay = aw_delay; item.w_delay = w_delay; item.ar_delay = ar_delay;
    item.b_stall = b_stall; item.r_stall = r_stall; item.idle_cycles = idle_cycles;
    finish_item(item);
    if (operation inside {AXI_WRITE, AXI_DUPLEX}) issued_writes++;
    if (operation inside {AXI_READ, AXI_DUPLEX}) issued_reads++;
  endtask

  task body();
    `uvm_info("SCENARIO", "reset_defaults_and_roundtrip", UVM_LOW)
    issue(AXI_READ, ADDR_CONTROL); issue(AXI_READ, ADDR_PERIOD);
    issue(AXI_READ, ADDR_COUNT); issue(AXI_READ, ADDR_STATUS); issue(AXI_READ, ADDR_ID);
    issue(.operation(AXI_WRITE), .address(ADDR_PERIOD), .data($urandom),
          .w_delay(5), .b_stall(4));
    issue(.operation(AXI_READ), .address(ADDR_PERIOD), .r_stall(5));

    `uvm_info("SCENARIO", "write_ordering_strobes_and_errors", UVM_LOW)
    issue(.operation(AXI_WRITE), .address(ADDR_PERIOD), .data($urandom),
          .strobes(4'b0101), .aw_delay(5));
    issue(AXI_READ, ADDR_PERIOD);
    issue(AXI_WRITE, ADDR_PERIOD, $urandom, 0);
    issue(AXI_READ, ADDR_PERIOD);
    issue(AXI_WRITE, ADDR_COUNT, '1);
    issue(AXI_WRITE, ADDR_ID, '1, 0);
    issue(AXI_WRITE, 32'h1, $urandom);
    issue(AXI_READ, 32'h1);
    issue(AXI_READ, 32'h10000004);
    issue(AXI_WRITE, ADDR_PERIOD, 0);
    issue(AXI_WRITE, ADDR_CONTROL, 1 << IRQ_EN_BIT);
    issue(AXI_WRITE, ADDR_CONTROL, 1 << START_BIT);
    issue(AXI_READ, ADDR_CONTROL);

    `uvm_info("SCENARIO", "concurrent_read_and_write_commit", UVM_LOW)
    issue(.operation(AXI_DUPLEX), .address(ADDR_PERIOD), .data($urandom),
          .read_address(ADDR_PERIOD), .ar_delay(1), .b_stall(4), .r_stall(6));
    issue(AXI_READ, ADDR_PERIOD);

    `uvm_info("SCENARIO", "timer_snapshot_elapsed_count_and_irq", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, 80);
    issue(AXI_WRITE, ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
    issue(.operation(AXI_READ), .address(ADDR_COUNT), .r_stall(8));
    issue(AXI_READ, ADDR_STATUS);
    issue(AXI_WRITE, ADDR_PERIOD, 2);
    issue(.operation(AXI_WRITE), .address(ADDR_CONTROL), .data(1 << START_BIT),
          .aw_delay(2));
    issue(AXI_READ, ADDR_CONTROL);
    issue(.operation(AXI_IDLE), .idle_cycles(90));
    issue(AXI_READ, ADDR_STATUS); issue(AXI_READ, ADDR_COUNT);
    issue(AXI_WRITE, ADDR_CONTROL, 0); issue(AXI_READ, ADDR_STATUS);
    issue(AXI_WRITE, ADDR_CONTROL, 1 << IRQ_EN_BIT);
    issue(AXI_WRITE, ADDR_STATUS, 1 << DONE_BIT, 0);
    issue(AXI_READ, ADDR_STATUS);
    issue(AXI_WRITE, ADDR_STATUS, 1 << DONE_BIT);
    issue(AXI_READ, ADDR_STATUS);

    `uvm_info("SCENARIO", "period_one_and_active_timer_reset", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, 1);
    issue(AXI_WRITE, ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
    issue(AXI_READ, ADDR_COUNT); issue(AXI_READ, ADDR_STATUS);
    issue(AXI_WRITE, ADDR_PERIOD, 1000);
    issue(AXI_WRITE, ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
    issue(AXI_RESET, .idle_cycles(3));
    issue(AXI_READ, ADDR_CONTROL); issue(AXI_READ, ADDR_PERIOD);
    issue(AXI_READ, ADDR_COUNT); issue(AXI_READ, ADDR_STATUS);

    `uvm_info("SCENARIO", "seeded_register_pairs", UVM_LOW)
    for (int pair_index = 0; pair_index < 16; pair_index++) begin
      axi_txn item;
      item = axi_txn::type_id::create("seeded_pair");
      start_item(item);
      item.operation = AXI_DUPLEX;
      item.address = ADDR_PERIOD; item.read_address = ADDR_PERIOD;
      item.data = $urandom;
      item.strobes = strobe_t'($urandom_range(15, 0));
      item.aw_delay = $urandom_range(4, 0); item.w_delay = $urandom_range(4, 0);
      item.ar_delay = $urandom_range(4, 0);
      item.b_stall = $urandom_range(6, 0); item.r_stall = $urandom_range(6, 0);
      finish_item(item);
      issued_writes++; issued_reads++;
      issue(AXI_READ, ADDR_PERIOD);
    end
  endtask
endclass

class timer_full_sequence extends timer_core_sequence;
  `uvm_object_utils(timer_full_sequence)
  function new(string name = "timer_full_sequence");
    super.new(name);
  endfunction

  task body();
    super.body();
    `uvm_info("SCENARIO", "smoke_reset_id", UVM_LOW)
    issue(AXI_RESET, .idle_cycles(3));
    issue(AXI_READ, ADDR_ID);
    `uvm_info("SCENARIO", "register_rw_strobes", UVM_LOW)
    for (int unsigned mask = 0; mask < 16; mask++) begin
      issue(AXI_WRITE, ADDR_PERIOD, $urandom, strobe_t'(mask));
      issue(AXI_READ, ADDR_PERIOD);
    end
    `uvm_info("SCENARIO", "aw_before_w", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, $urandom, .w_delay(5));
    `uvm_info("SCENARIO", "w_before_aw", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, $urandom, .aw_delay(5));
    `uvm_info("SCENARIO", "aw_w_same_cycle", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, $urandom);
    `uvm_info("SCENARIO", "b_backpressure", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, $urandom, .b_stall(10));
    `uvm_info("SCENARIO", "r_backpressure", UVM_LOW)
    issue(AXI_READ, ADDR_PERIOD, .r_stall(10));
    `uvm_info("SCENARIO", "concurrent_read_write", UVM_LOW)
    issue(AXI_DUPLEX, ADDR_PERIOD, $urandom, .read_address(ADDR_PERIOD), .ar_delay(1));
    `uvm_info("SCENARIO", "invalid_access", UVM_LOW)
    issue(AXI_WRITE, 32'h14, $urandom);
    issue(AXI_READ, 32'h14);
    issue(AXI_WRITE, ADDR_ID, '1); issue(AXI_READ, ADDR_ID);
    issue(AXI_WRITE, ADDR_COUNT, '1); issue(AXI_READ, ADDR_COUNT);
    `uvm_info("SCENARIO", "period_zero_start", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, 0);
    issue(AXI_WRITE, ADDR_CONTROL, 1 << START_BIT);
    `uvm_info("SCENARIO", "timer_done_irq_w1c", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, 5);
    issue(AXI_WRITE, ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
    issue(AXI_WRITE, ADDR_STATUS, 1 << DONE_BIT); // Coincides with completion.
    issue(AXI_READ, ADDR_STATUS); issue(AXI_READ, ADDR_COUNT);
    `uvm_info("SCENARIO", "period_snapshot", UVM_LOW)
    issue(AXI_WRITE, ADDR_PERIOD, 50);
    issue(AXI_WRITE, ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
    issue(AXI_WRITE, ADDR_PERIOD, 1);
    issue(AXI_IDLE, .idle_cycles(55));
    issue(AXI_READ, ADDR_COUNT); issue(AXI_READ, ADDR_STATUS);

    `uvm_info("SCENARIO", "reset_in_flight", UVM_LOW)
    for (int unsigned stage = 1; stage <= 6; stage++) begin
      axi_txn item;
      item = axi_txn::type_id::create("reset_pending");
      start_item(item);
      item.operation = AXI_RESET; item.reset_stage = stage;
      item.idle_cycles = 3; item.data = $urandom; item.strobes = 4'hf;
      finish_item(item);
      issue(AXI_READ, ADDR_CONTROL); issue(AXI_READ, ADDR_PERIOD);
      issue(AXI_READ, ADDR_COUNT); issue(AXI_READ, ADDR_STATUS);
    end

    `uvm_info("SCENARIO", "randomized_stalls", UVM_LOW)
    for (int unsigned index = 0; index < 96; index++) begin
      axi_txn item;
      int solved;
      item = axi_txn::type_id::create("constrained_pair");
      start_item(item);
      item.operation = AXI_DUPLEX;
      solved = item.randomize() with {
        address == ADDR_PERIOD;
        read_address inside {ADDR_CONTROL, ADDR_PERIOD, ADDR_COUNT, ADDR_STATUS,
                             ADDR_ID, 32'h14, 32'h1};
      };
      if (solved == 0) `uvm_fatal("RANDOMIZE", "Constrained item randomization failed")
      finish_item(item);
      issued_writes++; issued_reads++;
      if (index % 16 == 0) begin
        issue(AXI_WRITE, ADDR_PERIOD, $urandom_range(20, 1));
        issue(AXI_WRITE, ADDR_CONTROL, (1 << START_BIT) | (1 << IRQ_EN_BIT));
        issue(AXI_IDLE, .idle_cycles(25));
        issue(AXI_READ, ADDR_STATUS); issue(AXI_READ, ADDR_COUNT);
      end
    end
  endtask
endclass
