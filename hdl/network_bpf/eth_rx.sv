`timescale 1ns / 1ps `default_nettype none
`include "packet_desc_t.svh"
module eth_rx #(
    parameter int CPU_ID_BITS,
    parameter int BUF_ID_BITS,
    parameter int BUF_ADDR_BITS
) (
    input wire clk,
    input wire rst,

    // Ethernet RX (RMII)
    input wire eth_crsdv,
    input wire [1:0] eth_rxd,

    // Pop side of free_buffer fifo (from mux)
    input wire [CPU_ID_BITS-1:0] i_free_buf_pop_cpu_id,
    input wire [BUF_ID_BITS-1:0] i_free_buf_pop_data,
    input wire i_free_buf_pop_valid,
    output logic o_free_buf_pop_ready,

    // Push side of bpf_work fifo (to demux)
    output logic [CPU_ID_BITS-1:0] o_bpf_work_push_cpu_id,
    output packet_desc_t o_bpf_work_push_data,
    output logic o_bpf_work_push_valid,
    input wire i_bpf_work_push_ready,

    // BRAM write (to demux)
    output logic o_wren,
    output logic [CPU_ID_BITS-1:0] o_cpu_id,
    output logic [BUF_ID_BITS-1:0] o_buf_id,
    output logic [BUF_ADDR_BITS-1:0] o_wr_addr,
    output logic [7:0] o_wr_data,

    // Statistics
    output logic o_byte_active,
    output logic o_pkt_received_pulse,
    output logic o_pkt_sent_pulse
);

  //=========================================================================
  // Internal Signals & States
  //=========================================================================

  typedef enum logic [2:0] {
    WAIT_FOR_BUF,
    WAIT_FOR_IFG,  // Making sure we don't start mid packet
    IDLE,
    RECEIVE_DATA,
    PUSH_WORK
  } state_t;

  state_t state, next_state;

  // RMII signals
  logic byte_valid;
  logic [7:0] byte_data;
  logic carrier_detected;

  // Data path registers
  logic [CPU_ID_BITS-1:0] current_cpu_id;
  logic [BUF_ID_BITS-1:0] current_buf_id;
  logic [BUF_ADDR_BITS-1:0] byte_cnt;

  //=========================================================================
  // Submodules
  //=========================================================================
  rmii_to_byte rmii (
      .clk(clk),
      .rst(rst),

      .eth_crsdv(eth_crsdv),
      .eth_rxd(eth_rxd),
      .o_byte_valid(byte_valid),
      .o_byte_data(byte_data),
      .carrier_detected(carrier_detected)
  );

  logic pkt_is_valid;
  assign pkt_is_valid = (byte_cnt >= 64);

  //=========================================================================
  // FSM Logic
  //=========================================================================

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= WAIT_FOR_BUF;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    o_free_buf_pop_ready = 1'b0;
    o_bpf_work_push_valid = 1'b0;

    case (state)
      WAIT_FOR_BUF: begin
        if (i_free_buf_pop_valid) begin
          if (carrier_detected) begin
            // mid-packet don't start
            next_state = WAIT_FOR_IFG;
          end else begin
            next_state = IDLE;
          end
        end
      end
      WAIT_FOR_IFG: begin
        if (!i_free_buf_pop_valid) begin
          next_state = WAIT_FOR_BUF;
        end else if (!carrier_detected) begin
          next_state = IDLE;
        end
      end
      IDLE: begin
        if (!i_free_buf_pop_valid) begin
          next_state = WAIT_FOR_BUF;
        end else if (carrier_detected) begin
          o_free_buf_pop_ready = 1'b1;
          next_state           = RECEIVE_DATA;
        end
      end
      RECEIVE_DATA: begin
        if (!carrier_detected) begin
          next_state = PUSH_WORK;
        end
        // TODO: add crc check and packet length check
      end
      PUSH_WORK: begin
        // block until can push descriptor (shouldn't happen)
        if (i_bpf_work_push_ready) begin
          o_bpf_work_push_valid = 1'b1;
          next_state = WAIT_FOR_BUF;
        end
      end
    endcase
  end

  //=========================================================================
  // Data path
  //=========================================================================

  always_ff @(posedge clk) begin
    if (o_free_buf_pop_ready) begin
      current_cpu_id <= i_free_buf_pop_cpu_id;
      current_buf_id <= i_free_buf_pop_data;
    end
  end

  always_ff @(posedge clk) begin
    if (state == IDLE) begin
      byte_cnt <= '0;
    end else if (state == RECEIVE_DATA && byte_valid) begin
      // TODO: Logic to skip preamble bytes in count
      // or even better write it but only skip it for bpf processor read end
      byte_cnt <= byte_cnt + 1'b1;
    end
  end

  //=========================================================================
  // Output signals
  //=========================================================================

  // BRAM Write
  assign o_wren    = (state == RECEIVE_DATA) && byte_valid;
  assign o_cpu_id  = current_cpu_id;
  assign o_buf_id  = current_buf_id;
  assign o_wr_addr = byte_cnt;
  assign o_wr_data = byte_data;

  // BPF Work Queue
  assign o_bpf_work_push_cpu_id     = current_cpu_id;
  assign o_bpf_work_push_data.id    = current_buf_id;
  assign o_bpf_work_push_data.len   = byte_cnt;
  assign o_bpf_work_push_data.valid = pkt_is_valid; // TODO: CRC check result

  // Statistics
  always_ff @(posedge clk) begin
    o_pkt_received_pulse <= o_free_buf_pop_ready;
    o_byte_active <= byte_valid;
    // TODO: Implement proper drop logic
    o_pkt_sent_pulse <= o_bpf_work_push_valid;
  end

endmodule
`default_nettype wire
