typedef enum int unsigned {AXI_READ, AXI_WRITE, AXI_DUPLEX, AXI_IDLE, AXI_RESET} axi_operation;

class axi_txn extends uvm_sequence_item;
  `uvm_object_utils(axi_txn)
  axi_operation operation = AXI_READ;
  rand bit [31:0] address, data, read_address;
  rand bit [3:0] strobes;
  rand int unsigned aw_delay, w_delay, ar_delay, b_stall, r_stall;
  int unsigned idle_cycles = 1;
  bit [31:0] read_result;
  bit [1:0] write_response, read_response;

  constraint bounded_delays {
    aw_delay inside {[0:8]}; w_delay inside {[0:8]};
    ar_delay inside {[0:8]}; b_stall inside {[0:8]}; r_stall inside {[0:8]};
  }

  function new(string name = "axi_txn");
    super.new(name);
    strobes = '1;
  endfunction

  function string convert2string();
    return $sformatf("%s address=%08h data=%08h strobes=%h read_address=%08h",
                     operation.name(), address, data, strobes, read_address);
  endfunction
endclass

// One immutable observation per edge. Request/response handshakes are sampled
// before NBA updates; post_* values are sampled after the DUT has settled.
class axi_cycle extends uvm_sequence_item;
  `uvm_object_utils(axi_cycle)
  longint unsigned edge_number;
  bit resetn;
  bit aw_fire, w_fire, ar_fire, b_fire, r_fire;
  bit write_commit;
  word_t write_address, write_data, read_address;
  strobe_t write_strobes;
  logic [1:0] accepted_bresp, accepted_rresp;
  word_t accepted_rdata;
  bit post_bvalid, post_rvalid, post_irq;
  logic [1:0] post_bresp, post_rresp;
  word_t post_rdata;

  function new(string name = "axi_cycle");
    super.new(name);
  endfunction
endclass
