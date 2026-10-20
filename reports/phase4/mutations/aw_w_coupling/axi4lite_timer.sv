module axi4lite_timer (
  input  logic        aclk,
  input  logic        aresetn,
  input  logic [31:0] s_axi_awaddr,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,
  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,
  input  logic [31:0] s_axi_araddr,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready,
  output logic        irq
);
  import axi4lite_timer_pkg::*;

  word_t period_reg, active_period, count_reg;
  logic irq_enabled, busy, done;
  word_t write_address, write_data;
  strobe_t write_strobes;
  logic aw_full, w_full;
  logic commit_write, start_command, clear_done, write_irq, write_period;
  logic complete_timer;
  response_t write_response;
  word_t read_data;
  response_t read_response;

  assign irq = done && irq_enabled;
  assign commit_write = aw_full && w_full && !s_axi_bvalid;
  assign complete_timer = busy && count_reg == active_period - 32'd1;

  // Decode buffered requests only. A rejected START rejects the entire write.
  always_comb begin
    write_response = RESP_OKAY;
    start_command = 0;
    clear_done = 0;
    write_irq = 0;
    write_period = 0;
    case (write_address)
      ADDR_CONTROL: begin
        if (write_strobes[0]) begin
          if (write_data[START_BIT] && (busy || period_reg == 0))
            write_response = RESP_SLVERR;
          else begin
            start_command = write_data[START_BIT];
            write_irq = 1;
          end
        end
      end
      ADDR_PERIOD: write_period = |write_strobes;
      ADDR_STATUS: clear_done = write_strobes[0] && write_data[DONE_BIT];
      default: write_response = RESP_SLVERR;
    endcase
  end

  always_comb begin
    read_response = RESP_OKAY;
    read_data = '0;
    case (s_axi_araddr)
      ADDR_CONTROL: read_data[IRQ_EN_BIT] = irq_enabled;
      ADDR_PERIOD:  read_data = period_reg;
      ADDR_COUNT:   read_data = count_reg;
      ADDR_STATUS: begin
        read_data[DONE_BIT] = done;
        read_data[BUSY_BIT] = busy;
      end
      ADDR_ID: read_data = TIMER_ID;
      default: read_response = RESP_SLVERR;
    endcase
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      period_reg <= '0;
      active_period <= '0;
      count_reg <= '0;
      irq_enabled <= 0;
      busy <= 0;
      done <= 0;
      aw_full <= 0;
      w_full <= 0;
      write_address <= '0;
      write_data <= '0;
      write_strobes <= '0;
      s_axi_awready <= 0;
      s_axi_wready <= 0;
      s_axi_bvalid <= 0;
      s_axi_bresp <= RESP_OKAY;
      s_axi_arready <= 0;
      s_axi_rvalid <= 0;
      s_axi_rdata <= '0;
      s_axi_rresp <= RESP_OKAY;
    end else begin
      if (busy) begin
        count_reg <= count_reg + 32'd1;
        if (complete_timer) begin
          busy <= 0;
          done <= 1;
        end
      end

      if (!aw_full && !s_axi_bvalid) s_axi_awready <= s_axi_wvalid;
      if (!w_full && !s_axi_bvalid) s_axi_wready <= 1;
      if (s_axi_awvalid && s_axi_awready) begin
        write_address <= s_axi_awaddr;
        aw_full <= 1;
        s_axi_awready <= 0;
      end
      if (s_axi_wvalid && s_axi_wready) begin
        write_data <= s_axi_wdata;
        write_strobes <= s_axi_wstrb;
        w_full <= 1;
        s_axi_wready <= 0;
      end

      if (commit_write) begin
        aw_full <= 0;
        w_full <= 0;
        s_axi_awready <= 0;
        s_axi_wready <= 0;
        s_axi_bvalid <= 1;
        s_axi_bresp <= write_response;
        if (write_period)
          period_reg <= merge_bytes(period_reg, write_data, write_strobes);
        if (write_irq) irq_enabled <= write_data[IRQ_EN_BIT];
        if (clear_done && !complete_timer) done <= 0;
        if (start_command) begin
          active_period <= period_reg;
          count_reg <= '0;
          busy <= 1;
          done <= 0;
        end
      end
      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 0;
        s_axi_awready <= 1;
        s_axi_wready <= 1;
      end

      if (!s_axi_rvalid) s_axi_arready <= 1;
      if (s_axi_arvalid && s_axi_arready) begin
        s_axi_arready <= 0;
        s_axi_rvalid <= 1;
        s_axi_rdata <= read_data;
        s_axi_rresp <= read_response;
      end
      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 0;
        s_axi_arready <= 1;
      end
    end
  end
endmodule
