`timescale 1ns / 1ps
`default_nettype none
 
module uart_receive
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
    )
   (
    input wire 	       clk,
    input wire 	       rst,
    input wire 	       din,
    output logic       dout_valid,
    output logic [7:0] dout
    );
 
    localparam UART_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
    typedef enum {
        IDLE = 0,
        // TODO: define the rest of the states your receiver needs to operate   
        START = 1,
        DATA = 2,
        STOP = 3,
        TRANSMIT = 4
    } uart_state;
    
    // note: for the online checker, don't rename this variable
    uart_state state;
    logic [31:0] cycles; 
    logic [3:0] cnt;
    logic [7:0] data;

    // TODO: module to read UART rx wire
    always_ff @(posedge clk) begin 
        if(rst) begin 
            state <= IDLE;
        end else begin 
            case(state)
                IDLE: begin 
                    if(!din) begin
                        state <= START;
                        cycles <= 0; 
                     end 
                end
                START: begin
                    if(cycles == UART_BIT_PERIOD / 2 - 1 & din)begin  // bad start bit
                        state <= IDLE;
                        cycles <= 0;
                    end else if(cycles == UART_BIT_PERIOD - 1) begin // if we got here then it is a good start bit
                        state <= DATA;
                        cnt <= 0;
                        cycles <= 0;
                    end else begin 
                        cycles <= cycles + 1;
                    end
                end 
                DATA: begin 
                    if(cycles == UART_BIT_PERIOD / 2 - 1) begin
                        data <= {din, data[7:1]};
                        cnt <= cnt + 1;
                        cycles <= cycles + 1;
                    end else if(cycles == UART_BIT_PERIOD - 1) begin 
                        if(cnt == 8) begin 
                            state <= STOP;
                            cnt <= 0;
                        end
                       cycles <= 0; 
                    end else begin 
                        cycles <= cycles + 1;
                    end
                end 
                STOP: begin
                    if(cycles == UART_BIT_PERIOD / 2 - 1)begin
                        case(din)
                            1'b0: begin // bad stop bit
                                state <= IDLE;
                            end
                            1'b1: begin // good stop bit
                                state <= TRANSMIT;
                                dout <= data;
                                dout_valid <= 1;
                            end
                        endcase
                        cycles <= 0;
                    end else begin 
                        cycles <= cycles + 1;
                    end
                end
                TRANSMIT: begin
                    state <= IDLE;
                    dout_valid <= 0;
                end 
            endcase
        end 
    end
endmodule // uart_receive
 
`default_nettype wire