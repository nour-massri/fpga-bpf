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
//         EXECUTE: begin							
//             case (instruction_class)
//                 `BPF_RET: begin
//                     o_done <= 1;
//                     state <= IDLE;
//                     o_pass_packet <= immediate != 0;
//                 end

//                 `BPF_MISC: begin
//                     // TAX
//                     if (mode == `BPF_LD) begin
//                         X <= A;
//                     end else begin
//                         A <= X;
//                     end
//                     pc <= pc + 1;
//                     state <= FETCH;
//                 end

//                 `BPF_JMP: begin
//                     // Conditional and unconditional jumps
//                     if (op == `BPF_JA) begin
//                         pc <= pc + immediate;
//                     end else if (op == `BPF_JEQ) begin
//                         pc <= (A == immediate) ? pc + jt_offset_reg + 1 : pc + jf_offset_reg + 1;
//                     end else if (op == `BPF_JGT) begin
//                         pc <= (A > immediate) ? pc + jt_offset_reg + 1 : pc + jf_offset_reg + 1;
//                     end else if (op == `BPF_JGE) begin
//                         pc <= (A >= immediate) ? pc + jt_offset_reg + 1 : pc + jf_offset_reg + 1;
//                     end else if (op == `BPF_JSET) begin
//                         pc <= ((A & immediate) != 0) ? pc + jt_offset_reg + 1: pc + jf_offset_reg + 1;
//                     end else begin
//                         pc <= pc + 1;
//                     end
//                     state <= FETCH;
//                 end

//                 `BPF_ALU: begin 
//                     if (!src_loaded) begin
//                         if (src == 0) begin
//                             alu_src <= immediate;
//                         end else begin 
//                             alu_src <= X;
//                         end
//                         src_loaded <= 1;
//                     end else begin 
//                         if (op == `BPF_NEG) begin
//                             A <= -A;
//                         end else begin
//                             case (op) 
//                                 `BPF_ADD: A <= A + alu_src;
//                                 `BPF_SUB: A <= A - alu_src;
//                                 `BPF_MUL: A <= A * alu_src;

//                                 // TODO: Need to replace these expensive operations with a 
//                                 // state machine 
//                                 `BPF_DIV: A <= (alu_src == 0) ? 0 : (A/alu_src);
//                                 `BPF_MOD: A <= (alu_src == 0) ? 0 : (A%alu_src);

//                                 `BPF_OR: A <= A | alu_src;
//                                 `BPF_AND: A <= A & alu_src;
//                                 `BPF_LSH: A <= A << (alu_src & 5'h1F);
//                                 `BPF_RSH: A <= A >> (alu_src & 5'h1F);
//                                 `BPF_XOR: A <= A ^ alu_src;
//                             endcase
//                             src_loaded <= 0;
//                         end
//                         state <= FETCH;
//                         pc <= pc + 1;
//                     end
//                 end

//                 `BPF_LD: begin 
//                     case (mode)
//                         `BPF_IMM: begin
//                             A <= immediate;
//                             pc <= pc + 1;
//                             state <= FETCH;
//                         end

//                         `BPF_ABS, `BPF_IND: begin
//                             case (size)
//                                 `BPF_BYTE: begin
//                                     if (cycle_count == FIRST_BYTE) begin
//                                         A <= i_ram_data;
//                                         pc <= pc + 1;
//                                         state <= FETCH;
//                                         cycle_count <= 0;
//                                     end else begin 
//                                         cycle_count <= cycle_count + 1;
//                                     end
//                                 end
//                                 `BPF_HALFWORD: begin
//                                     if (cycle_count == FIRST_BYTE) begin
//                                         A <= i_ram_data;
//                                         cycle_count <= cycle_count + 1;
//                                     end else if (cycle_count == SECOND_BYTE) begin
//                                         A <= {A[7:0], i_ram_data};
//                                         pc <= pc + 1;
//                                         state <= FETCH;
//                                         cycle_count <= 0;
//                                     end else begin
//                                         cycle_count <= cycle_count + 1;
//                                     end
//                                 end
//                                 `BPF_WORD: begin
//                                     if (cycle_count == FIRST_BYTE) begin
//                                         A <= i_ram_data;
//                                         cycle_count <= cycle_count + 1;
//                                     end else if(cycle_count == SECOND_BYTE) begin
//                                         A <= {A[7:0], i_ram_data};
//                                         cycle_count <= cycle_count + 1;
//                                     end else if (cycle_count == THIRD_BYTE) begin 
//                                         A <= {A[15:0], i_ram_data};
//                                         cycle_count <= cycle_count + 1;
//                                     end else if (cycle_count == FOURTH_BYTE) begin 
//                                         A <= {A[23:0], i_ram_data};
//                                         pc <= pc + 1;
//                                         state <= FETCH;
//                                         cycle_count <= 0;
//                                     end else begin
//                                         cycle_count <= cycle_count + 1;
//                                     end
//                                 end
//                                 default: begin
//                                     pc <= pc + 1;
//                                     state <= FETCH;
//                                 end
//                             endcase
//                         end


//                         `BPF_MEM: begin 
//                             if (cycle_count == 2) begin
//                                 A <= scratch_mem_rd_data;
//                                 pc <= pc + 1;
//                                 state <= FETCH;
//                                 cycle_count <= 0;
//                             end else begin
//                                 cycle_count <= cycle_count + 1;
//                             end
//                         end

//                         `BPF_LEN: begin
//                             A <= i_packet_len;
//                             pc <= pc + 1;
//                             state <= FETCH;
//                         end

//                         `BPF_MSH: begin 
//                             if (cycle_count == FIRST_BYTE) begin
//                                 A <= ({24'd0, i_ram_data} & 32'h0f) << 2;
//                                 pc <= pc + 1;
//                                 state <= FETCH;
//                                 cycle_count <= 0;
//                             end else begin
//                                 cycle_count <= cycle_count + 1;
//                             end
//                         end	
                                
//                     endcase
//                 end
                
//                 `BPF_LDX: begin 
//                     case (mode)
//                         `BPF_IMM: begin
//                             X <= immediate;
//                             pc <= pc + 1;
//                             state <= FETCH;
//                         end

//                         `BPF_ABS, `BPF_IND: begin
//                             case (size)
//                                 `BPF_BYTE: begin
//                                     if (cycle_count == FIRST_BYTE) begin
//                                         X <= i_ram_data;
//                                         pc <= pc + 1;
//                                         state <= FETCH;
//                                         cycle_count <= 0;
//                                     end else begin 
//                                         cycle_count <= cycle_count + 1;
//                                     end
//                                 end
//                                 `BPF_HALFWORD: begin
//                                     if (cycle_count == FIRST_BYTE) begin
//                                         X <= i_ram_data;
//                                         cycle_count <= cycle_count + 1;
//                                     end else if (cycle_count == SECOND_BYTE) begin
//                                         X <= {X[7:0], i_ram_data};
//                                         pc <= pc + 1;
//                                         state <= FETCH;
//                                         cycle_count <= 0;
//                                     end else begin
//                                         cycle_count <= cycle_count + 1;
//                                     end
//                                 end
//                                 `BPF_WORD: begin
//                                     if (cycle_count == FIRST_BYTE) begin
//                                         X <= i_ram_data;
//                                         cycle_count <= cycle_count + 1;
//                                     end else if(cycle_count == SECOND_BYTE) begin
//                                         X <= {X[7:0], i_ram_data};
//                                         cycle_count <= cycle_count + 1;
//                                     end else if (cycle_count == THIRD_BYTE) begin 
//                                         X <= {X[15:0], i_ram_data};
//                                         cycle_count <= cycle_count + 1;
//                                     end else if (cycle_count == FOURTH_BYTE) begin 
//                                         X <= {X[23:0], i_ram_data};
//                                         pc <= pc + 1;
//                                         state <= FETCH;
//                                         cycle_count <= 0;
//                                     end else begin
//                                         cycle_count <= cycle_count + 1;
//                                     end
//                                 end
//                                 default: begin
//                                     pc <= pc + 1;
//                                     state <= FETCH;
//                                 end
//                             endcase
//                         end


//                         `BPF_MEM: begin 
//                             if (cycle_count == 2) begin
//                                 X <= scratch_mem_rd_data;
//                                 pc <= pc + 1;
//                                 state <= FETCH;
//                                 cycle_count <= 0;
//                             end else begin
//                                 cycle_count <= cycle_count + 1;
//                             end
//                         end

//                         `BPF_LEN: begin
//                             X <= i_packet_len;
//                             pc <= pc + 1;
//                             state <= FETCH;
//                         end

//                         `BPF_MSH: begin 
//                             if (cycle_count == FIRST_BYTE) begin
//                                 X <= ({24'd0, i_ram_data} & 32'h0f) << 2;
//                                 pc <= pc + 1;
//                                 state <= FETCH;
//                                 cycle_count <= 0;
//                             end else begin
//                                 cycle_count <= cycle_count + 1;
//                             end
//                         end	
                                
//                     endcase
//                 end

//                 `BPF_ST: begin
//                     state <= FETCH;
//                     pc <= pc + 1;
//                     cycle_count <= 0;
//                 end

//                 `BPF_STX: begin
//                     state <= FETCH;
//                     pc <= pc + 1;
//                     cycle_count <= 0;
//                 end

//                 default: begin
//                     // unimplemented classes
//                     pc <= pc + 1;
//                     state <= FETCH;
//                 end
//         endcase
//         end
//     end


//     always_comb begin 
//         EXECUTE: begin
//             if (instruction_class == `BPF_LD || instruction_class == `BPF_LDX) begin
//                 if (mode == `BPF_ABS || mode == `BPF_IND || mode == `BPF_MSH) begin

//                     if (mode == `BPF_IND) begin
//                         base_addr = (immediate + X);
//                     end else begin
//                         // BPF_ABS and BPF_MSH
//                         base_addr = immediate;
//                     end

//                     // Initiate later reads
//                     if (size == `BPF_BYTE) begin
//                         o_ram_addr = 0;
//                         o_ram_rd_en = 0;
//                     end else if (size == `BPF_HALFWORD) begin
//                         if (cycle_count == FIRST_BYTE-1) begin
//                             o_ram_rd_en = 1'b1;
//                             o_ram_addr  = base_addr + 1;
//                         end
//                     end else if (size == `BPF_WORD) begin
//                         if (cycle_count == FIRST_BYTE-1) begin
//                             o_ram_rd_en = 1'b1;
//                             o_ram_addr  = base_addr + 1;
//                         end else if (cycle_count == SECOND_BYTE-1) begin
//                             o_ram_rd_en = 1'b1;
//                             o_ram_addr  = base_addr + 2;
//                         end else if (cycle_count == THIRD_BYTE-1) begin
//                             o_ram_rd_en = 1'b1;
//                             o_ram_addr  = base_addr + 3;
//                         end
//                     end 
//                 end else if (mode == `BPF_MEM) begin
//                     // Inititate read from scratch memory
//                     scratch_mem_rd_addr = immediate;
//                 end 
//             end else if (instruction_class == `BPF_STX) begin
//                 scratch_mem_wren = 1;
//                 scratch_mem_wr_addr = immediate;
//                 scratch_mem_wr_data = X;
//             end else if (instruction_class == `BPF_ST) begin 
//                 scratch_mem_wren = 1;
//                 scratch_mem_wr_addr = immediate;
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
