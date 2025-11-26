`timescale 1ns / 1ps
`default_nettype none
`include "packet_defs.svh"

module network_bpf (
    input wire clk_50mhz,
    input wire rst,

    // Port 1 (Ingress)
    input wire eth1_clk,
    input wire eth1_crsdv,
    input wire [1:0] eth1_rxd,
    output logic eth1_txen,
    output logic [1:0] eth1_txd,
    
    // // Port 2 (Egress)
    // input wire eth2_clk, 
    // input wire eth2_crsdv,
    // input wire [1:0] eth2_rxd,
    // output logic eth2_txen,
    // output logic [1:0] eth2_txd,

    // // Push side of display_fifo
    // output logic       o_display_job_push,
    // output display_job_t o_display_job_data,
    // input wire         i_display_fifo_full,

    // Statistics output 
    output logic [31:0] o_total_bytes,
    output logic [31:0] o_recieved_packets,
    output logic [31:0] o_sent_packets 
);
 
    // TODO: consider how to do parallel bpf cores with bpf dispatcher and tx reorder
    // TODO: consider how to update BPF program during runtime through uart
    // ------------------------------------------------------------------------
    // Buffer/FIFO Parameters
    // ------------------------------------------------------------------------
    localparam int NUM_BUFFERS      = 32;
    localparam int BUFFER_SIZE_POW2 = 1024;

    localparam int BUF_ADDR_BITS    = $clog2(BUFFER_SIZE_POW2);
    localparam int BUF_ID_BITS      = $clog2(NUM_BUFFERS);
    localparam int BRAM_ADDR_BITS   = BUF_ID_BITS + BUF_ADDR_BITS;
    localparam int BRAM_DEPTH       = 2**BRAM_ADDR_BITS;
    localparam int BRAM_WIDTH       = 8;
    localparam int FIFO_DEPTH       = NUM_BUFFERS;

    // ------------------------------------------------------------------------
    // Internal FIFO Interfaces
    // ------------------------------------------------------------------------
    
    // --- 1. Free Buffer FIFO (buffer IDs) ---
    logic [BUF_ID_BITS-1:0] free_buf_push_data;
    logic                   free_buf_push_valid;
    logic                   free_buf_full;
    logic [BUF_ID_BITS-1:0] free_buf_pop_data;
    logic                   free_buf_pop_valid;
    logic                   free_buf_pop_ready;

    // --- 2. BPF Work FIFO (packet_desc_t) ---
    packet_desc_t bpf_work_push_data;
    logic            bpf_work_push_valid;
    logic            bpf_work_full;
    packet_desc_t bpf_work_pop_data;
    logic            bpf_work_pop_valid;
    logic            bpf_work_pop_ready;

    // --- 3. TX Work FIFO (packet_desc_t) ---
    packet_desc_t tx_work_push_data;
    logic            tx_work_push_valid;
    logic            tx_work_full;
    packet_desc_t tx_work_pop_data;
    logic            tx_work_pop_valid;
    logic            tx_work_pop_ready;

    // ------------------------------------------------------------------------
    // Internal Statistics Signals
    // ------------------------------------------------------------------------
    logic pkt_ingress_byte_active;
    logic pkt_ingress_received_pulse;
    logic pkt_ingress_sent_pulse;

    logic pkt_bpf_dropped_pulse;

    logic pkt_egress_byte_active;
    logic pkt_egress_received_pulse;
    logic pkt_egress_sent_pulse;

    // ------------------------------------------------------------------------
    // BRAM Interface Signals
    // ------------------------------------------------------------------------
    logic rx_wren;
    logic [BRAM_ADDR_BITS-1:0] rx_wr_addr;
    logic [BRAM_WIDTH-1:0]     rx_wr_data;
    logic [BUF_ID_BITS-1:0]    rx_buf_id_out;
    logic [BUF_ADDR_BITS-1:0]  rx_wr_addr_out;
    assign rx_wr_addr = {rx_buf_id_out, rx_wr_addr_out};

    logic bpf_rd_en;
    logic [BRAM_ADDR_BITS-1:0] bpf_rd_addr;
    logic [BRAM_WIDTH-1:0]     bpf_rd_data;
    logic [BUF_ID_BITS-1:0]    bpf_buf_id_out;
    logic [BUF_ADDR_BITS-1:0]  bpf_rd_addr_out;
    assign bpf_rd_addr = {bpf_buf_id_out, bpf_rd_addr_out};
    
    logic tx_rd_en;
    logic [BRAM_ADDR_BITS-1:0] tx_rd_addr;
    logic [BRAM_WIDTH-1:0]     tx_rd_data;
    logic [BUF_ID_BITS-1:0]    tx_buf_id_out;
    logic [BUF_ADDR_BITS-1:0]  tx_rd_addr_out;
    assign tx_rd_addr = {tx_buf_id_out, tx_rd_addr_out};
    
    // ------------------------------------------------------------------------
    // BRAM Instantiation
    // ------------------------------------------------------------------------
    
    // //  Xilinx Single Port Read First RAM (Program ROM)
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(32),                       
    //     .RAM_DEPTH(32),
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
    //     .INIT_FILE(`FPATH(bpf_program.mem))
    // ) image_mem(
    //     .addra(image_addr),
    //     .dina(8'b0),
    //     .clka(eth1_clk),
    //     .wea(1'b0),
    //     .ena(1'b1),
    //     .rsta(rst),
    //     .regcea(1'b1),
    //     .douta(color_index)
    // );

    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(BRAM_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH)
    ) bpf_packet_bram (
        .clka( eth1_clk ),
        .addra( rx_wr_addr ),
        .dina( rx_wr_data ),
        .wea( rx_wren ),
        .ena( 1'b1 ),
        .regcea( 1'b1 ),
        .rsta( rst ),
        .douta(), // never read from this port
        .addrb( bpf_rd_addr ),
        .dinb( 0 ),
        .web( 1'b0 ),
        .enb( 1'b1 ),
        .regceb( 1'b1 ),
        .rstb( rst ),
        .doutb( bpf_rd_data )
    );

    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(BRAM_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH)
    ) tx_packet_bram (
        .clka( eth1_clk ),
        .addra( rx_wr_addr ),
        .dina( rx_wr_data ),
        .wea( rx_wren ),
        .ena( 1'b1 ),
        .regcea( 1'b1 ),
        .rsta( rst ),
        .douta(), // never read from this port 
        .addrb( tx_rd_addr ),
        .dinb( 0 ),
        .web( 1'b0 ),
        .enb( 1'b1 ),
        .regceb( 1'b1 ),
        .rstb( rst ),
        .doutb( tx_rd_data )
    );

    // ------------------------------------------------------------------------
    // Internal FIFO Instantiation
    // ------------------------------------------------------------------------

    fifo #(
        .DATA_WIDTH(BUF_ID_BITS),
        .FIFO_DEPTH(FIFO_DEPTH),
        .INIT_COUNT(NUM_BUFFERS)
    ) free_buf_fifo (
        .clk(eth1_clk),
        .rst(rst),
        .i_push_data(free_buf_push_data),
        .i_push_valid(free_buf_push_valid),
        .o_full(free_buf_full),
        .o_pop_data(free_buf_pop_data),
        .o_pop_valid(free_buf_pop_valid),
        .i_pop_ready(free_buf_pop_ready)
    );

    fifo #(
        .DATA_WIDTH($bits(packet_desc_t)),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) bpf_work_fifo (
        .clk(eth1_clk),
        .rst(rst),
        .i_push_data(bpf_work_push_data),
        .i_push_valid(bpf_work_push_valid),
        .o_full(bpf_work_full),
        .o_pop_data(bpf_work_pop_data),
        .o_pop_valid(bpf_work_pop_valid),
        .i_pop_ready(bpf_work_pop_ready)
    );
    
    fifo #(
        .DATA_WIDTH($bits(packet_desc_t)),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) tx_work_fifo (
        .clk(eth1_clk),
        .rst(rst),
        .i_push_data(tx_work_push_data),
        .i_push_valid(tx_work_push_valid),
        .o_full(tx_work_full),
        .o_pop_data(tx_work_pop_data),
        .o_pop_valid(tx_work_pop_valid),
        .i_pop_ready(tx_work_pop_ready)
    );

    // ------------------------------------------------------------------------
    // Core Module Instantiation
    // ------------------------------------------------------------------------
    eth_rx #(
        .BUF_ID_BITS(BUF_ID_BITS),
        .BUF_ADDR_BITS(BUF_ADDR_BITS)
    ) eth_rx (
        .clk(eth1_clk),
        .rst(rst),

        .eth_clk(eth1_clk),
        .eth_crsdv(eth1_crsdv),
        .eth_rxd(eth1_rxd),

        .i_free_buf_id(free_buf_pop_data),
        .i_free_buf_valid(free_buf_pop_valid),
        .o_free_buf_pop(free_buf_pop_ready),

        .o_bpf_work_desc(tx_work_push_data),
        .o_bpf_work_push(tx_work_push_valid),
        .i_bpf_work_full(tx_work_full),

        .o_wren(rx_wren),
        .o_buf_id(rx_buf_id_out),
        .o_wr_addr(rx_wr_addr_out),
        .o_wr_data(rx_wr_data),

        .o_byte_active(pkt_ingress_byte_active),
        .o_pkt_received_pulse(pkt_ingress_received_pulse),
        .o_pkt_sent_pulse(pkt_ingress_sent_pulse)
    );
    
    // bpf_processor #(
    //     .BUF_ID_BITS(BUF_ID_BITS),
    //     .BUF_ADDR_BITS(BUF_ADDR_BITS)
    // ) bpf_processor (
    //     .clk(eth1_clk),
    //     .rst(rst),
    //     .i_bpf_work_desc(bpf_work_pop_data),
    //     .i_bpf_work_valid(bpf_work_pop_valid),
    //     .o_bpf_work_pop(bpf_work_pop_ready),

    //     .o_tx_work_desc(tx_work_push_data),
    //     .o_tx_work_push(tx_work_push_valid),
    //     .i_tx_work_full(tx_work_full),
        
    //     // .o_display_job_push(o_display_job_push),
    //     // .o_display_job_data(o_display_job_data),
    //     // .i_display_fifo_full(i_display_fifo_full),

    //     .o_rd_en(bpf_rd_en),
    //     .o_buf_id(bpf_buf_id_out),
    //     .o_rd_addr(bpf_rd_addr_out),
    //     .i_rd_data(bpf_rd_data),

    //     .o_pkt_bpf_dropped_pulse(pkt_bpf_dropped_pulse)
    // );

    eth_tx #(
        .BUF_ID_BITS(BUF_ID_BITS),
        .BUF_ADDR_BITS(BUF_ADDR_BITS)
    ) eth_tx (
        .clk(eth1_clk),
        .rst(rst),

        .eth_clk(eth1_clk),
        .eth_txen(eth1_txen),
        .eth_txd(eth1_txd),

        .i_tx_work_desc(tx_work_pop_data),
        .i_tx_work_valid(tx_work_pop_valid),
        .o_tx_work_pop(tx_work_pop_ready),

        .o_ret_buf_id(free_buf_push_data),
        .o_ret_buf_push(free_buf_push_valid),
        .i_ret_buf_ready(!free_buf_full),

        .o_rd_en(tx_rd_en),
        .o_buf_id(tx_buf_id_out),
        .o_rd_addr(tx_rd_addr_out),
        .i_rd_data(tx_rd_data),

        .o_byte_active(pkt_egress_byte_active),
        .o_pkt_received_pulse(pkt_egress_received_pulse),
        .o_pkt_sent_pulse(pkt_egress_sent_pulse)
    );

    logic [31:0] ingress_total_bytes, ingress_received_packets, ingress_sent_packets;
    logic [31:0] egress_total_bytes, egress_received_packets, egress_sent_packets;

    network_bpf_statistics inress_stats (
        .clk(eth1_clk),
        .rst(rst),
        .i_byte_active(pkt_ingress_byte_active),
        .i_pkt_recieved(pkt_ingress_received_pulse),
        .i_pkt_sent(pkt_ingress_sent_pulse),

        .o_total_bytes(ingress_total_bytes),
        .o_recieved_packets(ingress_received_packets),
        .o_sent_packets(ingress_sent_packets)
    );

    network_bpf_statistics egress_stats (
        .clk(eth1_clk),
        .rst(rst),
        .i_byte_active(pkt_egress_byte_active),
        .i_pkt_recieved(pkt_egress_received_pulse),
        .i_pkt_sent(pkt_egress_sent_pulse),

        .o_total_bytes(egress_total_bytes),
        .o_recieved_packets(egress_received_packets),
        .o_sent_packets(egress_sent_packets)
    );
    assign o_total_bytes = {ingress_total_bytes[15:0], egress_total_bytes[15:0]};
    assign o_recieved_packets = {ingress_received_packets[15:0], egress_received_packets[15:0]};
    assign o_sent_packets = {ingress_sent_packets[15:0], egress_sent_packets[15:0]};
    // ------------------------------------------------------------------------
    // Direct pass through eth2 -> eth1 
    // ------------------------------------------------------------------------

//     logic prev_crsdv;
//     logic sending;
//     always_ff @(posedge eth1_clk) begin
//     if (!eth1_crsdv) begin
//         eth1_txen <= 0;
//         eth1_txd  <= 0;
//         sending   <= 0;
//     end
//     else if (sending) begin
//         eth1_txen <= 1;
//         eth1_txd  <= eth1_rxd;
//     end
//     else if (eth1_rxd == 2'b01) begin
//         sending   <= 1;
//         eth1_txen <= 1;       // Now we assert TX_EN
//         eth1_txd  <= 2'b01;   // And we send the first '01'

//    end
   
//     prev_crsdv <= eth1_crsdv;
//     pkt_received_pulse <= (!prev_crsdv && eth1_crsdv);
//     end

endmodule

`default_nettype wire