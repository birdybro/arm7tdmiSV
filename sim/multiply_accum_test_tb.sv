// ARM7TDMI Multiply Accumulation Test
// Tests MLA, UMLAL, and SMLAL instructions

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module multiply_accum_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test interface signals
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
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // DUT instantiation
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
    
    // Test task for multiply operations
    task test_multiply(
        input string test_name,
        input logic [2:0] test_type,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] acc_h,
        input logic [31:0] acc_l,
        input logic [31:0] exp_hi,
        input logic [31:0] exp_lo
    );
        test_count++;
        $display("\nTest %d: %s", test_count, test_name);
        $display("  A=0x%08X, B=0x%08X", a, b);
        if (test_type == 3'd1 || test_type == 3'd3 || test_type == 3'd5) begin
            $display("  Accumulator: Hi=0x%08X, Lo=0x%08X", acc_h, acc_l);
        end
        
        // Setup multiply operation
        operand_a = a;
        operand_b = b;
        acc_hi = acc_h;
        acc_lo = acc_l;
        mul_type = test_type;
        
        // Decode multiply type
        case (test_type)
            3'd0: begin
                mul_long = 1'b0;
                mul_signed = 1'b0;
                mul_accumulate = 1'b0;
            end
            3'd1: begin
                mul_long = 1'b0;
                mul_signed = 1'b0;
                mul_accumulate = 1'b1;
            end
            3'd2: begin
                mul_long = 1'b1;
                mul_signed = 1'b0;
                mul_accumulate = 1'b0;
            end
            3'd3: begin
                mul_long = 1'b1;
                mul_signed = 1'b0;
                mul_accumulate = 1'b1;
            end
            3'd4: begin
                mul_long = 1'b1;
                mul_signed = 1'b1;
                mul_accumulate = 1'b0;
            end
            3'd5: begin
                mul_long = 1'b1;
                mul_signed = 1'b1;
                mul_accumulate = 1'b1;
            end
        endcase
        
        mul_set_flags = 1'b1;
        mul_en = 1'b1;
        @(posedge clk);
        
        // Wait for result
        wait(result_ready);
        @(posedge clk);
        mul_en = 1'b0;
        
        // Check results
        if (result_hi == exp_hi && result_lo == exp_lo) begin
            test_passed++;
            $display("  ✅ PASS: Result correct");
            $display("    Got: Hi=0x%08X, Lo=0x%08X", result_hi, result_lo);
        end else begin
            $display("  ❌ FAIL: Result incorrect");
            $display("    Expected: Hi=0x%08X, Lo=0x%08X", exp_hi, exp_lo);
            $display("    Got:      Hi=0x%08X, Lo=0x%08X", result_hi, result_lo);
            // Debug info for signed multiply accumulate
            if (test_type == 3'd5) begin
                $display("    Debug: mul_signed=%b, operand_a=%d, operand_b=%d", 
                        u_multiply.mul_signed, $signed(operand_a), $signed(operand_b));
                $display("    Debug: mul_result=0x%016X", u_multiply.mul_result);
                $display("    Debug: accumulator=0x%016X", u_multiply.accumulator);
                $display("    Debug: accumulate_result=0x%016X", u_multiply.accumulate_result);
                $display("    Debug: final_result=0x%016X", u_multiply.final_result);
                $display("    Debug: result_hi assignment = final_result[63:32] = 0x%08X", 
                        u_multiply.final_result[63:32]);
            end
        end
        
        @(posedge clk);
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("multiply_accum_test_tb.vcd");
        $dumpvars(0, multiply_accum_test_tb);
        
        $display("=== ARM7TDMI Multiply Accumulation Test ===");
        
        // Initialize
        mul_en = 0;
        operand_a = 0;
        operand_b = 0;
        acc_hi = 0;
        acc_lo = 0;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test MLA (Multiply Accumulate)
        $display("\n=== MLA Tests ===");
        test_multiply("MLA: 5 * 7 + 10", 3'd1, 
                     32'd5, 32'd7, 32'd0, 32'd10,
                     32'd0, 32'd45);  // 5*7 + 10 = 45
        
        test_multiply("MLA: 100 * 200 + 5000", 3'd1,
                     32'd100, 32'd200, 32'd0, 32'd5000,
                     32'd0, 32'd25000);  // 100*200 + 5000 = 25000
        
        test_multiply("MLA: 0xFFFF * 0xFFFF + 0x10000", 3'd1,
                     32'h0000FFFF, 32'h0000FFFF, 32'd0, 32'h00010000,
                     32'd0, 32'hFFFF0001);  // 65535*65535 + 65536
        
        // Test UMLAL (Unsigned Multiply Accumulate Long)
        $display("\n=== UMLAL Tests ===");
        test_multiply("UMLAL: 0x10000 * 0x10000 + 0", 3'd3,
                     32'h00010000, 32'h00010000, 32'd0, 32'd0,
                     32'h00000001, 32'h00000000);  // 65536*65536 = 0x100000000
        
        test_multiply("UMLAL: 0xFFFFFFFF * 2 + 0x100000001", 3'd3,
                     32'hFFFFFFFF, 32'd2, 32'h00000001, 32'h00000001,
                     32'h00000002, 32'hFFFFFFFF);  // Large accumulation
        
        // Test SMLAL (Signed Multiply Accumulate Long)
        $display("\n=== SMLAL Tests ===");
        test_multiply("SMLAL: -1000 * 1000 + 0", 3'd5,
                     -32'd1000, 32'd1000, 32'd0, 32'd0,
                     32'hFFFFFFFF, -32'd1000000);  // -1000000
        
        test_multiply("SMLAL: -1 * -1 + (-1)", 3'd5,
                     32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,
                     32'd0, 32'd0);  // 1 + (-1) = 0
        
        test_multiply("SMLAL: 0x7FFFFFFF * 2 + 0x100000000", 3'd5,
                     32'h7FFFFFFF, 32'd2, 32'h00000001, 32'h00000000,
                     32'h00000001, 32'hFFFFFFFE);  // Max positive accumulation
        
        // Edge cases
        $display("\n=== Edge Cases ===");
        test_multiply("MLA: 0 * 0 + 0xFFFFFFFF", 3'd1,
                     32'd0, 32'd0, 32'd0, 32'hFFFFFFFF,
                     32'd0, 32'hFFFFFFFF);
        
        test_multiply("UMLAL: Max * Max + Max", 3'd3,
                     32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,
                     32'hFFFFFFFF, 32'hFFFFFFFE);  // Overflow case
        
        // Summary
        repeat(10) @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL MULTIPLY ACCUMULATION TESTS PASSED!");
        end else begin
            $display("\n❌ SOME MULTIPLY ACCUMULATION TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000; // 10us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule