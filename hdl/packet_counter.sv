`timescale 1ns / 1ps
`default_nettype none

module packet_counter(
    input wire clk_50mhz,
    input wire sys_rst,
    input wire eth1_crsdv,
    input wire eth2_crsdv,
    output logic [6:0] eth1_packet_count,
    output logic [6:0] eth2_packet_count
);

    logic eth1_crsdv_prev;
    logic eth2_crsdv_prev;

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

endmodule

`default_nettype wire
    