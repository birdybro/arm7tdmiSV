import arm7tdmi_pkg::*;

module arm7tdmi_multiply (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  logic        mul_en,
    input  logic        mul_long,
    input  logic        mul_signed,
    input  logic        mul_accumulate,
    input  logic        mul_set_flags,
    input  logic [1:0]  mul_type,         // 00=MUL, 01=MLA, 10=UMULL/SMULL, 11=UMLAL/SMLAL
    
    // Operands
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [31:0] acc_hi,     // For accumulate operations
    input  logic [31:0] acc_lo,
    
    // Results
    output logic [31:0] result_hi,
    output logic [31:0] result_lo,
    output logic        result_ready,
    
    // Flags
    output logic        negative,
    output logic        zero
);

    // Multiply operation types
    typedef enum logic [1:0] {
        MUL_TYPE_MUL    = 2'b00,  // MUL - 32x32->32
        MUL_TYPE_MLA    = 2'b01,  // MLA - 32x32+32->32
        MUL_TYPE_MULL   = 2'b10,  // UMULL/SMULL - 32x32->64
        MUL_TYPE_MLAL   = 2'b11   // UMLAL/SMLAL - 32x32+64->64
    } mul_type_t;
    
    // Multiply operation
    logic [63:0] mul_result;
    logic [63:0] final_result;
    logic [63:0] accumulator;
    
    // Addition logic for long multiply accumulate
    logic [32:0] lo_sum;  // 33-bit to catch carry
    logic [31:0] hi_sum;
    logic [63:0] accumulate_result;
    
    // Perform multiplication
    always_comb begin
        if (mul_signed) begin
            // Signed multiply
            mul_result = $signed(operand_a) * $signed(operand_b);
        end else begin
            // Unsigned multiply
            mul_result = operand_a * operand_b;
        end
        
        // Prepare accumulator value
        accumulator = {acc_hi, acc_lo};
        
        // Manual 64-bit addition for accumulate operations
        lo_sum = {1'b0, mul_result[31:0]} + {1'b0, accumulator[31:0]};
        hi_sum = mul_result[63:32] + accumulator[63:32] + lo_sum[32];
        accumulate_result = {hi_sum, lo_sum[31:0]};
        
        // Handle different multiply types
        case (mul_type)
            MUL_TYPE_MUL: begin
                // MUL: Rd = Rm * Rs
                final_result = {32'b0, mul_result[31:0]};
            end
            
            MUL_TYPE_MLA: begin
                // MLA: Rd = (Rm * Rs) + Rn
                final_result = {32'b0, mul_result[31:0] + acc_lo};
            end
            
            MUL_TYPE_MULL: begin
                // UMULL/SMULL: RdHi:RdLo = Rm * Rs
                final_result = mul_result;
            end
            
            MUL_TYPE_MLAL: begin
                // UMLAL/SMLAL: RdHi:RdLo = (Rm * Rs) + RdHi:RdLo
                final_result = accumulate_result;
            end
            
            default: begin
                final_result = 64'b0;
            end
        endcase
    end
    
    // Output results based on multiply type
    assign result_hi = (mul_type == MUL_TYPE_MULL || mul_type == MUL_TYPE_MLAL) ? 
                      final_result[63:32] : 32'b0;
    assign result_lo = final_result[31:0];
    assign result_ready = mul_en;  // Single cycle multiply for now
    
    // Flags (only updated if mul_set_flags is asserted)
    assign negative = mul_set_flags ? 
                     ((mul_type == MUL_TYPE_MULL || mul_type == MUL_TYPE_MLAL) ? 
                      final_result[63] : final_result[31]) : 1'b0;
    assign zero = mul_set_flags ? 
                 ((mul_type == MUL_TYPE_MULL || mul_type == MUL_TYPE_MLAL) ? 
                  (final_result == 64'b0) : (final_result[31:0] == 32'b0)) : 1'b0;

endmodule