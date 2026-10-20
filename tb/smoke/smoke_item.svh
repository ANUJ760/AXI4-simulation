class smoke_item extends uvm_sequence_item;
  `uvm_object_utils(smoke_item)
  bit [31:0] value;

  function new(string name = "smoke_item");
    super.new(name);
  endfunction
endclass
