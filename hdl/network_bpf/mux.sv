`timescale 1ns / 1ps `default_nettype none

// Round-Robin Mux
module mux
  import network_bpf_config_pkg::*;
#(
    parameter int DATA_WIDTH
) (
    input wire clk,
    input wire rst,

    // Array Inputs
    input  wire  [NUM_CPUS-1:0][DATA_WIDTH-1:0] i_pop_data,
    input  wire  [NUM_CPUS-1:0]                 i_pop_valid,
    output logic [NUM_CPUS-1:0]                 o_pop_ready,

    // Single Output
    output logic [CPU_ID_BITS-1:0] o_mux_pop_cpu_id,
    output logic [ DATA_WIDTH-1:0] o_mux_pop_data,
    output logic                   o_mux_pop_valid,
    input  wire                    i_mux_pop_ready
);

  logic [CPU_ID_BITS-1:0] rr_ptr;

  assign o_mux_pop_cpu_id = rr_ptr;
  assign o_mux_pop_data   = i_pop_data[rr_ptr];
  assign o_mux_pop_valid  = i_pop_valid[rr_ptr];

  always_comb begin
    o_pop_ready = '0;
    o_pop_ready[rr_ptr] = i_mux_pop_ready;
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      rr_ptr <= '0;
    end else begin
      // Advance counter only on successful handshake
      if (i_pop_valid[rr_ptr] && i_mux_pop_ready) begin
        if (rr_ptr == NUM_CPUS[CPU_ID_BITS-1:0] - 1) begin
          rr_ptr <= '0;
        end else begin
          rr_ptr <= rr_ptr + 1'b1;
        end
      end
    end
  end

endmodule
`default_nettype wire
