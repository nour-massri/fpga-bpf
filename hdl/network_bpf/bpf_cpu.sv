`timescale 1ns / 1ps `default_nettype none

// classes
`define BPF_LD  0
`define BPF_LDX 1
`define BPF_ST  2
`define BPF_STX 3
`define BPF_ALU 4
`define BPF_JMP 5
`define BPF_RET 6

// Sizes
`define BPF_WORD     0
`define BPF_HALFWORD 1
`define BPF_BYTE     2

// Load Modes
`define BPF_IMM 0  // Load the constant 0x80 into A
`define BPF_ABS 1  // Load the constant at index k
`define BPF_IND 2 // Load the value at packet[k + A]
`define BPF_MEM 3	// Store A into scratch memory spot k
`define BPF_LEN 4
`define BPF_MSH 5

// ALU OP
`define BPF_ADD 8'h00
`define BPF_SUB 8'h10 
`define BPF_MUL 8'h20
`define BPF_DIV 8'h30
`define BPF_OR  8'h40
`define BPF_AND 8'h50
`define BPF_LSH 8'h60
`define BPF_RSH 8'h70
`define BPF_NEG 8'h80
`define BPF_MOD 8'h90
`define BPF_XOR 8'ha0

// Jump OP
`define BPF_JA   8'h00  // BPF_JMP only
`define BPF_JEQ  8'h10
`define BPF_JGT  8'h20
`define BPF_JGE  8'h30
`define BPF_JSET 8'h40 

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../bpf/X`"
`endif  /* ! SYNTHESIS */

module bpf_cpu #(
    parameter int PC_WIDTH = 8,
    parameter int BUF_ADDR_BITS = 11,
		parameter int ROM_LATENCY = 1
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

	typedef enum logic [2:0] {
			IDLE,
			FETCH, 
			DECODE,
			EXECUTE
	} state_t;

	state_t state;
	
	// Registers
	logic [31:0] pc;
	logic [31:0] A;
	logic [31:0] X;

	// Instruction parts
	logic [15:0] opcode_reg;
	logic [7:0]  jt_offset_reg;
	logic [7:0]  jf_offset_reg;
	logic [31:0] immediate_reg;

	// rom interface and captured rom data
	logic [PC_WIDTH-1:0] rom_addr;
	logic [63:0] rom_data;        // output from ROM primitive
	logic [63:0] rom_data_reg;    // captured after ROM_LATENCY cycles

	// decoded small fields for easier use
	logic [2:0] instruction_class;
	logic [1:0] size;
	logic [2:0] mode;
	logic [7:0] op;
	
	logic [2:0] cycle_count;
	localparam FIRST_BYTE = 2;
	localparam SECOND_BYTE = 4;
	localparam THIRD_BYTE = 6;
	localparam FOURTH_BYTE = 8;
		
	always_ff @(posedge clk) begin
			if (rst) begin
					state <= IDLE;
					cycle_count <= 0;
			end else begin
				case (state) 
					IDLE: begin
						cycle_count <= 0;
						if (i_start) begin
							pc <= 0;
							state <= FETCH;
						end
					end

					// Fetch instruction from ROM
					FETCH: begin
						if (cycle_count == ROM_LATENCY) begin
							rom_data_reg <= rom_data;
							cycle_count <= 0;
							state <= DECODE;
						end else begin
							cycle_count <= cycle_count + 1;
						end
					end

					// Parse retreived ROM data
					DECODE: begin
						instruction_class <= rom_data_reg[2:0];
						size <= rom_data_reg[4:3];
						mode <= rom_data_reg[7:5];
						op <= rom_data_reg[15:8];
						jt_offset_reg <= rom_data_reg[23:16];
						jf_offset_reg <= rom_data_reg[31:24];
						immediate_reg <= rom_data_reg[63:32];
						
						// Reset cycle count for EXECUTE stage
						cycle_count <= 0;
						state <= EXECUTE;
					end

					EXECUTE: begin							
						case (instruction_class)
							`BPF_RET: begin
								// If we are executing a return instruction
								// Reset all registers, set o_done to true and go to IDLE
								pc <= 0;
								A <= 0;
								X <= 0;
								o_done <= 1;
								state <= IDLE;
								o_pass_packet <= immediate_reg != 0;
							end

							`BPF_JMP: begin
								// Conditional and unconditional jumps
								if (op == `BPF_JA) begin
										pc <= pc + immediate_reg;
								end else if (op == `BPF_JEQ) begin
										pc <= (A == immediate_reg) ? pc + jt_offset_reg : pc + jf_offset_reg;
								end else if (op == `BPF_JGT) begin
										pc <= (A > immediate_reg) ? pc + jt_offset_reg : pc + jf_offset_reg;
								end else if (op == `BPF_JGE) begin
										pc <= (A >= immediate_reg) ? pc + jt_offset_reg : pc + jf_offset_reg;
								end else if (op == `BPF_JSET) begin
										pc <= ((A & immediate_reg) != 0) ? pc + jt_offset_reg: pc + jf_offset_reg;
								end else begin
										pc <= pc + 1;
								end
								state <= FETCH;
							end


							// Load instructions take multiple cycles
							`BPF_LD: begin 
								if (mode == `BPF_IMM) begin
									A <= immediate_reg;
								end else if (mode == `BPF_ABS) begin
									if (size == `BPF_BYTE) begin
										if (cycle_count == FIRST_BYTE) begin
											A <= i_ram_data;
											pc <= pc + 1;
											state <= FETCH;
											cycle_count <= 0;
										end begin 
											cycle_count <= cycle_count + 1;
										end
									end else if (size == `BPF_HALFWORD) begin
										if (cycle_count == FIRST_BYTE) begin
											A <= i_ram_data;
										end else if (cycle_count == SECOND_BYTE) begin
											A <= {A[7:0], i_ram_data};
											pc <= pc + 1;
											state <= FETCH;
											cycle_count <= 0;
										end else begin
											cycle_count <= cycle_count + 1;
										end
									end else if (size == `BPF_WORD) begin
										if (cycle_count == FIRST_BYTE) begin
											A <= i_ram_data;
										end else if(cycle_count == SECOND_BYTE) begin
											A <= {A[7:0], i_ram_data};
										end else if (cycle_count == THIRD_BYTE) begin 
											A <= {A[15:0], i_ram_data};
										end else if (cycle_count == FOURTH_BYTE) begin 
											A <= {A[23:0], i_ram_data};
											pc <= pc + 1;
											state <= FETCH;
											cycle_count <= 0;
										end else begin
											cycle_count <= cycle_count + 1;
										end
									end else begin
										pc <= pc + 1;
										state <= FETCH;
									end
								end 
							end
							default: begin
								// unimplemented classes
								pc <= pc + 1;
								state <= FETCH;
							end
					endcase
					end
				endcase 
			end
	end    

		

		//=========================================================================
		// Data path
		//=========================================================================

	logic [BUF_ADDR_BITS-1:0] base_addr;
	always_comb begin
		if (state == FETCH) begin
			rom_addr = pc;
		end
	
	 	o_ram_rd_en = 1'b0;
    o_ram_addr  = '0;
		if (state == EXECUTE && instruction_class == `BPF_LD && mode == `BPF_ABS) begin
			// address includes +2 offset because of preamble
			base_addr = immediate_reg + 2;
			if (size == `BPF_BYTE) begin
				if (cycle_count == 0) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr;
				end
			end else if (size == `BPF_HALFWORD) begin
				if (cycle_count == 0) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr;
				end else if (cycle_count == FIRST_BYTE) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr + 1;
				end
			end else if (size == `BPF_WORD) begin
				if (cycle_count == 0) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr;
				end else if (cycle_count == FIRST_BYTE) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr + 1;
				end else if (cycle_count == SECOND_BYTE) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr + 2;
				end else if (cycle_count == THIRD_BYTE) begin
					o_ram_rd_en = 1'b1;
					o_ram_addr  = base_addr + 3;
				end
			end
		end
	end
 

  //=========================================================================
  // Submodules
  //=========================================================================
  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(64),            
      .RAM_DEPTH(256),           
      .RAM_PERFORMANCE("LOW_LATENCY"), 
      .INIT_FILE(`FPATH(ip_and_udp.mem))
  ) instr_rom (
      .addra(rom_addr),
      .dina(64'b0),
      .clka(clk),
      .wea(1'b0),
      .ena(1'b1),
      .rsta(rst),
      .regcea(1'b1),
      .douta(rom_data)
  );


endmodule
