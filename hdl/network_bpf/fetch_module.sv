`timescale 1ns / 1ps `default_nettype none

// classes
`define BPF_LD  0
`define BPF_LDX 1
`define BPF_ST  2
`define BPF_STX 3
`define BPF_ALU 4
`define BPF_JMP 5
`define BPF_RET 6
`define BPF_MISC 7

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

module fetch_module #(
    parameter int PC_WIDTH    = 8,
	parameter int ROM_LATENCY = 2
) (
    // Clock and reset
    input wire clk,
    input wire rst,

    // Control signals
    input wire i_start,
    input wire finished_program,

    output logic o_valid,
    input wire i_ready,

    // Instruction ROM interface
    output logic [PC_WIDTH-1:0] rom_addr,
    input wire [63:0] rom_data
);

	typedef enum logic [1:0] {
			IDLE,
			EXECUTING,
            STALL
	} state_t;

    state_t state;
    logic [31:0] cycle_count;
    logic begin_next_fetch;
    logic [31:0] pc;


    always_ff @(posedge clk) begin
        if (rst) begin 
            cycle_count <= 0;
            pc <= 0;
            state <= IDLE;
            rom_addr <= 0;
        end else begin
            if (state == EXECUTING || i_start || begin_next_fetch) begin
                if (finished_program) begin 
                    state <= IDLE;
                end else begin
                    // If i_start is asserted we go to executing
                    if (i_start) begin
                        state <= EXECUTING;
                    end
                end

                if (cycle_count == ROM_LATENCY) begin
                    state <= STALL;
                    cycle_count <= 0;
                    pc <= pc + 1;
                end else begin
                    // Initiate read
                    cycle_count <= cycle_count + 1;
                    rom_addr <= pc;
                end
            end else if (state == STALL) begin
                if (i_ready) begin 
                    state <= EXECUTING;
                end
            end

        end
    end

    always_comb begin 
        // We reach STALL when we are done with computation
        if (state == STALL) begin
            // Make sure that o_valid is high for only a cycle
            if (i_ready) begin
                o_valid = 1;
                begin_next_fetch = 1;
            end else begin
                o_valid = 0;
                begin_next_fetch = 0;
            end
        end
    end

endmodule
