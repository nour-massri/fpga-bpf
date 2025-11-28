`timescale 1ns / 1ps `default_nettype none

module async_init_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_DEPTH = 16,
    parameter int INIT_COUNT = 0
) (
    input wire rst,

    // Push side  
    input wire push_clk,
    input wire [DATA_WIDTH-1:0] i_push_data,
    input wire i_push_valid,
    output logic o_full,

    // Pop side 
    input wire pop_clk,
    output logic [DATA_WIDTH-1:0] o_pop_data,
    output logic o_pop_valid,
    input wire i_pop_ready
);

  logic [DATA_WIDTH-1:0] return_data;
  logic return_valid;
  logic return_full;
  logic return_ready;

  assign return_ready = ~return_full;

  async_fifo #(
      .DATA_WIDTH(DATA_WIDTH),
      .FIFO_DEPTH(FIFO_DEPTH)
  ) transport_fifo (
      .rst(rst),

      .push_clk(push_clk),
      .i_push_data(i_push_data),
      .i_push_valid(i_push_valid),
      .o_full(o_full),

      .pop_clk(pop_clk),
      .o_pop_data(return_data),
      .o_pop_valid(return_valid),
      .i_pop_ready(return_ready)
  );

  fifo #(
      .DATA_WIDTH(DATA_WIDTH),
      .FIFO_DEPTH(FIFO_DEPTH),
      .INIT_COUNT(INIT_COUNT)
  ) storage_fifo (
      .clk(pop_clk),
      .rst(rst),

      .i_push_data(return_data),
      .i_push_valid(return_valid),
      .o_full(return_full),

      .o_pop_data (o_pop_data),
      .o_pop_valid(o_pop_valid),
      .i_pop_ready(i_pop_ready)
  );
endmodule
`default_nettype wire
