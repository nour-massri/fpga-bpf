`timescale 1ns / 1ps
`default_nettype none

module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_DEPTH = 4,
    parameter int INIT_COUNT = 0 
) (
    input wire clk,
    input wire rst,

    // Push interface
    input wire [DATA_WIDTH-1:0] i_push_data,
    input wire i_push_valid,
    output logic o_full,

    // Pop interface
    output logic [DATA_WIDTH-1:0] o_pop_data,
    output logic o_pop_valid,
    input wire i_pop_ready
);

    logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];
    logic [$clog2(FIFO_DEPTH):0] count;
    logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr;

    assign o_full = (count == FIFO_DEPTH);
    assign o_pop_valid = !(count == 0);
    assign o_pop_data = mem[rd_ptr];  

    logic do_pop, do_push;
    assign do_pop = o_pop_valid && i_pop_ready;
    assign do_push = i_push_valid && !o_full;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < INIT_COUNT; i++) begin
                mem[i] <= i[DATA_WIDTH-1:0];
            end
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= (INIT_COUNT > 0) ? INIT_COUNT : 0;
        end else begin
            case ({do_push, do_pop})
                 2'b11: begin // Push and pop
                    mem[wr_ptr] <= i_push_data;
                    wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
                    rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
                    // count stays the same
                end
                2'b10: begin // Push
                    mem[wr_ptr] <= i_push_data;
                    wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
                    count <= count + 1;
                end
                2'b01: begin // Pop
                    rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
                    count <= count - 1;
                end

                2'b00: begin // No operation
                end
            endcase
        end
    end
    
    initial begin
        if (INIT_COUNT > FIFO_DEPTH) begin
            $error("INIT_COUNT (%0d) cannot exceed FIFO_DEPTH (%0d)", INIT_COUNT, FIFO_DEPTH);
        end
    end
    
endmodule

`default_nettype wire
