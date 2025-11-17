`timescale 1ns / 1ps `default_nettype none

module pipeline #(
    parameter WIDTH = 8,
    parameter DEPTH = 1
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

  generate
    if (DEPTH == 0) begin
      assign data_out = data_in;
    end else begin
      logic [WIDTH-1:0] pipe_stages[DEPTH-1:0];

      always_ff @(posedge clk) begin
        if (rst) begin
          for (int i = 0; i < DEPTH; i = i + 1) begin
            pipe_stages[i] <= 0;
          end
        end else begin
          pipe_stages[0] <= data_in;
          for (int i = 1; i < DEPTH; i = i + 1) begin
            pipe_stages[i] <= pipe_stages[i-1];
          end
        end
      end

      assign data_out = pipe_stages[DEPTH-1];
    end
  endgenerate

endmodule

`default_nettype wire
