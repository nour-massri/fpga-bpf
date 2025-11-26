// `timescale 1ns / 1ps
// `default_nettype none
// `include "packet_defs.svh"
// module bpf_processor #(
//     parameter int BUF_ID_BITS = 2,
//     parameter int BUF_ADDR_BITS = 11
// ) (
//     input wire clk,
//     input wire rst,

//     // Pop side of bpf_work fifo
//     input packet_desc_t i_bpf_work_desc,
//     input wire i_bpf_work_valid,
//     output logic o_bpf_work_pop,

//     // Push side of tx_work fifo
//     output packet_desc_t o_tx_work_desc,
//     output logic o_tx_work_push,
//     input wire i_tx_work_full,

//     // // Push side of display_job fifo
//     // output logic o_display_job_push,
//     // output display_job_t o_display_job_data,
//     // input wire i_display_fifo_full,

//     // BRAM read 
//     output logic o_rd_en,
//     output logic [BUF_ID_BITS-1:0] o_buf_id,
//     output logic [BUF_ADDR_BITS-1:0] o_rd_addr,
//     input wire [7:0] i_rd_data,

//     // Statistics
//     output logic o_pkt_bpf_dropped_pulse
// );

//     assign o_tx_work_desc = i_bpf_work_desc;
//     assign o_tx_work_push = i_bpf_work_valid;
//     assign o_bpf_work_pop = !i_tx_work_full;
//     assign o_rd_en = 0;
//     assign o_pkt_bpf_dropped_pulse = 0; 
// endmodule

// `default_nettype wire
