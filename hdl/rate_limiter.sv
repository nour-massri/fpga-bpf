`timescale 1ns / 1ps
`default_nettype none

module rate_limiter #(
    parameter MAX_PACKETS = 10
)(
    input wire clk,
    input wire rst,
    input wire [31:0] src_ip,
    input wire ip_valid,
    output logic rate_limit_pass
);

    logic [31:0] packet_counter;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            rate_limit_pass <= 0;
            packet_counter <= 0;
        end else begin
            if (ip_valid) begin
                if (packet_counter < MAX_PACKETS) begin
                    rate_limit_pass <= 1;
                    packet_counter <= packet_counter + 1;
                end else begin
                    rate_limit_pass <= 0;
                end
            end
        end
    end

endmodule

`default_nettype wire