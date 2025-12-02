`timescale 1ns / 1ps `default_nettype none

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_DEPTH = 16
) (
    input wire rst,

    // Push side
    input wire push_clk,
    input wire [DATA_WIDTH-1:0] i_push_data,
    input wire i_push_valid,
    output logic o_push_ready,

    // Pop side
    input wire pop_clk,
    output logic [DATA_WIDTH-1:0] o_pop_data,
    output logic o_pop_valid,
    input wire i_pop_ready
);

  // XPM DATA_WIDTH shuld be multiple of 8 and between 8 and 256
  // Calculate the next multiple of 8 (e.g., 5->8, 12->16, 32->32)
  localparam int ALIGNED_WIDTH = ((DATA_WIDTH + 7) / 8) * 8;
  localparam int PAD_WIDTH = ALIGNED_WIDTH - DATA_WIDTH;

  logic [ALIGNED_WIDTH-1:0] s_axis_tdata_padded;
  logic [ALIGNED_WIDTH-1:0] m_axis_tdata_padded;

  assign s_axis_tdata_padded = {{PAD_WIDTH{1'b0}}, i_push_data};
  assign o_pop_data = m_axis_tdata_padded[DATA_WIDTH-1:0];

  xpm_fifo_axis #(
      .CASCADE_HEIGHT(0),
      .CDC_SYNC_STAGES(3),
      .CLOCKING_MODE("independent_clock"),
      .ECC_MODE("no_ecc"),
      .FIFO_DEPTH(FIFO_DEPTH),
      .FIFO_MEMORY_TYPE("auto"),
      .PACKET_FIFO("false"),
      .PROG_EMPTY_THRESH(10),
      .PROG_FULL_THRESH(FIFO_DEPTH - 2),
      .RELATED_CLOCKS(0),
      .SIM_ASSERT_CHK(0),
      .TDATA_WIDTH(ALIGNED_WIDTH),
      .USE_ADV_FEATURES("0000")
  ) xpm_fifo_axis_inst (
      // Receiver (pop) side
      .m_aclk(pop_clk),
      .m_axis_tdata(m_axis_tdata_padded),
      .m_axis_tvalid(o_pop_valid),
      .m_axis_tready(i_pop_ready),
      .m_axis_tlast(),
      .m_axis_tdest(),
      .m_axis_tid(),
      .m_axis_tkeep(),
      .m_axis_tstrb(),
      .m_axis_tuser(),

      // Sender (push) side
      .s_aclk(push_clk),
      .s_aresetn(~rst),
      .s_axis_tdata(s_axis_tdata_padded),
      .s_axis_tvalid(i_push_valid),
      .s_axis_tready(o_push_ready),
      .s_axis_tlast(1'b0),
      .s_axis_tdest(0),
      .s_axis_tid(0),
      .s_axis_tkeep(0),
      .s_axis_tstrb(0),
      .s_axis_tuser(0),

      // Unused features
      .prog_empty_axis(),
      .prog_full_axis ()
  );

endmodule

`default_nettype wire
