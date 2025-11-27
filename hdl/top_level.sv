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
    output logic [1:0] eth1_txd

    // // Port 2 (Egress)
    // input wire eth2_clk,
    // input wire eth2_crsdv,
    // input wire [1:0] eth2_rxd,
    // output logic eth2_txen,
    // output logic [1:0] eth2_txd
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

    // wire clk_100mhz_ibuf;
    // IBUF ibuf_clk100 (.I(clk_100mhz), .O(clk_100mhz_ibuf));
    // wire clk_100mhz_buffered;
    // BUFG bufg_clk100 (.I(clk_100mhz_ibuf), .O(clk_100mhz_buffered));
    
    // cw_eth_50mhz eth_clk_wizard (
    //     .clk_100mhz(clk_100mhz_buffered),
    //     .clk_50mhz(clk_50mhz),
    //     .reset(sys_rst),
    //     .locked(eth_locked)
    // );

    cw_hdmi_clk_wiz hdmi_clk_wizard (
        .sysclk(clk_100mhz),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(sys_rst)
    );



    // ------------------------------------------------------------------------
    // Packet Counting and Packet Simulations
    // ------------------------------------------------------------------------
    // --- Packet Counter --

    // logic display_fifo_push_ready;
    // logic display_fifo_pop_valid;
    logic display_fifo_pop_ready;
    // logic fifo_almost_full;
    // logic fifo_almost_empty;
    // logic network_statistics_valid;
    // logic [31:0] fifo_packet_count;

    localparam SAMPLING_CYCLES = 40_000;
    localparam PUSH_CYCLES = 10_000_000;
    // logic [31:0] packet_count;
    // logic prev_crsdv;
    // logic [31:0] cycle_count;
    // logic [1:0] sys_rst_network_buf;

  // --- Display Controller Work FIFO
  //   logic                display_fifo_push_valid;
  //   display_job_t        display_fifo_push_data;
  //   logic                display_fifo_full;
  //   logic                display_fifo_pop_ready;
  //   display_job_t        display_fifo_pop_data;
  //   logic                display_fifo_pop_valid;

  // --- Statistics Signals ---
    logic [31:0] total_bytes;  // From Network (eth1_clk)
    logic [31:0] recieved_packets;  // From Network (eth1_clk)
    logic [31:0] sent_packets;
    //   logic         [31:0] cdc_total_packets;  // To Display (clk_pixel)
    //   logic         [31:0] cdc_dropped_packets;  // To Display (clk_pixel)
    logic [31:0] cdc_dropped_packets;
    logic [31:0] cdc_total_packets;
    logic [31:0] push_count;
    logic [31:0] data_valid;
    logic is_counting;

    evt_counter#(.MAX_COUNT(SAMPLING_CYCLES)) cycle_counter(.clk(clk_pixel), .rst(sys_rst), .evt(1), .added_num(1), .count(cdc_total_packets));
    evt_counter#(.MAX_COUNT(PUSH_CYCLES)) push_counter(.clk(clk_pixel), .rst(sys_rst), .evt(is_counting), .added_num(1), .count(push_count));

    assign cdc_dropped_packets = cdc_total_packets >> 1;

    always_ff @(posedge clk_pixel) begin
        if (data_valid) begin
            if (display_fifo_pop_ready) begin
                data_valid <= 0;
            end else begin
                is_counting <= 0;
            end
        end else begin 
            if (push_count == 9_999_999) begin
                data_valid <= 1;
            end
            is_counting <= 1;
        end
    end


    // evt_counter#(.MAX_COUNT(SAMPLING_CYCLES)) cycle_counter(.clk(clk_50mhz), .rst(sys_rst), .evt(1), .added_num(1), .count(cycle_count));

    // always_ff @(posedge clk_50mhz) begin
    //     if (sys_rst) begin
    //         packet_count <= 0;
    //         sys_rst_network_buf <= 2'b00;
    //         cdc_dropped_packets <= 0;
    //     end else begin
    //         // Keep network rst synchronous with clk_50mhz
    //         sys_rst_network_buf = {sys_rst, sys_rst_network_buf[1]};

    //         if (!prev_crsdv && eth1_crsdv) begin
    //             packet_count <= packet_count + 1;
    //         end
    //         prev_crsdv <= eth1_crsdv;

    //         if (cycle_count == (SAMPLING_CYCLES - 1)) begin 
    //             packet_count <= 0;
    //             network_statistics_valid <= 1;
    //             fifo_packet_count <= packet_count;
    //         end else begin
    //             network_statistics_valid <= 0;
    //         end
    //     end
    // end

    // ------------------------------------------------------------------------
    // Clock Domain Crossing Communication FIFO & Statistics Instantiation
    // ------------------------------------------------------------------------

    // input wire 		sender_rst,
    // input wire 		sender_clk,
    // input wire 		sender_axis_tvalid,
    // output logic 	sender_axis_tready,
    // input wire [127:0] 	sender_axis_tdata,
    // input wire 		sender_axis_tlast,
    // output logic 	sender_axis_prog_full,

    // input wire 		receiver_clk,
    // output logic 	receiver_axis_tvalid,
    // input wire 		receiver_axis_tready,
    // output logic [127:0] receiver_axis_tdata,
    // output logic 	receiver_axis_tlast,
    // output logic 	receiver_axis_prog_empty

    // We assume sender_axis_tready to always be ready since we are sending one statistic per second
    // and the display channel is reading a new statistic every frame (60 fps)
    // clockdomain_fifo display_fifo (.sender_rst(sys_rst_network_buf[0]), .sender_clk(clk_50mhz), .sender_axis_tvalid(network_statistics_valid), 
    //                                     .sender_axis_tready(display_fifo_push_ready), .sender_axis_tdata(fifo_packet_count), .sender_axis_tlast(0), 
    //                                     .sender_axis_prog_full(fifo_almost_full), .receiver_clk(clk_pixel), .receiver_axis_tvalid(display_fifo_pop_valid), 
    //                                     .receiver_axis_tready(display_fifo_pop_ready), .receiver_axis_tdata(cdc_total_packets), .receiver_axis_prog_empty(fifo_almost_empty) );


    // ------------------------------------------------------------------------
    // Submodule Instantiation
    // ------------------------------------------------------------------------

    // --- Networking + BPF ---
    network_bpf network_bpf_submodule (
        .clk_50mhz(clk_50mhz),
        .rst(sys_rst),

        // Ingress 
        .eth1_clk  (eth1_clk),
        .eth1_crsdv(eth1_crsdv),
        .eth1_rxd  (eth1_rxd),
        .eth1_txen (eth1_txen),
        .eth1_txd  (eth1_txd),

        // Egress
        // .eth2_clk(eth2_clk),
        // .eth2_crsdv(eth2_crsdv),  // Pass-through
        // .eth2_rxd  (eth2_rxd),    // Pass-through
        // .eth2_txen (eth2_txen),   // Egress
        // .eth2_txd  (eth2_txd),    // Egress

        //   // Push side of display_fifo
        //   .o_display_job_push (display_fifo_push_valid),
        //   .o_display_job_data (display_fifo_push_data),
        //   .i_display_fifo_full(display_fifo_full),

        // Statistics output
        .o_total_bytes(total_bytes),
        .o_recieved_packets(recieved_packets),
        .o_sent_packets(sent_packets)
    );

    // --- Display Controller ---
    display_controller display_controller_submodule (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst_pixel(sys_rst),

        // Pop side of display_fifo
        // .i_display_job_valid(display_fifo_pop_valid),
        // .o_display_job_pop  (display_fifo_pop_ready),

        .i_display_job_valid(data_valid),
        .o_display_job_pop  (display_fifo_pop_ready),

        // Statistics input 
        .i_total_packets  (cdc_total_packets),
        .i_dropped_packets(cdc_dropped_packets),

        // HDMI Ports
        .o_hdmi_clk_p(hdmi_clk_p),
        .o_hdmi_clk_n(hdmi_clk_n),
        .o_hdmi_tx_p  (hdmi_tx_p),
        .o_hdmi_tx_n  (hdmi_tx_n)
    );

  // ------------------------------------------------------------------------
  // Debug Outputs
  // ------------------------------------------------------------------------

//   logic [6:0] ss_c;
//   seven_segment_controller scc (
//       .clk(clk_pixel),
//       .rst(sys_rst),
//       .val(cycle_count),
//       .cat(ss_c),
//       .an ({ss0_an, ss1_an})
//   );
//   assign ss0_c = ss_c;
//   assign ss1_c = ss_c;

//   assign led   = {prev_crsdv, eth_locked};
//   assign rgb0  = 3'b0;
//   assign rgb1  = 3'b0;

//   assign eth1_txen = eth1_crsdv;
//   assign eth1_txd = eth1_rxd;
endmodule

`default_nettype wire
