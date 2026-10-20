package axi4lite_timer_pkg;
  typedef logic [31:0] word_t;
  typedef logic [3:0] strobe_t;
  typedef enum logic [1:0] {
    RESP_OKAY = 2'b00,
    RESP_SLVERR = 2'b10
  } response_t;

  localparam word_t ADDR_CONTROL = 32'h00;
  localparam word_t ADDR_PERIOD  = 32'h04;
  localparam word_t ADDR_COUNT   = 32'h08;
  localparam word_t ADDR_STATUS  = 32'h0c;
  localparam word_t ADDR_ID      = 32'h10;
  localparam word_t TIMER_ID     = 32'hA11E0001;
  localparam int START_BIT  = 0;
  localparam int IRQ_EN_BIT = 1;
  localparam int DONE_BIT   = 0;
  localparam int BUSY_BIT   = 1;

  function automatic word_t merge_bytes(word_t previous, word_t incoming,
                                         strobe_t strobes);
    word_t merged;
    merged = previous;
    for (int lane = 0; lane < 4; lane++)
      if (strobes[lane]) merged[lane*8 +: 8] = incoming[lane*8 +: 8];
    return merged;
  endfunction
endpackage
