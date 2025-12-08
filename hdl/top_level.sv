`timescale 1ns / 1ps `default_nettype none

module top_level (
    input wire clk_100mhz,
    input wire [3:0] btn,

    output logic [15:0] led,
    output logic [ 2:0] rgb0,
    output logic [ 2:0] rgb1,
    output logic [ 3:0] ss0_an,
    output logic [ 3:0] ss1_an,
    output logic [ 6:0] ss0_c,
    output logic [ 6:0] ss1_c,

    // HDMI Ports
    output logic [2:0] hdmi_tx_p,
    output logic [2:0] hdmi_tx_n,
    output logic       hdmi_clk_p,
    output logic       hdmi_clk_n,

    // Port 1 (Ingress)
    input wire eth1_clk,
    input wire eth1_crsdv,
    input wire [1:0] eth1_rxd,
    output logic eth1_txen,
    output logic [1:0] eth1_txd,

    // // Port 2 (Egress)
    input wire eth2_clk,
    input wire eth2_crsdv,
    input wire [1:0] eth2_rxd,
    output logic eth2_txen,
    output logic [1:0] eth2_txd
);
  //   // ------------------------------------------------------------------------
  //   // Buffer/FIFO Parameters
  //   // ------------------------------------------------------------------------
  //   localparam DISPLAY_FIFO_DEPTH = 64;

  // ------------------------------------------------------------------------
  // Clocking and Reset
  // ------------------------------------------------------------------------
  // TODO: double check how lab7 uses clk_100_passthrough and rst = sys_rst || !eth_locked
  logic sys_rst;
  assign sys_rst = btn[0];  // Active-high reset

  // logic clk_100mhz_buffered;
  logic clk_50mhz;
  logic eth_locked;
  logic clk_5x;
  logic clk_pixel;
  logic pixel_locked;


  cw_hdmi_clk_wiz hdmi_clk_wizard (
      .sysclk(clk_100mhz),
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(sys_rst),
      .locked(pixel_locked)
  );



  // ------------------------------------------------------------------------
  // Packet Counting and Packet Simulations
  // ------------------------------------------------------------------------
  // --- Packet Counter --

  // logic display_fifo_pop_valid;
  // logic display_fifo_pop_ready;
  // logic network_statistics_valid;

  // localparam PACKET_COUNT = 26;
  // localparam PUSH_CYCLES = 10_000_000;

  // // --- Statistics Signals ---
  // logic [31:0] cdc_dropped_packets;
  // logic [31:0] cdc_total_packets;
  // logic [31:0] cycle_count;
  // logic is_counting;

  // evt_counter #(
  //     .MAX_COUNT(PACKET_COUNT)
  // ) cycle_counter (
  //     .clk(clk_pixel),
  //     .rst(sys_rst),
  //     .evt(1),
  //     .added_num(1),
  //     .count(cdc_total_packets)
  // );
  // evt_counter #(
  //     .MAX_COUNT(PUSH_CYCLES)
  // ) push_counter (
  //     .clk(clk_pixel),
  //     .rst(sys_rst),
  //     .evt(is_counting),
  //     .added_num(1),
  //     .count(cycle_count)
  // );

  // assign cdc_dropped_packets = cdc_total_packets >> 1;

  // always_ff @(posedge clk_pixel) begin
  //   if (display_fifo_pop_valid) begin
  //     if (display_fifo_pop_ready) begin
  //       display_fifo_pop_valid <= 0;
  //     end else begin
  //       is_counting <= 0;
  //     end
  //   end else begin
  //     if (cycle_count == 9_999_999) begin
  //       display_fifo_pop_valid <= 1;
  //     end
  //     is_counting <= 1;
  //   end
  // end

  // logic [31:0] total_bytes;
  // logic [31:0] received_packets;
  // logic [31:0] sent_packets;

  // ------------------------------------------------------------------------
  // Counting Real Packets from Ethernet
  // ------------------------------------------------------------------------

  localparam SAMPLING_CYCLES = 100_000_000;
  logic display_fifo_push_ready;
  logic network_statistics_valid;
  logic [31:0] cycle_count;
  logic [1:0] sys_rst_network_buf;
  logic [31:0] prev_received_packets;
  logic [31:0] new_packets;

  always_ff @(posedge eth1_clk) begin
    sys_rst_network_buf = {sys_rst, sys_rst_network_buf[1]};
    if (sys_rst_network_buf[0]) begin
      prev_received_packets <= 0;
    end else begin
       if (cycle_count == SAMPLING_CYCLES - 1) begin
        network_statistics_valid <= 1;
        new_packets <= received_packets - prev_received_packets;
        prev_received_packets <= received_packets;
      end else begin
        network_statistics_valid <= 0;
      end
    end
  end

  evt_counter#(.MAX_COUNT(SAMPLING_CYCLES)) cycle_counter(.clk(eth1_clk), .rst(sys_rst_network_buf[0]), .evt(1), .added_num(1), .count(cycle_count));

  // ------------------------------------------------------------------------
  // Submodule Instantiation
  // ------------------------------------------------------------------------

  logic [31:0] total_bytes;
  logic [31:0] received_packets;
  logic [31:0] sent_packets;

  // --- Networking + BPF ---
  network_bpf network_bpf_submodule (
      .rst(sys_rst),

      // Ingress 
      .eth1_clk  (eth1_clk),
      .eth1_crsdv(eth1_crsdv),
      .eth1_rxd  (eth1_rxd),
      .eth1_txen (eth1_txen),
      .eth1_txd  (eth1_txd),

      // Egress
      .eth2_clk  (eth2_clk),
      .eth2_crsdv(eth2_crsdv),  // Pass-through
      .eth2_rxd  (eth2_rxd),    // Pass-through
      .eth2_txen (eth2_txen),   // Egress
      .eth2_txd  (eth2_txd),    // Egress

      //   // Push side of display_fifo
      //   .o_display_job_push (display_fifo_push_valid),
      //   .o_display_job_data (display_fifo_push_data),
      //   .i_display_fifo_full(display_fifo_full),

      // Statistics output
      .o_total_bytes(total_bytes),
      .o_received_packets(received_packets),
      .o_sent_packets(sent_packets)
  );


  // ------------------------------------------------------------------------
  // Clock Domain Crossing Communication FIFO & Statistics Instantiation
  // ------------------------------------------------------------------------
  logic [15:0] cdc_total_packets;
  logic [31:0] cdc_packet_data;

  async_init_fifo #(.DATA_WIDTH(32), .FIFO_DEPTH(32), .INIT_COUNT(0)) display_fifo_cdc (.rst(sys_rst_network_buf[0]), .push_clk(eth1_clk), .i_push_valid(network_statistics_valid), 
                                      .o_push_ready(display_fifo_push_ready), .i_push_data(new_packets), 
                                      .pop_clk(clk_pixel), .o_pop_valid(display_fifo_pop_valid), 
                                      .i_pop_ready(display_fifo_pop_ready), .o_pop_data(cdc_packet_data));
    
  logic display_fifo_pop_valid;
  logic display_fifo_pop_ready;
  logic [15:0] cdc_dropped_packets;
  assign cdc_total_packets = cdc_packet_data[31:16];
  assign cdc_dropped_packets = 0;

  
  // --- Display Controller ---
  display_controller display_controller_submodule (
      .clk_pixel(clk_pixel),
      .clk_5x(clk_5x),
      .rst_pixel(sys_rst),

      // Pop side of display_fifo
      .i_display_job_valid(display_fifo_pop_valid),
      .o_display_job_pop  (display_fifo_pop_ready),

      // Statistics input 
      .i_total_packets  (cdc_total_packets),
      .i_dropped_packets(cdc_dropped_packets),

      // HDMI Ports
      .o_hdmi_clk_p(hdmi_clk_p),
      .o_hdmi_clk_n(hdmi_clk_n),
      .o_hdmi_tx_p (hdmi_tx_p),
      .o_hdmi_tx_n (hdmi_tx_n)
  );

  // ------------------------------------------------------------------------
  // Debug Outputs
  // ------------------------------------------------------------------------

  logic [6:0] ss_c;
  seven_segment_controller scc (
      .clk(eth1_clk),
      .rst(sys_rst),
      .val({
        sent_packets[23:16], received_packets[23:16], sent_packets[7:0], received_packets[7:0]
      }),
      .cat(ss_c),
      .an({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c;
  assign ss1_c = ss_c;
  assign led[0] = display_fifo_pop_valid;
  assign led[1] = display_fifo_pop_ready;
  assign led[2] = network_statistics_valid;
  assign led[3] = display_fifo_push_ready;
  assign led[15:4] = received_packets[31:16];
  assign rgb0  = 3'b0;
  assign rgb1  = 3'b0;
endmodule

`default_nettype wire
