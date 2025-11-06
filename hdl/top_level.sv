`timescale 1ns / 1ps
`default_nettype none

module top_level (
    input wire clk_100mhz,
    
    output logic [15:0] led,
    input wire [3:0] btn,
    output logic [2:0] rgb0,
    output logic [2:0] rgb1,
    
    // Ethernet RMII interface
    input wire eth_crsdv,
    input wire [1:0] eth_rxd,
    output logic eth_txen,
    output logic [1:0] eth_txd
);

    logic sys_rst;
    logic clk_50mhz;
    logic eth_locked;
    
    assign sys_rst = btn[0];
    
    // Generate 50MHz clock
    cw_eth_50mhz eth_clock_gen (
        .clk_100mhz(clk_100mhz),
        .clk_50mhz(clk_50mhz),
        .reset(sys_rst),
        .locked(eth_locked)
    );
    
    // Send 50MHz to PHY
    // assign eth_refclk = clk_50mhz;
    
    // TX signals idle
    assign eth_txen = 1'b0;
    assign eth_txd = 2'b00;
    
    // Packet counter
    logic crsdv_prev;
    logic [15:0] packet_count;
    
    always_ff @(posedge clk_50mhz) begin
        if (sys_rst) begin
            packet_count <= 0;
            crsdv_prev <= 0;
        end else begin
            crsdv_prev <= eth_crsdv;
            if (eth_crsdv && !crsdv_prev) begin
                packet_count <= packet_count + 1;
            end
        end 
    end
    
    assign led[0] = eth_locked;
    assign led[1] = eth_crsdv;
    assign led[2] = |eth_rxd;
    assign led[15:3] = packet_count[12:0];
    
endmodule

`default_nettype wire