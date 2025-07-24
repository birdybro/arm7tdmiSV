// Simple multiply testbench
`timescale 1ns/1ps

module multiply_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Multiply unit signals
    logic        mul_en;
    logic        mul_long;
    logic        mul_signed;
    logic        mul_accumulate;
    logic        mul_set_flags;
    logic [1:0]  mul_type;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [31:0] acc_hi;
    logic [31:0] acc_lo;
    logic [31:0] result_hi;
    logic [31:0] result_lo;
    logic        result_ready;
    logic        negative;
    logic        zero;
    
    // Instantiate multiply unit
    arm7tdmi_multiply u_multiply (
        .clk            (clk),
        .rst_n          (rst_n),
        .mul_en         (mul_en),
        .mul_long       (mul_long),
        .mul_signed     (mul_signed),
        .mul_accumulate (mul_accumulate),
        .mul_set_flags  (mul_set_flags),
        .mul_type       (mul_type),
        .operand_a      (operand_a),
        .operand_b      (operand_b),
        .acc_hi         (acc_hi),
        .acc_lo         (acc_lo),
        .result_hi      (result_hi),
        .result_lo      (result_lo),
        .result_ready   (result_ready),
        .negative       (negative),
        .zero           (zero)
    );
    
    initial begin
        $dumpfile("multiply_tb.vcd");
        $dumpvars(0, multiply_tb);
        
        // Reset
        rst_n = 0;
        mul_en = 0;
        mul_long = 0;
        mul_signed = 0;
        mul_accumulate = 0;
        mul_set_flags = 0;
        mul_type = 2'b00;
        operand_a = 32'h0;
        operand_b = 32'h0;
        acc_hi = 32'h0;
        acc_lo = 32'h0;
        
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("=== ARM7TDMI Multiply Unit Test ===");
        
        // Test 1: Simple MUL (5 * 7 = 35)
        $display("Test 1: MUL - 5 * 7");
        mul_en = 1;
        mul_type = 2'b00;  // MUL
        mul_set_flags = 1;
        operand_a = 32'd5;
        operand_b = 32'd7;
        @(posedge clk);
        if (result_lo == 32'd35) begin
            $display("  PASS: result = %d", result_lo);
        end else begin
            $display("  FAIL: expected 35, got %d", result_lo);
        end
        mul_en = 0;
        @(posedge clk);
        
        // Test 2: MLA (3 * 4 + 2 = 14)
        $display("Test 2: MLA - (3 * 4) + 2");
        mul_en = 1;
        mul_type = 2'b01;  // MLA
        mul_set_flags = 1;
        operand_a = 32'd3;
        operand_b = 32'd4;
        acc_lo = 32'd2;
        @(posedge clk);
        if (result_lo == 32'd14) begin
            $display("  PASS: result = %d", result_lo);
        end else begin
            $display("  FAIL: expected 14, got %d", result_lo);
        end
        mul_en = 0;
        @(posedge clk);
        
        // Test 3: UMULL (0xFFFFFFFF * 0xFFFFFFFF)
        $display("Test 3: UMULL - 0xFFFFFFFF * 0xFFFFFFFF");
        mul_en = 1;
        mul_type = 2'b10;  // UMULL
        mul_signed = 0;
        mul_set_flags = 1;
        operand_a = 32'hFFFFFFFF;
        operand_b = 32'hFFFFFFFF;
        acc_hi = 32'h0;
        acc_lo = 32'h0;
        @(posedge clk);
        $display("  Result: %08h_%08h", result_hi, result_lo);
        if (result_hi == 32'hFFFFFFFE && result_lo == 32'h00000001) begin
            $display("  PASS: UMULL correct");
        end else begin
            $display("  FAIL: expected FFFFFFFE_00000001");
        end
        mul_en = 0;
        @(posedge clk);
        
        // Test 4: SMULL (-1 * -1 = 1)
        $display("Test 4: SMULL - (-1) * (-1)");
        mul_en = 1;
        mul_type = 2'b10;  // SMULL
        mul_signed = 1;
        mul_set_flags = 1;
        operand_a = 32'hFFFFFFFF;  // -1
        operand_b = 32'hFFFFFFFF;  // -1
        @(posedge clk);
        $display("  Result: %08h_%08h", result_hi, result_lo);
        if (result_hi == 32'h00000000 && result_lo == 32'h00000001) begin
            $display("  PASS: SMULL correct");
        end else begin
            $display("  FAIL: expected 00000000_00000001");
        end
        mul_en = 0;
        @(posedge clk);
        
        // Test 5: Zero flag test (0 * anything = 0)
        $display("Test 5: Zero flag test - 0 * 42");
        mul_en = 1;
        mul_type = 2'b00;  // MUL
        mul_set_flags = 1;
        operand_a = 32'd0;
        operand_b = 32'd42;
        @(posedge clk);
        if (result_lo == 32'd0 && zero == 1'b1) begin
            $display("  PASS: result = 0, zero flag set");
        end else begin
            $display("  FAIL: expected 0 with zero flag, got %d, zero=%b", result_lo, zero);
        end
        mul_en = 0;
        
        $display("=== Test Complete ===");
        $finish;
    end
    
endmodule