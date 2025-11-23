// `timescale 1ns / 1ps
// `default_nettype none

// module network_bpf (
//     input wire clk_50mhz,
//     input wire rst,

//     // Port 1 (Ingress)
//     input wire eth1_crsdv,
//     input wire [1:0] eth1_rxd,
//     output logic eth1_txen,
//     output logic [1:0] eth1_txd,
    
//     // Port 2 (Egress)
//     input wire eth2_crsdv,
//     input wire [1:0] eth2_rxd,
//     output logic eth2_txen,
//     output logic [1:0] eth2_txd,

//     // Push side of display_fifo
//     output logic       o_display_job_push,
//     output display_job_t o_display_job_data,
//     input wire         i_display_fifo_full,

//     // Statistics output 
//     output logic [31:0] o_total_packets,
//     output logic [31:0] o_dropped_packets,
 
// );
 
//     // TODO: consider how to do parallel bpf cores with bpf dispatcher and tx reorder
//     // TODO: consider how to update BPF program during runtime through uart
//     // ------------------------------------------------------------------------
//     // Buffer/FIFO Parameters
//     // ------------------------------------------------------------------------
//     localparam int NUM_BUFFERS      = 4;
//     localparam int BUFFER_SIZE_POW2 = 2048;

//     localparam int BUF_ADDR_BITS    = $clog2(BUFFER_SIZE_POW2);
//     localparam int BUF_ID_BITS      = $clog2(NUM_BUFFERS);
//     localparam int BRAM_ADDR_BITS   = BUF_ID_BITS + BUF_ADDR_BITS;
//     localparam int BRAM_DEPTH       = 2**BRAM_ADDR_BITS;
//     localparam int BRAM_WIDTH       = 8;
//     localparam int FIFO_DEPTH       = NUM_BUFFERS + 1;

//     // ------------------------------------------------------------------------
//     // Communication Definitions 
//     // ------------------------------------------------------------------------

//     // 1. RX -> BPF
//     typedef struct packed {
//         logic [BUF_ID_BITS-1:0]   id;  // Which buffer to use
//         logic [BUF_ADDR_BITS-1:0] len; // Length of the packet
//     } rx_packet_desc_t;

//     // 2. BPF -> TX
//     typedef struct packed {
//         logic [BUF_ID_BITS-1:0]   id;
//         logic [BUF_ADDR_BITS-1:0] len;
//         bpf_status_t              status;
//     } tx_packet_desc_t;

//     // ------------------------------------------------------------------------
//     // Internal FIFO Interfaces
//     // ------------------------------------------------------------------------
    
//     // --- 1. Free Buffer FIFO (buffer IDs) ---
//     logic [BUF_ID_BITS-1:0] free_buf_push_data;
//     logic                   free_buf_push_valid;
//     logic                   free_buf_full;
//     logic [BUF_ID_BITS-1:0] free_buf_pop_data;
//     logic                   free_buf_pop_valid;
//     logic                   free_buf_pop_ready;

//     // --- 2. BPF Work FIFO (rx_packet_desc_t) ---
//     rx_packet_desc_t bpf_work_push_data;
//     logic            bpf_work_push_valid;
//     logic            bpf_work_full;
//     rx_packet_desc_t bpf_work_pop_data;
//     logic            bpf_work_pop_valid;
//     logic            bpf_work_pop_ready;

//     // --- 3. TX Work FIFO (tx_packet_desc_t) ---
//     tx_packet_desc_t tx_work_push_data;
//     logic            tx_work_push_valid;
//     logic            tx_work_full;
//     tx_packet_desc_t tx_work_pop_data;
//     logic            tx_work_pop_valid;
//     logic            tx_work_pop_ready;

//     // ------------------------------------------------------------------------
//     // Internal Statistics Signals
//     // ------------------------------------------------------------------------
//     logic pkt_received_pulse;
//     logic pkt_ingress_dropped_pulse;
//     logic pkt_bpf_dropped_pulse;
//     logic pkt_egress_dropped_pulse;
    
//     // ------------------------------------------------------------------------
//     // BRAM Interface Signals
//     // ------------------------------------------------------------------------
//     logic rx_wren;
//     logic [BRAM_ADDR_BITS-1:0] rx_wr_addr;
//     logic [BRAM_WIDTH-1:0]     rx_wr_data;
//     logic [BUF_ID_BITS-1:0]    rx_buf_id_out;
//     logic [BUF_ADDR_BITS-1:0]  rx_wr_addr_out;
//     assign rx_wr_addr = {rx_buf_id_out, rx_wr_addr_out};

//     logic bpf_rd_en;
//     logic [BRAM_ADDR_BITS-1:0] bpf_rd_addr;
//     logic [BRAM_WIDTH-1:0]     bpf_rd_data;
//     logic [BUF_ID_BITS-1:0]    bpf_buf_id_out;
//     logic [BUF_ADDR_BITS-1:0]  bpf_rd_addr_out;
//     assign bpf_rd_addr = {bpf_buf_id_out, bpf_rd_addr_out};
    
//     logic tx_rd_en;
//     logic [BRAM_ADDR_BITS-1:0] tx_rd_addr;
//     logic [BRAM_WIDTH-1:0]     tx_rd_data;
//     logic [BUF_ID_BITS-1:0]    tx_buf_id_out;
//     logic [BUF_ADDR_BITS-1:0]  tx_rd_addr_out;
//     assign tx_rd_addr = {tx_buf_id_out, tx_rd_addr_out};
    
//     // ------------------------------------------------------------------------
//     // BRAM Instantiation
//     // ------------------------------------------------------------------------
    
//     // //  Xilinx Single Port Read First RAM (Program ROM)
//     // xilinx_single_port_ram_read_first #(
//     //     .RAM_WIDTH(32),                       
//     //     .RAM_DEPTH(32),
//     //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
//     //     .INIT_FILE(`FPATH(bpf_program.mem))
//     // ) image_mem(
//     //     .addra(image_addr),
//     //     .dina(8'b0),
//     //     .clka(clk_50mhz),
//     //     .wea(1'b0),
//     //     .ena(1'b1),
//     //     .rsta(rst),
//     //     .regcea(1'b1),
//     //     .douta(color_index)
//     // );

//     xilinx_true_dual_port_read_first_1_clock_ram #(
//         .RAM_WIDTH(BRAM_WIDTH),
//         .RAM_DEPTH(BRAM_DEPTH)
//     ) bpf_packet_bram (
//         .clka( clk_50mhz ),
//         .addra( rx_wr_addr ),
//         .dina( rx_wr_data ),
//         .wea( rx_wren ),
//         .ena( 1'b1 ),
//         .rsta( rst ),
//         .douta(), // never read from this port
//         .addrb( bpf_rd_addr ),
//         .dinb( 0 ),
//         .web( 1'b0 ),
//         .enb( 1'b1 ),
//         .rstb( rst ),
//         .doutb( bpf_rd_data )
//     );

//     xilinx_true_dual_port_read_first_1_clock_ram #(
//         .RAM_WIDTH(BRAM_WIDTH),
//         .RAM_DEPTH(BRAM_DEPTH)
//     ) tx_packet_bram (
//         .clka( clk_50mhz ),
//         .addra( rx_wr_addr ),
//         .dina( rx_wr_data ),
//         .wea( rx_wren ),
//         .ena( 1'b1 ),
//         .rsta( rst ),
//         .douta(), // never read from this port 
//         .addrb( tx_rd_addr ),
//         .dinb( 0 ),
//         .web( 1'b0 ),
//         .enb( 1'b1 ),
//         .rstb( rst ),
//         .doutb( tx_rd_data )
//     );

//     // ------------------------------------------------------------------------
//     // Internal FIFO Instantiation
//     // ------------------------------------------------------------------------

//     // init with 1, 2, ..., NUM_BUFFERS 
//     fifo_init #(
//         .DATA_WIDTH(BUF_ID_BITS),
//         .FIFO_DEPTH(FIFO_DEPTH),
//         .INIT_COUNT(NUM_BUFFERS)
//     ) free_buf_fifo (
//         .clk(clk_50mhz),
//         .rst(rst),
//         .i_push_data(free_buf_push_data),
//         .i_push_valid(free_buf_push_valid),
//         .o_full(free_buf_full),
//         .o_pop_data(free_buf_pop_data),
//         .o_pop_valid(free_buf_pop_valid),
//         .i_pop_ready(free_buf_pop_ready)
//     );

//     fifo #(
//         .DATA_WIDTH($bits(rx_packet_desc_t)),
//         .FIFO_DEPTH(FIFO_DEPTH)
//     ) bpf_work_fifo (
//         .clk(clk_50mhz),
//         .rst(rst),
//         .i_push_data(bpf_work_push_data),
//         .i_push_valid(bpf_work_push_valid),
//         .o_full(bpf_work_full),
//         .o_pop_data(bpf_work_pop_data),
//         .o_pop_valid(bpf_work_pop_valid),
//         .i_pop_ready(bpf_work_pop_ready)
//     );
    
//     fifo #(
//         .DATA_WIDTH($bits(tx_packet_desc_t)),
//         .FIFO_DEPTH(FIFO_DEPTH)
//     ) tx_work_fifo (
//         .clk(clk_50mhz),
//         .rst(rst),
//         .i_push_data(tx_work_push_data),
//         .i_push_valid(tx_work_push_valid),
//         .o_full(tx_work_full),
//         .o_pop_data(tx_work_pop_data),
//         .o_pop_valid(tx_work_pop_valid),
//         .i_pop_ready(tx_work_pop_ready)
//     );

//     // ------------------------------------------------------------------------
//     // Core Module Instantiation
//     // ------------------------------------------------------------------------
//     eth_rx #(
//         .BUF_ID_BITS(BUF_ID_BITS),
//         .BUF_ADDR_BITS(BUF_ADDR_BITS)
//     ) eth_rx (
//         .clk(clk_50mhz),
//         .rst(rst),

//         .eth_crsdv(eth1_crsdv),
//         .eth_rxd(eth1_rxd),

//         .i_free_buf_id(free_buf_pop_data),
//         .i_free_buf_valid(free_buf_pop_valid),
//         .o_free_buf_pop(free_buf_pop_ready),

//         .o_bpf_work_desc(bpf_work_push_data),
//         .o_bpf_work_push(bpf_work_push_valid),
//         .i_bpf_work_full(bpf_work_full),

//         .o_wren(rx_wren),
//         .o_buf_id(rx_buf_id_out),
//         .o_wr_addr(rx_wr_addr_out),
//         .o_wr_data(rx_wr_data),

//         .o_pkt_received_pulse(pkt_received_pulse),
//         .o_pkt_ingress_dropped_pulse(pkt_ingress_dropped_pulse)
//     );
    
//     bpf_processor #(
//         .BUF_ID_BITS(BUF_ID_BITS),
//         .BUF_ADDR_BITS(BUF_ADDR_BITS)
//     ) bpf_processor (
//         .clk(clk_50mhz),
//         .rst(rst),
//         .i_bpf_work_desc(bpf_work_pop_data),
//         .i_bpf_work_valid(bpf_work_pop_valid),
//         .o_bpf_work_pop(bpf_work_pop_ready),

//         .o_tx_work_desc(tx_work_push_data),
//         .o_tx_work_push(tx_work_push_valid),
//         .i_tx_work_full(tx_work_full),
        
//         .o_display_job_push(o_display_job_push),
//         .o_display_job_data(o_display_job_data),
//         .i_display_fifo_full(i_display_fifo_full),

//         .o_rd_en(bpf_rd_en),
//         .o_buf_id(bpf_buf_id_out),
//         .o_rd_addr(bpf_rd_addr_out),
//         .i_rd_data(bpf_rd_data),
//         .o_pkt_bpf_dropped_pulse(pkt_bpf_dropped_pulse)
//     );

//     eth_tx #(
//         .BUF_ID_BITS(BUF_ID_BITS),
//         .BUF_ADDR_BITS(BUF_ADDR_BITS)
//     ) eth_tx (
//         .clk(clk_50mhz),
//         .rst(rst),

//         .eth_txen(eth2_txen),
//         .eth_txd(eth2_txd),

//         .i_tx_work_desc(tx_work_pop_data),
//         .i_tx_work_valid(tx_work_pop_valid),
//         .o_tx_work_pop(tx_work_pop_ready),

//         .o_ret_buf_id(free_buf_push_data),
//         .o_ret_buf_push(free_buf_push_valid),
//         .i_ret_buf_ready(!free_buf_full),

//         .o_rd_en(tx_rd_en),
//         .o_buf_id(tx_buf_id_out),
//         .o_rd_addr(tx_rd_addr_out),
//         .i_rd_data(tx_rd_data)
//     );

//     network_bpf_statistics stats (
//         .clk(clk_50mhz),
//         .rst(rst),

//         .i_pkt_received(pkt_received_pulse),
//         .i_pkt_ingress_dropped(pkt_ingress_dropped_pulse),
//         .i_pkt_bpf_dropped(pkt_bpf_dropped_pulse),

//         .o_total_packets(o_total_packets),
//         .o_dropped_packets(o_dropped_packets)
//     );

//     // ------------------------------------------------------------------------
//     // Direct pass through eth2 -> eth1 
//     // ------------------------------------------------------------------------
//     assign eth1_txen = eth2_crsdv;
//     assign eth1_txd = eth2_rxd;

// endmodule

// `default_nettype wire