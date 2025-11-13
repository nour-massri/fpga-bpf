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

    input wire eth1_crsdv,
    input wire [1:0] eth1_rxd,
    output logic eth1_txen,
    output logic [1:0] eth1_txd,
    
    input wire eth2_crsdv,
    input wire [1:0] eth2_rxd,
    output logic eth2_txen,
    output logic [1:0] eth2_txd
);
    // 30 bytes * 4 cycles per byte + 1 rate lookup
    // localparam DECISION_LATENCY = 121;
    localparam DECISION_LATENCY = 2; // testing only
    logic sys_rst;
    assign sys_rst = btn[0];
    
    logic clk_50mhz;
    logic eth_locked;
    
    cw_eth_50mhz eth_clock_gen (
        .clk_100mhz(clk_100mhz),
        .clk_50mhz(clk_50mhz),
        .reset(sys_rst),
        .locked(eth_locked)
    );
    
    logic [6:0] eth1_packet_count;
    logic [6:0] eth2_packet_count;
    logic [31:0] dropped_packet_count;

    packet_counter total_packet_counts(
        .clk_50mhz(clk_50mhz),
        .sys_rst(sys_rst),
        .eth1_crsdv(eth1_crsdv),
        .eth2_crsdv(eth2_crsdv),
        .eth1_packet_count(eth1_packet_count),
        .eth2_packet_count(eth2_packet_count)
    );

    assign led[0] = eth_locked;
    assign led[7:1] = eth2_packet_count[6:0];
    assign led[14:8] = eth1_packet_count[6:0];
    assign led[15] = 1'b0;

    logic [6:0] ss_c;
    seven_segment_controller ssc (
        .clk(clk_50mhz),
        .rst(sys_rst),
        .val(dropped_packet_count),
        .cat(ss_c),
        .an({ss0_an, ss1_an})
    );
    assign ss0_c = ss_c;
    assign ss1_c = ss_c;
    
    assign eth1_txen = eth2_crsdv;
    assign eth1_txd = eth2_rxd;
    
    logic [31:0] src_ip;
    logic ip_valid;
    
    parser pkt_parser (
        .clk(clk_50mhz),
        .rst(sys_rst),
        .eth_crsdv(eth1_crsdv),
        .eth_rxd(eth1_rxd),
        .src_ip(src_ip),
        .ip_valid(ip_valid)
    );
    
    logic rate_limit_pass;
    
    rate_limiter limiter (
        .clk(clk_50mhz),
        .rst(sys_rst),
        .src_ip(src_ip),
        .ip_valid(ip_valid),
        .rate_limit_pass(rate_limit_pass)
    );
    
    logic [1:0] rxd_delayed;
    logic crsdv_delayed;
    
    pipeline #(.WIDTH(2), .DEPTH(DECISION_LATENCY)) rxd_pipe (
        .clk(clk_50mhz),
        .rst(sys_rst),
        .data_in(eth1_rxd),
        .data_out(rxd_delayed)
    );
    
    pipeline #(.WIDTH(1), .DEPTH(DECISION_LATENCY)) crsdv_pipe (
        .clk(clk_50mhz),
        .rst(sys_rst),
        .data_in(eth1_crsdv),
        .data_out(crsdv_delayed)
    );
    
    tx_filter_controller tx_filter (
        .clk(clk_50mhz),
        .rst(sys_rst),
        .crsdv_in(crsdv_delayed),
        .rxd_in(rxd_delayed),
        .rate_limit_pass(rate_limit_pass),
        .eth_txen(eth2_txen),
        .eth_txd(eth2_txd),
        .dropped_count(dropped_packet_count)
    );
    
endmodule

`default_nettype wire