import arm7tdmi_pkg::*;

module arm7tdmi_alu (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  alu_op_t     alu_op,
    input  logic        set_flags,
    
    // Operands
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic        carry_in,
    
    // Results
    output logic [31:0] result,
    output logic        carry_out,
    output logic        overflow,
    output logic        negative,
    output logic        zero
);

    logic [32:0] extended_result;  // 33-bit for carry detection
    logic [31:0] alu_result;
    logic        alu_carry;
    logic        alu_overflow;
    
    // ALU operation logic
    always_comb begin
        alu_result = 32'b0;
        alu_carry = 1'b0;
        alu_overflow = 1'b0;
        extended_result = 33'b0;
        
        case (alu_op)
            ALU_AND: begin
                alu_result = operand_a & operand_b;
                alu_carry = carry_in;  // Preserve carry for logical operations
            end
            
            ALU_EOR: begin
                alu_result = operand_a ^ operand_b;
                alu_carry = carry_in;
            end
            
            ALU_SUB: begin
                extended_result = {1'b0, operand_a} - {1'b0, operand_b};
                alu_result = extended_result[31:0];
                alu_carry = ~extended_result[32];  // Inverted for subtraction
                alu_overflow = (operand_a[31] != operand_b[31]) && 
                              (operand_a[31] != alu_result[31]);
            end
            
            ALU_RSB: begin  // Reverse subtract: operand_b - operand_a
                extended_result = {1'b0, operand_b} - {1'b0, operand_a};
                alu_result = extended_result[31:0];
                alu_carry = ~extended_result[32];
                alu_overflow = (operand_b[31] != operand_a[31]) && 
                              (operand_b[31] != alu_result[31]);
            end
            
            ALU_ADD: begin
                extended_result = {1'b0, operand_a} + {1'b0, operand_b};
                alu_result = extended_result[31:0];
                alu_carry = extended_result[32];
                alu_overflow = (operand_a[31] == operand_b[31]) && 
                              (operand_a[31] != alu_result[31]);
            end
            
            ALU_ADC: begin  // Add with carry
                extended_result = {1'b0, operand_a} + {1'b0, operand_b} + {32'b0, carry_in};
                alu_result = extended_result[31:0];
                alu_carry = extended_result[32];
                alu_overflow = (operand_a[31] == operand_b[31]) && 
                              (operand_a[31] != alu_result[31]);
            end
            
            ALU_SBC: begin  // Subtract with carry
                extended_result = {1'b0, operand_a} - {1'b0, operand_b} - {32'b0, ~carry_in};
                alu_result = extended_result[31:0];
                alu_carry = ~extended_result[32];
                alu_overflow = (operand_a[31] != operand_b[31]) && 
                              (operand_a[31] != alu_result[31]);
            end
            
            ALU_RSC: begin  // Reverse subtract with carry
                extended_result = {1'b0, operand_b} - {1'b0, operand_a} - {32'b0, ~carry_in};
                alu_result = extended_result[31:0];
                alu_carry = ~extended_result[32];
                alu_overflow = (operand_b[31] != operand_a[31]) && 
                              (operand_b[31] != alu_result[31]);
            end
            
            ALU_TST: begin  // Test (AND but don't store result)
                alu_result = operand_a & operand_b;
                alu_carry = carry_in;
            end
            
            ALU_TEQ: begin  // Test equivalence (EOR but don't store result)
                alu_result = operand_a ^ operand_b;
                alu_carry = carry_in;
            end
            
            ALU_CMP: begin  // Compare (SUB but don't store result)
                extended_result = {1'b0, operand_a} - {1'b0, operand_b};
                alu_result = extended_result[31:0];
                alu_carry = ~extended_result[32];
                alu_overflow = (operand_a[31] != operand_b[31]) && 
                              (operand_a[31] != alu_result[31]);
            end
            
            ALU_CMN: begin  // Compare negative (ADD but don't store result)
                extended_result = {1'b0, operand_a} + {1'b0, operand_b};
                alu_result = extended_result[31:0];
                alu_carry = extended_result[32];
                alu_overflow = (operand_a[31] == operand_b[31]) && 
                              (operand_a[31] != alu_result[31]);
            end
            
            ALU_ORR: begin
                alu_result = operand_a | operand_b;
                alu_carry = carry_in;
            end
            
            ALU_MOV: begin
                alu_result = operand_b;
                alu_carry = carry_in;
            end
            
            ALU_BIC: begin  // Bit clear: operand_a AND NOT operand_b
                alu_result = operand_a & (~operand_b);
                alu_carry = carry_in;
            end
            
            ALU_MVN: begin  // Move NOT
                alu_result = ~operand_b;
                alu_carry = carry_in;
            end
            
            default: begin
                alu_result = 32'b0;
                alu_carry = 1'b0;
                alu_overflow = 1'b0;
            end
        endcase
    end
    
    // Flag generation
    assign negative = alu_result[31];
    assign zero = (alu_result == 32'b0);
    
    // Output assignments
    assign result = alu_result;
    assign carry_out = alu_carry;
    assign overflow = alu_overflow;
    
endmodule