`timescale 1ns / 1ps
`default_nettype none

module top_level (
    input wire clk_100mhz,
    
    output logic [15:0] led,
    input wire [3:0] btn,
    output logic [2:0] rgb0,
    output logic [2:0] rgb1,
    
    // Ethernet RMII interface
    // eth1: PMODB 
    // eth2: PMODA
    input wire eth1_crsdv,
    input wire eth2_crsdv,

    input wire [1:0] eth1_rxd,
    input wire [1:0] eth2_rxd,

    output logic eth1_txen,
    output logic eth2_txen,

    output logic [1:0] eth1_txd,
    output logic [1:0] eth2_txd
);

    logic sys_rst;
    logic clk_50mhz;
    logic eth_clk_locked;
    
    assign sys_rst = btn[0];
    
    cw_eth_50mhz eth_clock_gen (
        .clk_100mhz(clk_100mhz),
        .clk_50mhz(clk_50mhz),
        .reset(sys_rst),
        .locked(eth_clk_locked)
    );
    
    logic eth1_crsdv_prev;
    logic eth2_crsdv_prev;

    logic [6:0] eth1_packet_count;
    logic [6:0] eth2_packet_count;
    
    always_ff @(posedge clk_50mhz) begin
        if (sys_rst) begin
            eth1_packet_count <= 0;
            eth2_packet_count <= 0;

            eth1_crsdv_prev <= 0;
            eth2_crsdv_prev <= 0;
        end else begin

            eth1_crsdv_prev <= eth1_crsdv;
            eth2_crsdv_prev <= eth2_crsdv;

            if (eth1_crsdv && !eth1_crsdv_prev) begin
                eth1_packet_count <= eth1_packet_count + 1;
            end

            if (eth2_crsdv && !eth2_crsdv_prev) begin
                eth2_packet_count <= eth2_packet_count + 1;
            end
        end 
    end
    
    assign led[0] = eth_clk_locked;
    assign led[7:1] = eth1_packet_count[6:0];
    assign led[14:8] = eth2_packet_count[6:0];
    

    assign eth1_txen = eth2_crsdv;
    assign eth2_txen = eth1_crsdv;
    assign eth1_txd = eth2_rxd; 
    assign eth2_txd = eth1_rxd; 

endmodule

`default_nettype wire
