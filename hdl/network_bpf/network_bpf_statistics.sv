`timescale 1ns / 1ps `default_nettype none

module network_bpf_statistics (
    input wire clk,
    input wire rst,

    input wire i_byte_active,
    input wire i_pkt_received,
    input wire i_pkt_dropped,

    output logic [31:0] o_total_bytes,
    output logic [31:0] o_received_packets,
    output logic [31:0] o_dropped_packets
);

  always_ff @(posedge clk) begin
    if (rst) begin
      o_total_bytes <= 32'h0;
      o_received_packets <= 32'h0;
      o_dropped_packets <= 32'h0;
    end else begin
      if (i_byte_active) begin
        o_total_bytes <= o_total_bytes + 32'h1;
      end
      if (i_pkt_received) begin
        o_received_packets <= o_received_packets + 32'h1;
      end
      if (i_pkt_dropped) begin
        o_dropped_packets <= o_dropped_packets + 32'h1;
      end
    end
  end

endmodule

`default_nettype wire
