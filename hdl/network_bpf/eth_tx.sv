`timescale 1ns / 1ps `default_nettype none

module eth_tx
  import network_bpf_config_pkg::*;
(
    input wire clk,
    input wire rst,

    // Ethernet TX (RMII)
    output logic eth_txen,
    output logic [1:0] eth_txd,

    // Pop side of tx_work fifo (from mux)
    input wire [CPU_ID_BITS-1:0] i_tx_work_pop_cpu_id,
    input packet_desc_t i_tx_work_pop_data,
    input wire i_tx_work_pop_valid,
    output logic o_tx_work_pop_ready,

    // Push side of free_buffer fifo (return buffer to demux)
    output logic [CPU_ID_BITS-1:0] o_free_buf_push_cpu_id,
    output logic [BUF_ID_BITS-1:0] o_free_buf_push_data,
    output logic o_free_buf_push_valid,
    input wire i_free_buf_push_ready,

    // BRAM read (to demux)
    output logic o_rd_en,
    output logic [CPU_ID_BITS-1:0] o_cpu_id,
    output logic [BUF_ID_BITS-1:0] o_buf_id,
    output logic [BUF_ADDR_BITS-1:0] o_rd_addr,
    input wire [7:0] i_rd_data,

    // Statistics
    output logic o_byte_active,
    output logic o_pkt_received_pulse,
    output logic o_pkt_sent_pulse
);

  //=========================================================================
  // Internal Signals & States
  //=========================================================================

  typedef enum logic [2:0] {
    IDLE,
    FILTER_DESC,
    PREFETCH,
    SEND_FRAME,
    IFG_WAIT,
    RETURN_BUF
  } state_t;

  state_t state, next_state;

  // RMII signals
  logic [1:0] tick_cnt;
  logic [7:0] shift_reg;
  logic [5:0] ifg_counter;

  // Data path registers
  logic current_packet_valid;
  logic [CPU_ID_BITS-1:0] current_cpu_id;
  logic [BUF_ID_BITS-1:0] current_buf_id;
  logic [BUF_ADDR_BITS-1:0] packet_len;
  logic [BUF_ADDR_BITS-1:0] byte_cnt;

  //=========================================================================
  // FSM Logic
  //=========================================================================

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    o_tx_work_pop_ready = 1'b0;
    o_free_buf_push_valid = 1'b0;

    case (state)
      IDLE: begin
        if (i_tx_work_pop_valid) begin
          o_tx_work_pop_ready = 1'b1;
          next_state = FILTER_DESC;
        end
      end
      FILTER_DESC: begin
        if (!current_packet_valid) begin
          next_state = RETURN_BUF;
        end else begin
          next_state = PREFETCH;
        end
      end
      PREFETCH: begin
        // prefetch byte 0 requested inFILTER_DESC
        next_state = SEND_FRAME;
      end
      SEND_FRAME: begin
        if (byte_cnt == packet_len && tick_cnt == 3) begin
          next_state = IFG_WAIT;
        end
      end
      IFG_WAIT: begin
        // 12 bytes * 4 ticks = 48 clocks minimum IFG
        if (ifg_counter == 48) next_state = RETURN_BUF;
      end
      RETURN_BUF: begin
        if (i_free_buf_push_ready) begin
          o_free_buf_push_valid = 1'b1;
          next_state = IDLE;
        end
      end
    endcase
  end

  //=========================================================================
  // Data Path
  //=========================================================================

  always_ff @(posedge clk) begin
    if (rst || state != SEND_FRAME) begin
      tick_cnt <= 0;
    end else begin
      tick_cnt <= tick_cnt + 1;
    end
  end

  always_ff @(posedge clk) begin
    if (state == IFG_WAIT) ifg_counter <= ifg_counter + 1;
    else ifg_counter <= 0;
  end

  always_ff @(posedge clk) begin
    if (state == IDLE) begin
      byte_cnt <= 0;
      if (i_tx_work_pop_valid) begin
        current_packet_valid <= i_tx_work_pop_data.valid;
        current_cpu_id <= i_tx_work_pop_cpu_id;
        current_buf_id <= i_tx_work_pop_data.id;
        packet_len <= i_tx_work_pop_data.len;
      end
    end else if (state == FILTER_DESC) begin
      byte_cnt <= 1;  // fetch byte 1
    end else if (state == SEND_FRAME && tick_cnt == 3) begin
      if (byte_cnt < packet_len) byte_cnt <= byte_cnt + 1;
    end
  end

  always_ff @(posedge clk) begin
    if (state == PREFETCH) begin
      shift_reg <= i_rd_data;  // Load Byte 0
    end else if (state == SEND_FRAME) begin
      if (tick_cnt == 3) begin
        shift_reg <= i_rd_data;  // Load Byte N+1
      end else begin
        shift_reg <= {2'b00, shift_reg[7:2]};  // LSB first
      end
    end
  end

  //=========================================================================
  // Output signals
  //=========================================================================

  // RMII Output
  assign eth_txen = (state == SEND_FRAME);
  assign eth_txd = (state == SEND_FRAME) ? shift_reg[1:0] : 2'b00;

  // BRAM Read
  assign o_rd_en   = (state == FILTER_DESC) ||
                       (state == PREFETCH) ||
                       (state == SEND_FRAME && tick_cnt == 0 && byte_cnt < packet_len);

  assign o_cpu_id = current_cpu_id;
  assign o_buf_id = current_buf_id;
  assign o_rd_addr = byte_cnt;

  // Return Buffer
  assign o_free_buf_push_cpu_id = current_cpu_id;
  assign o_free_buf_push_data = current_buf_id;

  // ------------------------------------------------------------------------
  // Statistics
  // ------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    o_pkt_received_pulse <= o_tx_work_pop_ready;
    o_byte_active <= (state == SEND_FRAME) && (tick_cnt == 3);
    o_pkt_sent_pulse <= (state == PREFETCH);
  end
endmodule
`default_nettype wire
