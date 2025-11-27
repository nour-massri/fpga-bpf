`default_nettype none
module evt_counter #(
    parameter MAX_COUNT = 40_000
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         evt,
    input  wire  [ 2:0] added_num,
    output logic [31:0] count
);
  always_ff @(posedge clk) begin
    if (rst) begin
      count <= 0;
    end else begin
      if (evt) begin
        if (count == MAX_COUNT - 1) begin
          count <= 0;
        end else begin
          count <= count + added_num;
        end
      end
    end
  end
endmodule
`default_nettype wire
