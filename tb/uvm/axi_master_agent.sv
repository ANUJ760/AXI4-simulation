class axi_master_driver extends uvm_driver #(axi_txn);
  `uvm_component_utils(axi_master_driver)
  virtual axi_if vif;
  localparam int unsigned HANDSHAKE_TIMEOUT = 1000;

  function new(string name = "axi_master_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "AXI driver requires virtual interface")
  endfunction

  task reset_bus(int unsigned hold_cycles);
    vif.aresetn = 0;
    vif.awaddr = 0; vif.awvalid = 0;
    vif.wdata = 0; vif.wstrb = 0; vif.wvalid = 0; vif.bready = 0;
    vif.araddr = 0; vif.arvalid = 0; vif.rready = 0;
    repeat (hold_cycles) @(negedge vif.aclk);
    vif.aresetn = 1;
  endtask

  task send_aw(axi_txn item);
    int unsigned waited;
    repeat (item.aw_delay) @(negedge vif.aclk);
    vif.awaddr = item.address; vif.awvalid = 1;
    waited = 0;
    do begin
      @(posedge vif.aclk);
      if (++waited > HANDSHAKE_TIMEOUT) `uvm_fatal("AW_TIMEOUT", item.convert2string())
    end while (!vif.awready);
    @(negedge vif.aclk); vif.awvalid = 0;
  endtask

  task send_w(axi_txn item);
    int unsigned waited;
    repeat (item.w_delay) @(negedge vif.aclk);
    vif.wdata = item.data; vif.wstrb = item.strobes; vif.wvalid = 1;
    waited = 0;
    do begin
      @(posedge vif.aclk);
      if (++waited > HANDSHAKE_TIMEOUT) `uvm_fatal("W_TIMEOUT", item.convert2string())
    end while (!vif.wready);
    @(negedge vif.aclk); vif.wvalid = 0;
  endtask

  task receive_b(axi_txn item);
    int unsigned waited;
    vif.bready = 0;
    waited = 0;
    do begin
      @(posedge vif.aclk);
      if (++waited > HANDSHAKE_TIMEOUT) `uvm_fatal("B_TIMEOUT", item.convert2string())
    end while (!vif.bvalid);
    repeat (item.b_stall) @(posedge vif.aclk);
    @(negedge vif.aclk); vif.bready = 1;
    @(posedge vif.aclk); item.write_response = vif.bresp;
    @(negedge vif.aclk); vif.bready = 0;
  endtask

  task drive_write(axi_txn item);
    fork
      send_aw(item);
      send_w(item);
      receive_b(item);
    join
  endtask

  task drive_read(axi_txn item);
    int unsigned waited;
    repeat (item.ar_delay) @(negedge vif.aclk);
    vif.araddr = item.operation == AXI_DUPLEX ? item.read_address : item.address;
    vif.arvalid = 1; vif.rready = 0;
    waited = 0;
    do begin
      @(posedge vif.aclk);
      if (++waited > HANDSHAKE_TIMEOUT) `uvm_fatal("AR_TIMEOUT", item.convert2string())
    end while (!vif.arready);
    @(negedge vif.aclk); vif.arvalid = 0;
    waited = 0;
    do begin
      @(posedge vif.aclk);
      if (++waited > HANDSHAKE_TIMEOUT) `uvm_fatal("R_TIMEOUT", item.convert2string())
    end while (!vif.rvalid);
    repeat (item.r_stall) @(posedge vif.aclk);
    @(negedge vif.aclk); vif.rready = 1;
    @(posedge vif.aclk);
    item.read_result = vif.rdata; item.read_response = vif.rresp;
    @(negedge vif.aclk); vif.rready = 0;
  endtask

  task run_phase(uvm_phase phase);
    axi_txn item;
    reset_bus(3);
    forever begin
      seq_item_port.get_next_item(item);
      @(negedge vif.aclk);
      `uvm_info("DRIVE", item.convert2string(), UVM_HIGH)
      case (item.operation)
        AXI_WRITE: drive_write(item);
        AXI_READ: drive_read(item);
        AXI_DUPLEX: begin
          fork
            drive_write(item);
            drive_read(item);
          join
        end
        AXI_IDLE: repeat (item.idle_cycles) @(posedge vif.aclk);
        AXI_RESET: reset_bus(item.idle_cycles);
        default: `uvm_fatal("BAD_OPERATION", "Unknown AXI operation")
      endcase
      seq_item_port.item_done();
    end
  endtask
endclass

class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)
  virtual axi_if vif;
  uvm_analysis_port #(axi_cycle) observations;
  bit have_aw, have_w;
  word_t aw_address, w_data;
  strobe_t w_strobes;
  longint unsigned edge_number = 0;

  function new(string name = "axi_monitor", uvm_component parent = null);
    super.new(name, parent);
    observations = new("observations", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "AXI monitor requires virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    axi_cycle sample;
    forever begin
      @(posedge vif.aclk);
      sample = axi_cycle::type_id::create("sample");
      sample.edge_number = ++edge_number;
      sample.resetn = vif.aresetn;
      if (!vif.aresetn) begin
        have_aw = 0; have_w = 0;
      end else begin
        // Pair the prior accepted halves BEFORE capturing this edge's inputs.
        sample.write_commit = have_aw && have_w;
        if (sample.write_commit) begin
          sample.write_address = aw_address;
          sample.write_data = w_data;
          sample.write_strobes = w_strobes;
          have_aw = 0; have_w = 0;
        end
        sample.aw_fire = vif.awvalid && vif.awready;
        sample.w_fire = vif.wvalid && vif.wready;
        sample.ar_fire = vif.arvalid && vif.arready;
        sample.b_fire = vif.bvalid && vif.bready;
        sample.r_fire = vif.rvalid && vif.rready;
        sample.read_address = vif.araddr;
        sample.accepted_bresp = vif.bresp;
        sample.accepted_rresp = vif.rresp;
        sample.accepted_rdata = vif.rdata;
        if (sample.aw_fire) begin
          if (have_aw) `uvm_error("DUPLICATE_AW", "AW buffer accepted twice")
          have_aw = 1; aw_address = vif.awaddr;
        end
        if (sample.w_fire) begin
          if (have_w) `uvm_error("DUPLICATE_W", "W buffer accepted twice")
          have_w = 1; w_data = vif.wdata; w_strobes = vif.wstrb;
        end
      end
      #1ps;
      sample.post_bvalid = vif.bvalid; sample.post_bresp = vif.bresp;
      sample.post_rvalid = vif.rvalid; sample.post_rresp = vif.rresp;
      sample.post_rdata = vif.rdata; sample.post_irq = vif.irq;
      observations.write(sample);
    end
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (have_aw || have_w) `uvm_error("UNPAIRED_WRITE", "Accepted write half remains")
  endfunction
endclass

class axi_master_agent extends uvm_agent;
  `uvm_component_utils(axi_master_agent)
  axi_master_driver driver;
  uvm_sequencer #(axi_txn) sequencer;
  axi_monitor monitor;

  function new(string name = "axi_master_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = axi_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver = axi_master_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(axi_txn)::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
