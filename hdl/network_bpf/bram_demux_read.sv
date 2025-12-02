`timescale 1ns / 1ps `default_nettype none

module bram_demux_read
  import network_bpf_config_pkg::*;
#(
    parameter int DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst,

    // Single Input 
    input wire                     i_mux_rd_en,
    input wire [  CPU_ID_BITS-1:0] i_mux_cpu_id,
    input wire [  BUF_ID_BITS-1:0] i_mux_buf_id,
    input wire [BUF_ADDR_BITS-1:0] i_mux_addr,

    // Array Outputs
    output logic [NUM_CPUS-1:0]                    o_rd_en,
    output logic [NUM_CPUS-1:0][  BUF_ID_BITS-1:0] o_buf_id_out,
    output logic [NUM_CPUS-1:0][BUF_ADDR_BITS-1:0] o_addr_out,
    input  wire  [NUM_CPUS-1:0][   DATA_WIDTH-1:0] i_rd_data,

    // Single Output Data 
    output logic [DATA_WIDTH-1:0] o_mux_data
);


  always_comb begin
    o_rd_en      = '0;
    o_buf_id_out = {NUM_CPUS{i_mux_buf_id}};
    o_addr_out   = {NUM_CPUS{i_mux_addr}};

    if (i_mux_cpu_id < NUM_CPUS) begin
      o_rd_en[i_mux_cpu_id] = i_mux_rd_en;
    end
  end

  // that's in case controller didn't hold mux_cpu_id
  logic [CPU_ID_BITS-1:0] prev_mux_cpu_id;
  always_ff @(posedge clk) begin
    prev_mux_cpu_id <= i_mux_cpu_id;
  end
  assign o_mux_data = i_rd_data[prev_mux_cpu_id];

endmodule
`default_nettype wire
