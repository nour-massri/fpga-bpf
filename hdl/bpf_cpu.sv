`timescale 1ns / 1ps `default_nettype none

module bpf_cpu #(
    parameter int PC_WIDTH = 8,
    parameter int BUF_ADDR_BITS = 11
) (
    input wire clk,
    input wire rst,

    // Control signals
    input wire i_start,
    input wire [BUF_ADDR_BITS-1:0] i_packet_len,
    output logic o_done,
    output logic o_pass_packet,

    // BRAM read packet
    output logic o_ram_rd_en,
    output logic [BUF_ADDR_BITS-1:0] o_ram_addr,
    input wire [7:0] i_ram_data
);

  assign o_done = 1'b1;
  assign o_pass_packet = 1'b1;
  assign o_ram_rd_en = 1'b0;
  assign o_ram_addr = 0;

  // // ROM Signals
  // logic [7:0] rom_addr;
  // logic [63:0] rom_data;
  //=========================================================================
  // Submodules
  //=========================================================================
  // xilinx_single_port_ram_read_first #(
  //     .RAM_WIDTH(64),            
  //     .RAM_DEPTH(256),           
  //     .RAM_PERFORMANCE("LOW_LATENCY"), 
  //     .INIT_FILE(`FPATH(bpf_program.mem))
  // ) instr_rom (
  //     .addra(rom_addr),
  //     .dina(64'b0),
  //     .clka(clk),
  //     .wea(1'b0),
  //     .ena(1'b1),
  //     .rsta(rst),
  //     .regcea(1'b1),
  //     .douta(rom_data)
  // );


endmodule
