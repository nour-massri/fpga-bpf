`timescale 1ns / 1ps `default_nettype none

module rmii_to_byte (
    input wire clk,
    input wire rst,

    input wire eth_crsdv,
    input wire [1:0] eth_rxd,

    output logic o_byte_valid,
    output logic [7:0] o_byte_data,
    output logic carrier_detected
);

  // when crsdv goes high, need to wait for the preamble first 01 to start accumulating byte
  // also ethernet is LSB first
  logic [1:0] dibit_count;
  logic receiving;

  always_ff @(posedge clk) begin
    if (rst) begin
      dibit_count <= 2'd0;
      receiving <= 1'b0;

      o_byte_valid <= 1'b0;
      o_byte_data <= 8'h00;
      carrier_detected <= 1'b0;
    end else begin
      o_byte_valid <= receiving && (dibit_count == 2'd3);
      carrier_detected <= eth_crsdv;

      if (!eth_crsdv) begin
        receiving   <= 1'b0;
        dibit_count <= 2'd0;
        o_byte_data <= 8'h00;
      end else begin
        if (receiving) begin
          o_byte_data <= {eth_rxd, o_byte_data[7:2]};
          dibit_count <= dibit_count + 1'b1;
        end else if (eth_rxd == 2'b01) begin
          // wait for the first 01 in preamble according to datasheet
          receiving   <= 1'b1;
          o_byte_data <= {eth_rxd, o_byte_data[7:2]};
          dibit_count <= 2'd1;
        end

      end
    end
  end

endmodule
`default_nettype wire
