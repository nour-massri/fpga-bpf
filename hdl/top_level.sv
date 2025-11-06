`timescale 1ns / 1ps
`default_nettype none

module top_level
    (
        input wire          clk_100mhz,
        
        output logic [15:0] led,
        input wire [15:0]   sw,
        input wire [3:0]    btn,
        output logic [2:0]  rgb0,
        output logic [2:0]  rgb1,

        // seven segment
        output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
        output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
        output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
        output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits

        // ethernet RMII interface
        input logic eth_crsdv,
        input logic[1:0] eth_rxd,

        output logic eth_txen,
        output logic[1:0] eth_txd,

        // // hdmi port
        // output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
        // output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
        // output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock

    );

endmodule // top_level


`default_nettype wire

