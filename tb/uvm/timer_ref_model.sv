class timer_ref_model extends uvm_object;
  `uvm_object_utils(timer_ref_model)
  word_t configured_period, captured_period, final_count;
  bit running, done, irq_enabled;
  longint unsigned start_edge, last_edge;

  function new(string name = "timer_ref_model");
    super.new(name);
    reset();
  endfunction

  function void reset();
    configured_period = 0; captured_period = 0; final_count = 0;
    running = 0; done = 0; irq_enabled = 0; start_edge = 0; last_edge = 0;
  endfunction

  function word_t elapsed_count();
    longint unsigned elapsed;
    if (!running) return final_count;
    elapsed = last_edge - start_edge;
    return elapsed >= 64'(captured_period) ? captured_period : word_t'(elapsed);
  endfunction

  function word_t read_register(word_t address, output response_t response);
    word_t value;
    response = RESP_OKAY;
    value = 0;
    case (address)
      ADDR_CONTROL: value[IRQ_EN_BIT] = irq_enabled;
      ADDR_PERIOD: value = configured_period;
      ADDR_COUNT: value = elapsed_count();
      ADDR_STATUS: begin value[DONE_BIT] = done; value[BUSY_BIT] = running; end
      ADDR_ID: value = TIMER_ID;
      default: response = RESP_SLVERR;
    endcase
    return value;
  endfunction

  // Advance independently from the DUT counter: elapsed time is derived from
  // edge timestamps. Write validation uses the state BEFORE this edge.
  function response_t step(longint unsigned edge_number, bit commit,
                            word_t address, word_t data, strobe_t strobes);
    bit completing, reject_start;
    response_t response;
    completing = running && edge_number - start_edge >= 64'(captured_period);
    reject_start = data[START_BIT] && (running || configured_period == 0);
    response = RESP_OKAY;
    last_edge = edge_number;
    if (completing) begin
      running = 0; done = 1; final_count = captured_period;
    end
    if (!commit) return response;
    case (address)
      ADDR_CONTROL: begin
        if (strobes[0]) begin
          if (reject_start) response = RESP_SLVERR;
          else begin
            irq_enabled = data[IRQ_EN_BIT];
            if (data[START_BIT]) begin
              captured_period = configured_period;
              start_edge = edge_number;
              final_count = 0; running = 1; done = 0;
            end
          end
        end
      end
      ADDR_PERIOD: begin
        // Deliberately independent from the DUT's byte merge helper.
        for (int bit_index = 0; bit_index < 32; bit_index++)
          if (strobes[bit_index / 8]) configured_period[bit_index] = data[bit_index];
      end
      ADDR_STATUS: if (strobes[0] && data[DONE_BIT] && !completing) done = 0;
      default: response = RESP_SLVERR;
    endcase
    return response;
  endfunction

  function bit expected_irq();
    return done && irq_enabled;
  endfunction
endclass
