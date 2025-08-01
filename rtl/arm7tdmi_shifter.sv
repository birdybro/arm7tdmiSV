// import arm7tdmi_pkg::*;

module arm7tdmi_shifter (
    input  logic [31:0]    data_in,
    input  logic [1:0]     shift_type,
    input  logic [4:0]     shift_amount,
    input  logic           carry_in,
    
    output logic [31:0]    data_out,
    output logic           carry_out
);

    always_comb begin
        data_out = data_in;
        carry_out = carry_in;
        
        if (shift_amount != 5'b0 || (shift_type == 2'b11 && shift_amount == 5'b0)) begin
            case (shift_type)
                2'b00: begin  // SHIFT_LSL - Logical Shift Left
                    if (shift_amount <= 32) begin
                        data_out = data_in << shift_amount;
                        carry_out = (shift_amount <= 32) ? data_in[32-shift_amount] : 1'b0;
                    end else begin
                        data_out = 32'b0;
                        carry_out = 1'b0;
                    end
                end
                
                2'b01: begin  // SHIFT_LSR - Logical Shift Right
                    if (shift_amount < 32) begin
                        data_out = data_in >> shift_amount;
                        carry_out = data_in[shift_amount-1];
                    end else if (shift_amount == 32) begin
                        data_out = 32'b0;
                        carry_out = data_in[31];
                    end else begin
                        data_out = 32'b0;
                        carry_out = 1'b0;
                    end
                end
                
                2'b10: begin  // SHIFT_ASR - Arithmetic Shift Right
                    if (shift_amount < 32) begin
                        data_out = $signed(data_in) >>> shift_amount;
                        carry_out = data_in[shift_amount-1];
                    end else begin
                        data_out = {32{data_in[31]}};  // Sign extend
                        carry_out = data_in[31];
                    end
                end
                
                2'b11: begin  // SHIFT_ROR - Rotate Right
                    if (shift_amount == 0) begin
                        // RRX - Rotate Right Extended (through carry)
                        data_out = {carry_in, data_in[31:1]};
                        carry_out = data_in[0];
                    end else begin
                        data_out = (data_in >> shift_amount[4:0]) | (data_in << (32 - shift_amount[4:0]));
                        carry_out = data_in[shift_amount[4:0]-1];
                    end
                end
            endcase
        end
    end

endmodule