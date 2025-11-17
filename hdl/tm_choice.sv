module tm_choice (
    input wire [7:0] d,      //data byte in 
    output logic [8:0] q_m   //transition minimized output  
);

    logic [3:0] ones_count;
    
    always_comb begin
        ones_count = d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7];
        q_m[0] = d[0];
 
        if ((ones_count > 4) || (ones_count == 4 && d[0] == 0)) begin
            q_m[1] = q_m[0] ~^ d[1];
            q_m[2] = q_m[1] ~^ d[2];
            q_m[3] = q_m[2] ~^ d[3];
            q_m[4] = q_m[3] ~^ d[4];
            q_m[5] = q_m[4] ~^ d[5];
            q_m[6] = q_m[5] ~^ d[6];
            q_m[7] = q_m[6] ~^ d[7];
            q_m[8] = 1'b0;
        end else begin
            q_m[1] = q_m[0] ^ d[1];
            q_m[2] = q_m[1] ^ d[2];
            q_m[3] = q_m[2] ^ d[3];
            q_m[4] = q_m[3] ^ d[4];
            q_m[5] = q_m[4] ^ d[5];
            q_m[6] = q_m[5] ^ d[6];
            q_m[7] = q_m[6] ^ d[7];
            q_m[8] = 1'b1;
        end
    end
endmodule