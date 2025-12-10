// `timescale 1ns / 1ps `default_nettype none

// // classes
// `define BPF_LD  0
// `define BPF_LDX 1
// `define BPF_ST  2
// `define BPF_STX 3
// `define BPF_ALU 4
// `define BPF_JMP 5
// `define BPF_RET 6
// `define BPF_MISC 7

// // Sizes
// `define BPF_WORD 0
// `define BPF_HALFWORD 1
// `define BPF_BYTE 2

// // Load Modes
// `define BPF_IMM 0  // Load the constant 0x80 into A
// `define BPF_ABS 1  // Load the constant at index k
// `define BPF_IND 2 // Load the value at packet[k + A]
// `define BPF_MEM 3	// Store A into scratch memory spot k
// `define BPF_LEN 4
// `define BPF_MSH 5

// // ALU OP
// `define BPF_ADD 4'h0
// `define BPF_SUB 4'h1 
// `define BPF_MUL 4'h2
// `define BPF_DIV 4'h3
// `define BPF_OR  4'h4
// `define BPF_AND 4'h5
// `define BPF_LSH 4'h6
// `define BPF_RSH 4'h7
// `define BPF_NEG 4'h8
// `define BPF_MOD 4'h9
// `define BPF_XOR 4'ha

// // Jump OP
// `define BPF_JA   4'h0  // BPF_JMP only
// `define BPF_JEQ  4'h1
// `define BPF_JGT  4'h2
// `define BPF_JGE  4'h3
// `define BPF_JSET 4'h4 

// `ifdef SYNTHESIS
// `define FPATH(X) `"X`"
// `else /* ! SYNTHESIS */
// `define FPATH(X) `"../../bpf/X`"
// `endif  /* ! SYNTHESIS */

// module bpf_cpu #(
//     parameter int PC_WIDTH = 8,
//     parameter int BUF_ADDR_BITS = 11,
// 		parameter int ROM_LATENCY = 2
// ) (
//     input wire clk,
//     input wire rst,

//     // Control signals
//     input wire i_start,
//     input wire [BUF_ADDR_BITS-1:0] i_packet_len,
//     output logic o_done,
//     output logic o_pass_packet,

//     // BRAM read packet
//     output logic o_ram_rd_en,
//     output logic [BUF_ADDR_BITS-1:0] o_ram_addr,
//     input wire [7:0] i_ram_data
// );


//     always_ff @(posedge clk) begin
//         // Parse retreived ROM data
//         DECODE: begin
//             mode <= rom_data[55:53];
//             size <= rom_data[52:51];

//             op <= rom_data[55:52];
//             src <= rom_data[51];

//             instruction_class <= rom_data[50:48];
//             jt_offset_reg <= rom_data[47:40];
//             jf_offset_reg <= rom_data[39:32];
//             immediate <= rom_data[31:0];

//             // Reset cycle count for EXECUTE stage
//             cycle_count <= 0;
//             state <= EXECUTE;
//         end
//     end


//     always_comb begin 
//         DECODE: begin
//             decode_class = rom_data >> 48;
//             decode_mode = rom_data >> 53;
//             decode_immediate = rom_data;
//             decode_size = rom_data >> 51;

//             if (decode_class == `BPF_LD || decode_class == `BPF_LDX) begin
//                 if (decode_mode == `BPF_ABS || decode_mode == `BPF_IND || decode_mode == `BPF_MSH) begin
//                     // Choose base address
//                     if (decode_mode == `BPF_IND) begin
//                         base_addr = (decode_immediate + X);
//                     end else begin
//                         // BPF_ABS and BPF_MSH
//                         base_addr = decode_immediate;
//                     end

//                     // Initiate reads for all modes
//                     if (decode_size == `BPF_BYTE) begin
//                         o_ram_rd_en = 1'b1;
//                         o_ram_addr  = base_addr;
//                     end else if (decode_size == `BPF_HALFWORD) begin
//                         o_ram_rd_en = 1'b1;
//                         o_ram_addr  = base_addr;
//                     end else if (decode_size == `BPF_WORD) begin
//                         o_ram_rd_en = 1'b1;
//                         o_ram_addr  = base_addr;
//                     end
//                 end else if (decode_mode == `BPF_MEM) begin
//                     // Inititate read from scratch memory
//                     scratch_mem_rd_addr = decode_immediate;
//                 end 
//             end else if (decode_class == `BPF_STX) begin
//                 scratch_mem_wren = 1;
//                 scratch_mem_wr_addr = decode_immediate;
//                 scratch_mem_wr_data = X;
//             end else if (decode_class == `BPF_ST) begin 
//                 scratch_mem_wren = 1;
//                 scratch_mem_wr_addr = decode_immediate;
//                 scratch_mem_wr_data = A;
//             end else begin 
//                 // Not a load or store instruction
//                 scratch_mem_wren = 0;
//                 scratch_mem_wr_addr = 0;
//                 scratch_mem_wr_data = 0;
//                 o_ram_rd_en = 0;
//                 o_ram_addr  = 0;
//             end
//         end
//     end 

// endmodule
