`timescale 1ns / 1ps
`default_nettype none

module demux #(
    parameter int NUM_CPUS,
    parameter int CPU_ID_BITS, 
    parameter int DATA_WIDTH  
) (
    input wire clk,
    input wire rst,

    // Single Input 
    input wire  [CPU_ID_BITS-1:0] i_demux_cpu_id,
    input wire  [DATA_WIDTH-1:0]  i_demux_push_data,
    input wire                    i_demux_push_valid,
    output logic                  o_demux_push_ready,

    // Array Outputs
    output logic [NUM_CPUS-1:0][DATA_WIDTH-1:0] o_push_data,
    output logic [NUM_CPUS-1:0]                 o_push_valid,
    input wire   [NUM_CPUS-1:0]                 i_push_ready
);

    always_comb begin
        o_push_valid       = '0;
        o_push_data        = {NUM_CPUS{i_demux_push_data}}; // Broadcast data to all (only valid will latch)
        o_demux_push_ready = 1'b0;

        if (i_demux_cpu_id < NUM_CPUS) begin
            o_push_valid[i_demux_cpu_id] = i_demux_push_valid;
            o_demux_push_ready           = i_push_ready[i_demux_cpu_id];
        end
    end

endmodule
`default_nettype wire