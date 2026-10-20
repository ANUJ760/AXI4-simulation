class timer_coverage extends uvm_subscriber #(axi_cycle);
  `uvm_component_utils(timer_coverage)
  longint unsigned address_hits[2][7], strobe_hits[16], order_hits[3];
  longint unsigned response_hits[2][2], event_hits[10];
  bit previous_irq, was_reset;

  covergroup address_cg with function sample(bit is_write, int unsigned address_class);
    option.per_instance = 1;
    operation: coverpoint is_write { bins read = {0}; bins write = {1}; }
    address: coverpoint address_class { bins classes[] = {[0:6]}; }
    operation_address: cross operation, address;
  endgroup
  covergroup write_cg with function sample(strobe_t strobes, int unsigned order_code);
    option.per_instance = 1;
    strobe: coverpoint strobes { bins masks[] = {[0:15]}; }
    ordering: coverpoint order_code { bins simultaneous = {0}; bins aw_first = {1}; bins w_first = {2}; }
  endgroup
  covergroup response_cg with function sample(bit is_write, logic [1:0] response_code);
    option.per_instance = 1;
    operation: coverpoint is_write { bins read = {0}; bins write = {1}; }
    response: coverpoint response_code { bins okay = {RESP_OKAY}; bins slverr = {RESP_SLVERR}; }
    operation_response: cross operation, response;
  endgroup
  covergroup event_cg with function sample(int unsigned event_code);
    option.per_instance = 1;
    scenario: coverpoint event_code { bins events[] = {[0:9]}; }
  endgroup

  function new(string name = "timer_coverage", uvm_component parent = null);
    super.new(name, parent);
    address_cg = new(); write_cg = new(); response_cg = new(); event_cg = new();
    foreach (address_hits[op, address]) address_hits[op][address] = 0;
    foreach (strobe_hits[i]) strobe_hits[i] = 0;
    foreach (order_hits[i]) order_hits[i] = 0;
    foreach (response_hits[op, response]) response_hits[op][response] = 0;
    foreach (event_hits[i]) event_hits[i] = 0;
  endfunction

  function int unsigned classify_address(word_t address);
    if (address[1:0] != 0) return 6;
    case (address)
      ADDR_CONTROL: return 0;
      ADDR_PERIOD: return 1;
      ADDR_COUNT: return 2;
      ADDR_STATUS: return 3;
      ADDR_ID: return 4;
      default: return 5;
    endcase
  endfunction

  function string operation_name(int unsigned index);
    if (index == 1) return "write";
    return "read";
  endfunction

  function string response_name(int unsigned index);
    if (index == 0) return "okay";
    return "slverr";
  endfunction

  function string address_name(int unsigned index);
    case (index)
      0: return "control"; 1: return "period"; 2: return "count";
      3: return "status"; 4: return "id"; 5: return "unmapped";
      default: return "misaligned";
    endcase
  endfunction

  function string event_name(int unsigned index);
    case (index)
      0: return "aw_stall"; 1: return "w_stall"; 2: return "ar_stall";
      3: return "b_stall"; 4: return "r_stall"; 5: return "reset_in_flight";
      6: return "done_read"; 7: return "irq_rise"; 8: return "irq_fall";
      default: return "reset_idle";
    endcase
  endfunction

  function void hit_event(int unsigned index);
    event_hits[index]++;
    event_cg.sample(index);
  endfunction

  function void write(axi_cycle t);
    int unsigned address_class;
    if (!t.resetn) begin
      if (!was_reset) hit_event(t.reset_in_flight ? 5 : 9);
      was_reset = 1;
    end else begin
      was_reset = 0;
      if (t.write_commit) begin
        address_class = classify_address(t.write_address);
        address_hits[1][address_class]++;
        address_cg.sample(1, address_class);
        strobe_hits[t.write_strobes]++;
        order_hits[t.write_order]++;
        write_cg.sample(t.write_strobes, t.write_order);
      end
      if (t.ar_fire) begin
        address_class = classify_address(t.read_address);
        address_hits[0][address_class]++;
        address_cg.sample(0, address_class);
      end
      if (t.b_fire) begin
        response_cg.sample(1, t.accepted_bresp);
        if (t.accepted_bresp == RESP_OKAY) response_hits[1][0]++;
        if (t.accepted_bresp == RESP_SLVERR) response_hits[1][1]++;
      end
      if (t.r_fire) begin
        response_cg.sample(0, t.accepted_rresp);
        if (t.accepted_rresp == RESP_OKAY) response_hits[0][0]++;
        if (t.accepted_rresp == RESP_SLVERR) response_hits[0][1]++;
        if (t.completed_read_address == ADDR_STATUS &&
            t.accepted_rresp == RESP_OKAY && t.accepted_rdata[DONE_BIT]) hit_event(6);
      end
      if (t.aw_stall) hit_event(0);
      if (t.w_stall) hit_event(1);
      if (t.ar_stall) hit_event(2);
      if (t.b_stall) hit_event(3);
      if (t.r_stall) hit_event(4);
    end
    if (!previous_irq && t.post_irq) hit_event(7);
    if (previous_irq && !t.post_irq) hit_event(8);
    previous_irq = t.post_irq;
  endfunction

  function void emit_bin(string name, longint unsigned hits);
    `uvm_info("COVER_BIN", $sformatf("name=%s hits=%0d", name, hits), UVM_LOW)
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    foreach (address_hits[op, address])
      emit_bin($sformatf("address.%s.%s", operation_name(op), address_name(address)),
               address_hits[op][address]);
    foreach (strobe_hits[i]) emit_bin($sformatf("strobe.%0d", i), strobe_hits[i]);
    foreach (order_hits[i]) emit_bin($sformatf("order.%0d", i), order_hits[i]);
    foreach (response_hits[op, response])
      emit_bin($sformatf("response.%s.%s", operation_name(op),
                        response_name(response)), response_hits[op][response]);
    foreach (event_hits[i]) emit_bin($sformatf("event.%s", event_name(i)), event_hits[i]);
    `uvm_info("COVERGROUP", $sformatf("name=address percent=%0.2f", address_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info("COVERGROUP", $sformatf("name=write percent=%0.2f", write_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info("COVERGROUP", $sformatf("name=response percent=%0.2f", response_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info("COVERGROUP", $sformatf("name=event percent=%0.2f", event_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
