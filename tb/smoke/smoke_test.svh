class smoke_test extends uvm_test;
  `uvm_component_utils(smoke_test)
  virtual smoke_if vif;

  function new(string name = "smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual smoke_if)::get(this, "", "vif", vif))
      `uvm_fatal("SMOKE_CONFIG", "Missing virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    smoke_item item;
    phase.raise_objection(this);
    item = smoke_item::type_id::create("item");
    // No random constraints or solver dependency is needed for this gate.
    item.value = $urandom;
    @(negedge vif.clk);
    vif.value = item.value;
    @(posedge vif.clk);
    if (vif.value !== item.value)
      `uvm_fatal("SMOKE_DATA", "Virtual interface did not retain item value")
    `uvm_info("SMOKE", "UVM running: factory item and virtual interface checked", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
