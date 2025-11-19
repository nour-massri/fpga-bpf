`timescale 1ns / 1ps `default_nettype none

module display_controller #(
    parameter UNIT_WIDTH = 16,
    parameter UNIT_HEIGHT = 16,
    parameter ORIGIN_X = 40,
    parameter ORIGIN_Y = 40,
    parameter WIDTH = 1200,
    parameter HEIGHT = 640
    ) (
    input wire clk_pixel,
    input wire clk_5x,
    input wire rst_pixel,

    // Pop side of display_fifo
    input  wire          i_display_job_valid,
    input  display_job_t i_display_job_data,
    output logic         o_display_job_pop,

    // Statistics input 
    input wire [31:0] i_total_packets,
    input wire [31:0] i_dropped_packets,

    // HDMI Ports
    output logic [2:0]  hdmi_tx_p, 
    output logic [2:0]  hdmi_tx_n, 
    output logic        hdmi_clk_p, hdmi_clk_n,
);

  // ------------------------------------------------------------------------
  // HDMI Parameters 
  // ------------------------------------------------------------------------
  localparam H_PIXELS = 1280;
  localparam H_FRONT_PORCH = 110;
  localparam H_SYNC = 40;
  localparam H_BACK_PORCH = 220;

  localparam V_LINES = 720;
  localparam V_FRONT_PORCH = 5;
  localparam V_SYNC = 5; 
  localparam V_BACK_PORCH = 20;

  localparam FPS = 60;
  // ------------------------------------------------------------------------
  // HDMI internal signals
  // ------------------------------------------------------------------------

  logic [$clog2(H_PIXELS+H_FP+H_SYNC+H_BP)-1:0] h_count;
  logic [$clog2(V_LINES+V_FP+V_SYNC+V_BP)-1:0] v_count;
  logic v_sync, h_sync, active_draw, new_frame;
  logic [7:0] red, green, blue;
  logic [9:0] tmds_10b   [0:2];  //output of each TMDS encoder!
  logic       tmds_signal[2:0];  //output of each TMDS serializer!

  video_sig_gen #(
      .ACTIVE_H_PIXELS(H_PIXELS),
      .H_FRONT_PORCH(H_FP),
      .H_SYNC_WIDTH(H_SYNC),
      .H_BACK_PORCH(H_BP),
      .ACTIVE_LINES(V_LINES),
      .V_FRONT_PORCH(V_FP),
      .V_SYNC_WIDTH(V_SYNC),
      .V_BACK_PORCH(V_BP)
  ) vsg (
      .pixel_clk(clk_pixel),
      .rst(rst_pixel),
      .h_count(h_count),
      .v_count(v_count),
      .v_sync(v_sync),
      .h_sync(h_sync),
      .active_draw(active_draw),
      .new_frame(new_frame)
  );
  // ------------------------------------------------------------------------
  // Frame logic 
  // ------------------------------------------------------------------------
  // TODO: fill out logic to new values to display on each new frame

    localparam NUM_TIME_RANGES = WIDTH/UNIT_WIDTH;
    localparam NUM_PACKET_RANGES = HEIGHT/UNIT_HEIGHT;

    logic [NUM_TIME_RANGES-1:0][31:0] packet_counts;
    logic [NUM_TIME_RANGES-1:0][31:0] dropped_packet_counts;

    logic packet_count_index;

    always_ff @(posedge clk_pixel) begin
        // When new frame signal is high we want to update the packet counts
        // and our counter
        if (rst) begin
            packet_counts <= 0;
            packet_count_index <= 0;
        end else begin
            if (new_frame) begin
                if (packet_count_index == NUM_RANGES-1) begin 
                    packet_counts <= packet_counts << 31;
                    dropped_packet_counts <= dropped_packet_counts << 31;
                end else begin
                    packet_count_index <= packet_count_index + 1;
                end
                packet_counts[packet_count_index] <= i_total_packets;
                dropped_packet_counts[packet_count_index] <= i_dropped_packets;
            end
        end
       
    end 

   

  // ------------------------------------------------------------------------
  // Drawing Logic
  // ------------------------------------------------------------------------
  // TODO: fill out drawing logic  for the spcific h_count, v_count pixels using 
  // statistics and display_fifo packet info and filtering result

    // We check if the v_count is in between some range
    // If it is, we check what row and column it is in, wiithin that range
    // We get the associated packet count with a specific column, 
    // and we only color it black if the packet count is supposed to be in that row (we will have
    // ranges for each row))

    // TODO: Need to update the sizes of these variables
    logic [31:0] new_x_count;
    logic [31:0] new_y_count;
    logic [$clog2(NUM_TIME_RANGES-1):0] time_bucket;
    logic [$clog2(NUM_PACKET_RANGES-1):0] packet_count_bucket;

    logic [31:0] current_packet_count;
    logic [31:0] current_dropped_packet_count;

    always_comb begin
        in_graph_frame =(h_count >= ORIGIN_X) && (h_count < ORIGIN_X + WIDTH) && (v_count >= ORIGIN_Y) && (v_count >= ORIGIN_X + HEIGHT);
        if (in_graph_frame) begin
            new_x_count = x_count - ORIGIN_X;
            new_y_count = y_count - ORIGIN_Y;

            // Since we are currently dealing with unit squares of width 16, then we will cut off the last 4 bits
            time_bucket = new_x_count[31:5];
            packet_count_bucket = new_y_count[31:5];
            current_packet_count = packet_counts[time_bucket];
            current_dropped_packet_count = dropped_packet_counts[time_bucket];

            // Need to figure out how to reduce latency for multiplications (especially because of the two else if checks)
            if (new_x_count == 0 || new_y_count == 0 || new_x_count == WIDTH || new_y_count == HEIGHT) begin
                // Black borders
                red = 0;
                blue = 0;
                green = 0;
            end else if (packet_count_bucket * 1000 < current_dropped_packet_count && current_dropped_packet_count <= (packet_count_bucket + 1) * (1000)) begin
                // Color red for dropped packets
                red = 8'HFF;
                blue = 0;
                green = 0;
            end else if (packet_count_bucket * 1000 < current_packet_count && current_packet_count <= (packet_count_bucket + 1) * (1000)) begin
                // Color green for packets that passed
                red = 0;
                blue = 0;
                green = 8'HFF;
            end else begin 
                red = 8'HFF;
                blue = 8'HFF;
                green = 8'HFF;
            end
        end
    end

  // ------------------------------------------------------------------------
  // HDMI Output Path
  // ------------------------------------------------------------------------
  //three tmds_encoders (blue, green, red)
  //note green should have no control signal like red
  //the blue channel DOES carry the two sync signals:
  //  * control[0] = horizontal sync signal
  //  * control[1] = vertical sync signal

  tmds_encoder tmds_red (
      .clk(clk_pixel),
      .rst(rst_pixel),
      .video_data(red),
      .control(2'b0),
      .video_enable(active_draw),
      .tmds(tmds_10b[2])
  );
  tmds_encoder tmds_green (
      .clk(clk_pixel),
      .rst(rst_pixel),
      .video_data(green),
      .control(2'b0),
      .video_enable(active_draw),
      .tmds(tmds_10b[1])
  );
  tmds_encoder tmds_blue (
      .clk(clk_pixel),
      .rst(rst_pixel),
      .video_data(blue),
      .control({v_sync_hdmi, h_sync_hdmi}),
      .video_enable(active_draw),
      .tmds(tmds_10b[0])
  );

  tmds_serializer red_ser (
      .clk_pixel(clk_pixel),
      .clk_5x(clk_5x),
      .rst(rst_pixel),
      .tmds_in(tmds_10b[2]),
      .tmds_out(tmds_signal[2])
  );
  tmds_serializer green_ser (
      .clk_pixel(clk_pixel),
      .clk_5x(clk_5x),
      .rst(rst_pixel),
      .tmds_in(tmds_10b[1]),
      .tmds_out(tmds_signal[1])
  );
  tmds_serializer blue_ser (
      .clk_pixel(clk_pixel),
      .clk_5x(clk_5x),
      .rst(rst_pixel),
      .tmds_in(tmds_10b[0]),
      .tmds_out(tmds_signal[0])
  );

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals asserted
  //during blanking and sync periods to synchronize their faster bit clocks off
  //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
  //the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (
      .I (tmds_signal[0]),
      .O (hdmi_tx_p[0]),
      .OB(hdmi_tx_n[0])
  );
  OBUFDS OBUFDS_green (
      .I (tmds_signal[1]),
      .O (hdmi_tx_p[1]),
      .OB(hdmi_tx_n[1])
  );
  OBUFDS OBUFDS_red (
      .I (tmds_signal[2]),
      .O (hdmi_tx_p[2]),
      .OB(hdmi_tx_n[2])
  );
  OBUFDS OBUFDS_clock (
      .I (clk_pixel),
      .O (hdmi_clk_p),
      .OB(hdmi_clk_n)
  );

endmodule

`default_nettype wire
