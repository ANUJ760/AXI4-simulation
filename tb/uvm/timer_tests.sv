class timer_core_test extends uvm_test;
  `uvm_component_utils(timer_core_test)
  timer_env env;
  timer_core_sequence stimulus;
  virtual axi_if vif;

  function new(string name = "timer_core_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Timer test requires virtual interface")
    env = timer_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    stimulus = timer_core_sequence::type_id::create("stimulus");
    stimulus.start(env.agent.sequencer);
    repeat (3) @(negedge vif.aclk);
    `uvm_info("GATE2", $sformatf("UVM bus sequences completed: issued_writes=%0d issued_reads=%0d",
                                 stimulus.issued_writes, stimulus.issued_reads), UVM_LOW)
    phase.drop_objection(this);
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (stimulus == null) begin
      `uvm_error("NO_SEQUENCE", "Bus sequence never ran")
      return;
    end
    if (env.scoreboard.writes_checked != stimulus.issued_writes ||
        env.scoreboard.reads_checked != stimulus.issued_reads)
      `uvm_error("LOST_TRANSACTION", "Sequence-issued and monitor-checked totals differ")
  endfunction
endclass
