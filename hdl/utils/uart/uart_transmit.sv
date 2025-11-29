`timescale 1ns / 1ps
`default_nettype none

module uart_transmit
    #(
        parameter INPUT_CLOCK_FREQ = 100_000_000,
        parameter BAUD_RATE = 9600
     )
    (
        input wire clk, 
        input wire rst, 
        input wire [7:0] din, // data in, should only be read when transmition is started
        input wire trigger, 
        output logic busy,
        output logic dout
    );
    localparam BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
     
     logic [3:0] cnt;
     logic [8:0] data;
     logic [31:0] cycles;

     always_ff @(posedge clk) begin
        if(rst) begin 
            cnt <= 0;
            busy <= 0;
            dout <= 1;
        end else begin 
            if(busy) begin 
                if(cycles == BAUD_BIT_PERIOD - 1) begin 
                   if(cnt == 9) begin 
                        busy <= 0;
                        dout <= 1;
                   end else begin 
                        cnt <= cnt + 1;
                        data <= {1'b1, data[8:1]};

                        dout <= data[0];
                   end 
                   cycles <= 0;
                end else begin 
                    cycles <= cycles + 1;
                end
            end else if(trigger) begin 
                cnt <= 0;
                data <= {1'b1, din};
                cycles <= 0;

                busy <= 1;
                dout <= 0;
            end
        end
     end

endmodule // uart_transmit

`default_nettype wire