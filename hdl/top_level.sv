`timescale 1ns / 1ps
`default_nettype none

module top_level (
    input wire clk_100mhz,
    input wire [3:0] btn,
    
    output logic [15:0] led,
    output logic [2:0] rgb0,
    output logic [2:0] rgb1,
    output logic [3:0] ss0_an,
    output logic [3:0] ss1_an,
    output logic [6:0] ss0_c,
    output logic [6:0] ss1_c,
    
    // hdmi port
    output logic [2:0]  hdmi_tx_p, 
    output logic [2:0]  hdmi_tx_n, 
    output logic        hdmi_clk_p, hdmi_clk_n,

    // Port 1 (Ingress)
    input wire eth1_crsdv,
    input wire [1:0] eth1_rxd,
    output logic eth1_txen,
    output logic [1:0] eth1_txd,
    
    // Port 2 (Egress)
    input wire eth2_crsdv,
    input wire [1:0] eth2_rxd,
    output logic eth2_txen,
    output logic [1:0] eth2_txd
);
    // ------------------------------------------------------------------------
    // Buffer/FIFO Parameters
    // ------------------------------------------------------------------------
    localparam DISPLAY_FIFO_DEPTH = 64;

    // ------------------------------------------------------------------------
    // Clocking and Reset
    // ------------------------------------------------------------------------
    // TODO: double check how lab7 uses clk_100_passthrough and rst = sys_rst || !eth_locked
    logic sys_rst;
    assign sys_rst = btn[0]; // Active-high reset
    
    logic clk_50mhz;
    logic eth_locked;
    logic clk_5x;
    logic clk_pixel;
    
    cw_eth_50mhz eth_clk_wizard (
        .clk_100mhz(clk_100mhz),
        .clk_50mhz(clk_50mhz),
        .reset(sys_rst),
        .locked(eth_locked)
    );
    
    cw_hdmi_clk_wiz hdmi_clk_wizard (
        .sysclk(clk_100mhz),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(sys_rst)
    );

    // ------------------------------------------------------------------------
    // Communication Definitions 
    // ------------------------------------------------------------------------
    typedef enum logic { ACCEPT, DROP } bpf_status_t;
    typedef struct packed {
        bpf_status_t status;
        logic [31:0] src_ip;
        logic [31:0] dst_ip;
        logic [15:0] src_port;
        logic [15:0] dst_port;
    } display_job_t;

    // ------------------------------------------------------------------------
    // Communication Queues & Wires
    // ------------------------------------------------------------------------
    
    // --- Display Controller Work FIFO
    logic         display_fifo_push_valid; 
    display_job_t   display_fifo_push_data;  
    logic         display_fifo_full;       
    logic         display_fifo_pop_ready;  
    display_job_t   display_fifo_pop_data;   
    logic         display_fifo_pop_valid;  

    // --- Statistics Signals ---
    logic [31:0] total_packets_count;   // From Network (clk_50mhz)
    logic [31:0] dropped_packets_count; // From Network (clk_50mhz)
    logic [31:0] cdc_total_packets;     // To Display (clk_pixel)
    logic [31:0] cdc_dropped_packets;   // To Display (clk_pixel)

    // ------------------------------------------------------------------------
    // Clock Domain Crossing Communication FIFO & Statistics Instantiation
    // ------------------------------------------------------------------------

    // --- Network + BPF -> Display Work queue ---
    fifo_cdc #(
        .DATA_WIDTH($bits(display_job_t)),
        .FIFO_DEPTH(DISPLAY_FIFO_DEPTH)
    ) display_fifo_cdc (
        .push_clk(clk_50mhz),
        .push_rst(sys_rst),
        .i_push_data(display_fifo_push_data),
        .i_push_valid(display_fifo_push_valid),
        .o_full(display_fifo_full),
        
        .pop_clk(clk_pixel), 
        .pop_rst(sys_rst),
        .o_pop_data(display_fifo_pop_data),
        .o_pop_valid(display_fifo_pop_valid),
        .i_pop_ready(display_fifo_pop_ready)
    );

    // --- Network + BPF -> Display Statistics Synchronizer ---
    statistics_cdc display_statistics_cdc (
        .clk_a(clk_50mhz),
        .rst_a(sys_rst),
        .i_total_count_a(total_packets_count),
        .i_dropped_count_a(dropped_packets_count),
        
        .clk_b(clk_pixel),
        .rst_b(sys_rst),
        .o_total_count_b(cdc_total_packets),
        .o_dropped_count_b(cdc_dropped_packets)
    );

    // ------------------------------------------------------------------------
    // Submodule Instantiation
    // ------------------------------------------------------------------------

    // --- Networking + BPF ---
    network_bpf network_bpf_submodule (
        .clk_50mhz(clk_50mhz),
        .rst(sys_rst),

        // Ethernet Ports
        .eth1_crsdv(eth1_crsdv), // Ingress
        .eth1_rxd(eth1_rxd),    // Ingress 
        .eth1_txen(eth1_txen), // Pass-through
        .eth1_txd(eth1_txd),   // Pass-through
        .eth2_crsdv(eth2_crsdv), // Pass-through
        .eth2_rxd(eth2_rxd),   // Pass-through
        .eth2_txen(eth2_txen), // Egress
        .eth2_txd(eth2_txd),   // Egress
        
        // Push side of display_fifo
        .o_display_job_push(display_fifo_push_valid),
        .o_display_job_data(display_fifo_push_data),
        .i_display_fifo_full(display_fifo_full),

        // Statistics output
        .o_total_packets(total_packets_count),
        .o_dropped_packets(dropped_packets_count),
    );
    
    // --- Display Controller ---
    display_controller display_controller_submodule (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst_pixel(sys_rst),
        
        // Pop side of display_fifo
        .i_display_job_valid(display_fifo_pop_valid),
        .i_display_job_data(display_fifo_pop_data),
        .o_display_job_pop(display_fifo_pop_ready),
        
        // Statistics input 
        .i_total_packets(cdc_total_packets),
        .i_dropped_packets(cdc_dropped_packets),

        // HDMI Ports
        .o_hdmi_clk_p(hdmi_clk_p),
        .o_hdmi_clk_n(hdmi_clk_n),
        .o_hdmi_d_p(hdmi_tx_p),
        .o_hdmi_d_n(hdmi_tx_n)
    );

    // ------------------------------------------------------------------------
    // Debug Outputs
    // ------------------------------------------------------------------------

    logic [6:0] ss_c;
    seven_segment_controller scc (
        .clk(clk_pixel),
        .rst(sys_rst),
        .val({cdc_dropped_packets[15:0], cdc_total_packets[15:0]}),
        .cat(ss_c),
        .an({ss0_an, ss1_an})
    );
    assign ss0_c = ss_c;
    assign ss1_c = ss_c;

    assign led = {15'b0, eth_locked}; 
    assign rgb0 = 3'b0;
    assign rgb1 = 3'b0;
endmodule

`default_nettype wire