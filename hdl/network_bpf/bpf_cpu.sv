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
`define BPF_WORD 0
`define BPF_HALFWORD 1
`define BPF_BYTE 2

// Load Modes
`define BPF_IMM 0  // Load the constant 0x80 into A
`define BPF_ABS 1  // Load the constant at index k
`define BPF_IND 2 // Load the value at packet[k + A]
`define BPF_MEM 3	// Store A into scratch memory spot k
`define BPF_LEN 4
`define BPF_MSH 5

// ALU OP
`define BPF_ADD 4'h0
`define BPF_SUB 4'h1 
`define BPF_MUL 4'h2
`define BPF_DIV 4'h3
`define BPF_OR  4'h4
`define BPF_AND 4'h5
`define BPF_LSH 4'h6
`define BPF_RSH 4'h7
`define BPF_NEG 4'h8
`define BPF_MOD 4'h9
`define BPF_XOR 4'ha

// Jump OP
`define BPF_JA   4'h0  // BPF_JMP only
`define BPF_JEQ  4'h1
`define BPF_JGT  4'h2
`define BPF_JGE  4'h3
`define BPF_JSET 4'h4 

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../bpf/X`"
`endif  /* ! SYNTHESIS */

module bpf_cpu #(
    parameter int PC_WIDTH = 8,
    parameter int BUF_ADDR_BITS = 11,
		parameter int ROM_LATENCY = 2
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
	logic [7:0]  jt_offset_reg;
	logic [7:0]  jf_offset_reg;
	logic [31:0] immediate;
	logic [2:0] instruction_class;
	logic [1:0] size;
	logic [2:0] mode;
	logic [7:0] op;
	logic src;
	logic [31:0] alu_src;

	// rom interface and captured rom data
	logic [PC_WIDTH-1:0] rom_addr;
	logic [63:0] rom_data;     

	// data interface for scratch memory
	logic [3:0] scratch_mem_rd_addr;
	logic [31:0] scratch_mem_rd_data;   

	logic [3:0] scratch_mem_wr_addr;
	logic [31:0] scratch_mem_wr_data;  
	logic scratch_mem_wren;
	
	// Multiplication regs
	logic src_loaded;
	
	logic [4:0] cycle_count;
	localparam FIRST_BYTE = 3;
	localparam SECOND_BYTE = 6;
	localparam THIRD_BYTE = 9;
	localparam FOURTH_BYTE = 12;
		
	always_ff @(posedge clk) begin
			if (rst) begin
				state <= IDLE;
				cycle_count <= 0;
				rom_addr <= 0;
				instruction_class <=0;
				size <= 0;
				mode <= 0;
				op <= 0;
				src <= 0;
				jt_offset_reg <= 0;
				jf_offset_reg <= 0;
				pc <= 0;
				A <= 0;
				X <= 0;
				o_done <= 0;
				o_pass_packet <= 0;
				src_loaded <= 0;
			end else begin
				case (state) 
					IDLE: begin
						state <= IDLE;
						cycle_count <= 0;
						rom_addr <= 0;
						instruction_class <=0;
						size <= 0;
						mode <= 0;
						op <= 0;
						src <= 0;
						jt_offset_reg <= 0;
						jf_offset_reg <= 0;
						pc <= 0;
						A <= 0;
						X <= 0;
						o_done <= 0;
						o_pass_packet <= 0;
						src_loaded <= 0;

						if (i_start) begin
							pc <= 0;
							state <= FETCH;
						end
					end

					// Fetch instruction from ROM
					FETCH: begin
						if (cycle_count == ROM_LATENCY) begin
							cycle_count <= 0;
							state <= DECODE;
						end else begin
							rom_addr <= pc;
							cycle_count <= cycle_count + 1;
						end

						// Set write enable to 0, while fetching
						scratch_mem_wren <= 1;
					end

					// Parse retreived ROM data
					DECODE: begin
						mode <= rom_data[55:53];
						size <= rom_data[52:51];

						op <= rom_data[55:52];
						src <= rom_data[51];

						instruction_class <= rom_data[50:48];
						jt_offset_reg <= rom_data[47:40];
						jf_offset_reg <= rom_data[39:32];
						immediate <= rom_data[31:0];
						
						// Reset cycle count for EXECUTE stage
						cycle_count <= 0;
						state <= EXECUTE;
					end

					EXECUTE: begin							
						case (instruction_class)
							`BPF_RET: begin
								// If we are executing a return instruction							
								o_done <= 1;
								state <= IDLE;
								o_pass_packet <= immediate != 0;
							end

							`BPF_JMP: begin
								// Conditional and unconditional jumps
								if (op == `BPF_JA) begin
										pc <= pc + immediate;
								end else if (op == `BPF_JEQ) begin
										pc <= (A == immediate) ? pc + jt_offset_reg + 1 : pc + jf_offset_reg + 1;
								end else if (op == `BPF_JGT) begin
										pc <= (A > immediate) ? pc + jt_offset_reg + 1 : pc + jf_offset_reg + 1;
								end else if (op == `BPF_JGE) begin
										pc <= (A >= immediate) ? pc + jt_offset_reg + 1 : pc + jf_offset_reg + 1;
								end else if (op == `BPF_JSET) begin
										pc <= ((A & immediate) != 0) ? pc + jt_offset_reg + 1: pc + jf_offset_reg + 1;
								end else begin
										pc <= pc + 1;
								end
								state <= FETCH;
							end

							`BPF_ALU: begin 
								if (!src_loaded) begin
									if (src == 0) begin
										alu_src <= immediate;
									end else begin 
										alu_src <= X;
									end
									src_loaded <= 1;
								end else begin 
									if (op == `BPF_NEG) begin
										A <= -A;
									end else begin
										case (op) 
											`BPF_ADD: A <= A + alu_src;
											`BPF_SUB: A <= A - alu_src;
											`BPF_MUL: A <= A * alu_src;
											// Need to research better division instead of this expensive hunk of garbo
											`BPF_DIV: A <= (alu_src == 0) ? 0 : (A/alu_src);
											// Also need to search up pipelined MOD cuz this is ahh
											`BPF_MOD: A <= (alu_src == 0) ? 0 : (A%alu_src);
											`BPF_OR: A <= A | alu_src;
											`BPF_AND: A <= A & alu_src;
											`BPF_LSH: A <= A << (alu_src & 5'h1F);
											`BPF_RSH: A <= A >> (alu_src & 5'h1F);
											`BPF_XOR: A <= A ^ alu_src;
										endcase
										src_loaded <= 0;
									end
								end
							end

							// TODO: Make a load module and then pass in A or X depending on the type of instruction.
							// Only loading from BRAM with BPF_ABS, BPF_IND, BPF_MSH
							// Load instructions take multiple cycles
							`BPF_LD: begin 
								case (mode)
									`BPF_IMM: A <= immediate;

									// Load from index 'base_address' from packet
									`BPF_ABS, `BPF_IND: begin
										case (size)
											`BPF_BYTE: begin
												if (cycle_count == FIRST_BYTE) begin
													A <= i_ram_data;
													pc <= pc + 1;
													state <= FETCH;
													cycle_count <= 0;
												end else begin 
													cycle_count <= cycle_count + 1;
												end
											end
											`BPF_HALFWORD: begin
												if (cycle_count == FIRST_BYTE) begin
													A <= i_ram_data;
													cycle_count <= cycle_count + 1;
												end else if (cycle_count == SECOND_BYTE) begin
													A <= {A[7:0], i_ram_data};
													pc <= pc + 1;
													state <= FETCH;
													cycle_count <= 0;
												end else begin
													cycle_count <= cycle_count + 1;
												end
											end
											`BPF_WORD: begin
												if (cycle_count == FIRST_BYTE) begin
													A <= i_ram_data;
													cycle_count <= cycle_count + 1;
												end else if(cycle_count == SECOND_BYTE) begin
													A <= {A[7:0], i_ram_data};
													cycle_count <= cycle_count + 1;
												end else if (cycle_count == THIRD_BYTE) begin 
													A <= {A[15:0], i_ram_data};
													cycle_count <= cycle_count + 1;
												end else if (cycle_count == FOURTH_BYTE) begin 
													A <= {A[23:0], i_ram_data};
													pc <= pc + 1;
													state <= FETCH;
													cycle_count <= 0;
												end else begin
													cycle_count <= cycle_count + 1;
												end
											end
											default: begin
												pc <= pc + 1;
												state <= FETCH;
											end
										endcase
									end


									`BPF_MEM: begin 
										if (cycle_count == 3) begin
											A <= scratch_mem_rd_data;
											pc <= pc + 1;
											state <= FETCH;
										end else begin
											cycle_count <= cycle_count + 1;
										end
									end

									`BPF_LEN: begin
										A <= i_packet_len;
										pc <= pc + 1;
										state <= FETCH;
									end

									`BPF_MSH: begin 
										if (cycle_count == FIRST_BYTE) begin
											A <= ({24'd0, i_ram_data}) << 2;
											pc <= pc + 1;
											state <= FETCH;
											cycle_count <= 0;
										end else begin
											cycle_count <= cycle_count + 1;
										end
									end	
											
								endcase
							end
							
							`BPF_LDX: begin 
								case (mode)
									`BPF_IMM: X <= immediate;

									// Load from index 'base_address' from packet
									`BPF_ABS, `BPF_IND: begin
										case (size)
											`BPF_BYTE: begin
												if (cycle_count == FIRST_BYTE) begin
													X <= i_ram_data;
													pc <= pc + 1;
													state <= FETCH;
													cycle_count <= 0;
												end else begin 
													cycle_count <= cycle_count + 1;
												end
											end
											`BPF_HALFWORD: begin
												if (cycle_count == FIRST_BYTE) begin
													X <= i_ram_data;
													cycle_count <= cycle_count + 1;
												end else if (cycle_count == SECOND_BYTE) begin
													X <= {X[7:0], i_ram_data};
													pc <= pc + 1;
													state <= FETCH;
													cycle_count <= 0;
												end else begin
													cycle_count <= cycle_count + 1;
												end
											end
											`BPF_WORD: begin
												if (cycle_count == FIRST_BYTE) begin
													X <= i_ram_data;
													cycle_count <= cycle_count + 1;
												end else if(cycle_count == SECOND_BYTE) begin
													X <= {X[7:0], i_ram_data};
													cycle_count <= cycle_count + 1;
												end else if (cycle_count == THIRD_BYTE) begin 
													X <= {X[15:0], i_ram_data};
													cycle_count <= cycle_count + 1;
												end else if (cycle_count == FOURTH_BYTE) begin 
													X <= {X[23:0], i_ram_data};
													pc <= pc + 1;
													state <= FETCH;
													cycle_count <= 0;
												end else begin
													cycle_count <= cycle_count + 1;
												end
											end
											default: begin
												pc <= pc + 1;
												state <= FETCH;
											end
										endcase
									end


									`BPF_MEM: begin 
										if (cycle_count == 3) begin
											X <= scratch_mem_rd_data;
											pc <= pc + 1;
											state <= FETCH;
										end else begin
											cycle_count <= cycle_count + 1;
										end
									end

									`BPF_LEN: begin
										X <= i_packet_len;
										pc <= pc + 1;
										state <= FETCH;
									end

									`BPF_MSH: begin 
										if (cycle_count == FIRST_BYTE) begin
											X <= ({24'd0, i_ram_data}) << 2;
											pc <= pc + 1;
											state <= FETCH;
											cycle_count <= 0;
										end else begin
											cycle_count <= cycle_count + 1;
										end
									end	
											
								endcase
							end

							`BPF_ST: begin
								scratch_mem_wr_addr <= immediate;
								scratch_mem_wren <= 1;
								scratch_mem_wr_data <= A;
								state <= FETCH;
							end

							`BPF_STX: begin
								scratch_mem_wr_addr <= immediate;
								scratch_mem_wren <= 1;
								scratch_mem_wr_data <= X;
								state <= FETCH;
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
	 	o_ram_rd_en = 1'b0;
    	o_ram_addr  = '0;
		if (state == EXECUTE && (instruction_class == `BPF_LD || instruction_class == `BPF_LDX)) begin
			if (mode == `BPF_ABS || mode == `BPF_IND || mode == `BPF_MSH) begin
				// Choose base address
				if (mode == `BPF_IND) begin
					base_addr = (immediate + X);
				end else begin
					// BPF_ABS and BPF_MSH
					base_addr = immediate;
				end

				// Initiate reads
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
			end else if (mode == `BPF_MEM) begin
				// Inititate read from scratch memory
				if (cycle_count == 0) begin
					scratch_mem_rd_addr = immediate;
				end
			end
			
		end

	end
 

  //=========================================================================
  // Submodules
  //=========================================================================

  // BRAM for instructions
	xilinx_single_port_ram_read_first #(
		.RAM_WIDTH(64),            
		.RAM_DEPTH(256),           
		.RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
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

	// BRAM for scratch memory
	xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(32),
        .RAM_DEPTH(16)
    ) i_bpf_packet_bram (
        .clka(clk),
        .addra(scratch_mem_wr_addr),
        .dina(scratch_mem_wr_data),
        .wea(scratch_mem_wren),
        .ena( 1'b1 ),
        .rsta( rst ),
        .douta(), // never read from this port
        .addrb(scratch_mem_rd_addr),
        .dinb( 0 ),
        .web( 1'b0 ),
        .enb( 1'b1 ),
        .rstb( rst ),
        .doutb(scratch_mem_rd_data)
    );


endmodule
