// `timescale 1ns / 1ps `default_nettype none

// module tx_filter_controller (
//     input wire clk,
//     input wire rst,
//     input wire crsdv_in,
//     input wire [1:0] rxd_in,
//     input wire rate_limit_pass,
//     output logic eth_txen,
//     output logic [1:0] eth_txd,
//     output logic [31:0] dropped_count
// );

//   logic pass_decision;
//   logic crsdv_prev;

//   always_ff @(posedge clk) begin
//     if (rst) begin
//       pass_decision <= 0;
//       dropped_count <= 0;
//       eth_txen <= 0;
//       eth_txd <= 0;
//       crsdv_prev <= 0;
//     end else begin
//       crsdv_prev <= crsdv_in;

//       if (crsdv_in && !crsdv_prev) begin
//         pass_decision <= rate_limit_pass;
//       end

//       if (!crsdv_in && crsdv_prev) begin
//         if (!pass_decision) begin
//           dropped_count <= dropped_count + 1;
//         end
//         pass_decision <= 0;
//       end

//       eth_txen <= crsdv_in && pass_decision;
//       eth_txd  <= rxd_in;
//     end
//   end

// endmodule

// `default_nettype wire
