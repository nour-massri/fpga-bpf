`timescale 1ns / 1ps `default_nettype none
`include "packet_defs.svh"

module bpf_processor #(
    parameter int BUF_ID_BITS   = 2,
    parameter int BUF_ADDR_BITS = 11
) (
    input wire clk,
    input wire rst,

    // Pop side of bpf_work fifo
    input packet_desc_t i_bpf_work_desc,
    input wire i_bpf_work_valid,
    output logic o_bpf_work_pop,

    // Push side of tx_work fifo
    output packet_desc_t o_tx_work_desc,
    output logic o_tx_work_push,
    input wire i_tx_work_full,

    // BRAM read packet
    output logic o_rd_en,
    output logic [BUF_ID_BITS-1:0] o_buf_id,
    output logic [BUF_ADDR_BITS-1:0] o_rd_addr,
    input wire [7:0] i_rd_data,

    // Statistics
    output logic o_pkt_bpf_dropped_pulse
);

  //=========================================================================
  // 1. Internal Signals & States
  //=========================================================================
  typedef enum logic [2:0] {
    IDLE,
    CHECK_VALIDITY,
    START_CPU,
    WAIT_CPU,
    PUSH_WORK
  } state_t;

  state_t state, next_state;

  // Data Path Registers
  packet_desc_t desc_reg;
  logic final_decision_pass;

  // CPU Signals
  logic cpu_start;
  logic cpu_done;
  logic cpu_pass;
  logic cpu_rd_en;
  logic [BUF_ADDR_BITS-1:0] cpu_rd_addr;

  //=========================================================================
  // Submodules
  //=========================================================================

  bpf_cpu #(
      .PC_WIDTH(8),
      .BUF_ADDR_BITS(BUF_ADDR_BITS)
  ) cpu_inst (
      .clk(clk),
      .rst(rst),
      .i_start(cpu_start),
      .i_packet_len(desc_reg.len),
      .o_done(cpu_done),
      .o_pass_packet(cpu_pass),
      .o_ram_rd_en(cpu_rd_en),
      .o_ram_addr(cpu_rd_addr),
      .i_ram_data(i_rd_data)
  );
  //=========================================================================
  // 2. FSM Logic
  //=========================================================================
  always_ff @(posedge clk) begin
    if (rst) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    o_bpf_work_pop = 1'b0;
    o_tx_work_push = 1'b0;
    cpu_start = 1'b0;

    case (state)
      IDLE: begin
        if (i_bpf_work_valid) begin
          o_bpf_work_pop = 1'b1;
          next_state = CHECK_VALIDITY;
        end
      end
      CHECK_VALIDITY: begin
        if (!desc_reg.valid) begin
          next_state = PUSH_WORK;
        end else begin
          next_state = START_CPU;
        end
      end
      START_CPU: begin
        cpu_start  = 1'b1;
        next_state = WAIT_CPU;
      end
      WAIT_CPU: begin
        if (cpu_done) begin
          next_state = PUSH_WORK;
        end
      end
      PUSH_WORK: begin
        if (!i_tx_work_full) begin
          o_tx_work_push = 1'b1;
          next_state = IDLE;
        end
      end
    endcase
  end

  //=========================================================================
  // 3. Data Path
  //=========================================================================
  always_ff @(posedge clk) begin
    if (rst) begin
      desc_reg <= '0;
      final_decision_pass <= 1'b0;
    end else begin
      if (state == IDLE && i_bpf_work_valid) begin
        desc_reg <= i_bpf_work_desc;
      end else if (state == CHECK_VALIDITY) begin
        if (!desc_reg.valid) begin
          final_decision_pass <= 1'b0;
        end
      end else if (state == WAIT_CPU && cpu_done) begin
        final_decision_pass <= cpu_pass;
      end
    end
  end

  //=========================================================================
  // 4. Output signals
  //=========================================================================

  // BRAM Read
  assign o_rd_en = (state == WAIT_CPU) ? cpu_rd_en : 1'b0;
  assign o_rd_addr = (state == WAIT_CPU) ? cpu_rd_addr : '0;
  assign o_buf_id = desc_reg.id;

  // TX Work Queue
  assign o_tx_work_desc.id = desc_reg.id;
  assign o_tx_work_desc.len = desc_reg.len;
  assign o_tx_work_desc.valid = final_decision_pass;

  // ------------------------------------------------------------------------
  // Statistics
  // ------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    o_pkt_bpf_dropped_pulse <= (state == PUSH_WORK && !final_decision_pass);
  end

endmodule
