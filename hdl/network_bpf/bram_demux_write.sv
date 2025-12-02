`timescale 1ns / 1ps `default_nettype none

module bram_demux_write
  import network_bpf_config_pkg::*;
#(
    parameter int DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst,

    // Single Input
    input wire [  CPU_ID_BITS-1:0] i_demux_cpu_id,
    input wire                     i_demux_wr_en,
    input wire [  BUF_ID_BITS-1:0] i_demux_buf_id,
    input wire [BUF_ADDR_BITS-1:0] i_demux_addr,
    input wire [   DATA_WIDTH-1:0] i_demux_data,

    // Array Outputs (to BRAMs)
    output logic [NUM_CPUS-1:0]                    o_wr_en,
    output logic [NUM_CPUS-1:0][   DATA_WIDTH-1:0] o_wr_data,
    output logic [NUM_CPUS-1:0][  BUF_ID_BITS-1:0] o_buf_id_out,
    output logic [NUM_CPUS-1:0][BUF_ADDR_BITS-1:0] o_addr_out
);

  always_comb begin
    o_wr_en      = '0;
    o_wr_data    = {NUM_CPUS{i_demux_data}};
    o_buf_id_out = {NUM_CPUS{i_demux_buf_id}};
    o_addr_out   = {NUM_CPUS{i_demux_addr}};

    if (i_demux_cpu_id < NUM_CPUS) begin
      o_wr_en[i_demux_cpu_id] = i_demux_wr_en;
    end
  end

endmodule
`default_nettype wire
