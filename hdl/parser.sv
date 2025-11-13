`timescale 1ns / 1ps
`default_nettype none

module parser (
    input wire clk,
    input wire rst,
    input wire eth_crsdv,
    input wire [1:0] eth_rxd,
    output logic [31:0] src_ip,
    output logic ip_valid
);
    always_ff @(posedge clk) begin
        if(rst) begin
            ip_valid <= 0;
        end else begin 
            ip_valid <= 1;
        end
    end
endmodule

`default_nettype wire