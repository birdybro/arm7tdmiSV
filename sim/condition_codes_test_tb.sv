// Condition codes test for ARM7TDMI
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module condition_codes_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test signals for decode module
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h00001000;
    logic instr_valid = 1;
    logic stall = 0;
    logic flush = 0;
    logic thumb_mode = 0;
    
    // Decode outputs
    condition_t decode_condition;
    instr_type_t decode_instr_type;
    logic decode_valid;
    
    // CPSR flags
    logic flag_n, flag_z, flag_c, flag_v;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
    // Task variables
    logic test_passed;
    logic condition_met;
    
    // Instantiate decode module
    arm7tdmi_decode u_decode (
        .clk            (clk),
        .rst_n          (rst_n),
        .instruction    (instruction),
        .pc_in          (pc_in),
        .instr_valid    (instr_valid),
        .stall          (stall),
        .flush          (flush),
        .thumb_mode     (thumb_mode),
        
        .condition      (decode_condition),
        .instr_type     (decode_instr_type),
        .decode_valid   (decode_valid),
        
        // Unused outputs
        .alu_op         (),
        .rd             (),
        .rn             (),
        .rm             (),
        .immediate      (),
        .imm_en         (),
        .set_flags      (),
        .is_memory      (),
        .mem_load       (),
        .mem_byte       (),
        .mem_pre        (),
        .mem_up         (),
        .mem_writeback  (),
        .pc_out         (),
        .shift_type     (),
        .shift_amount   (),
        .shift_reg      (),
        .shift_rs       (),
        .is_branch      (),
        .branch_offset  (),
        .branch_link    (),
        .psr_to_reg     (),
        .psr_spsr       (),
        .psr_immediate  (),
        .cp_op          (),
        .cp_num         (),
        .cp_rd          (),
        .cp_rn          (),
        .cp_opcode1     (),
        .cp_opcode2     (),
        .cp_load        (),
        .thumb_instr_type (),
        .thumb_rd       (),
        .thumb_rs       (),
        .thumb_rn       (),
        .thumb_imm8     (),
        .thumb_imm5     (),
        .thumb_offset11 (),
        .thumb_offset8  ()
    );
    
    // Condition evaluation logic
    always_comb begin
        case (decode_condition)
            4'b0000: condition_met = flag_z;                    // EQ - Equal
            4'b0001: condition_met = !flag_z;                   // NE - Not Equal
            4'b0010: condition_met = flag_c;                    // CS/HS - Carry Set
            4'b0011: condition_met = !flag_c;                   // CC/LO - Carry Clear
            4'b0100: condition_met = flag_n;                    // MI - Minus
            4'b0101: condition_met = !flag_n;                   // PL - Plus
            4'b0110: condition_met = flag_v;                    // VS - Overflow Set
            4'b0111: condition_met = !flag_v;                   // VC - Overflow Clear
            4'b1000: condition_met = flag_c && !flag_z;         // HI - Higher
            4'b1001: condition_met = !flag_c || flag_z;         // LS - Lower or Same
            4'b1010: condition_met = flag_n == flag_v;          // GE - Greater or Equal
            4'b1011: condition_met = flag_n != flag_v;          // LT - Less Than
            4'b1100: condition_met = !flag_z && (flag_n == flag_v); // GT - Greater Than
            4'b1101: condition_met = flag_z || (flag_n != flag_v);  // LE - Less or Equal
            4'b1110: condition_met = 1'b1;                      // AL - Always
            4'b1111: condition_met = 1'b0;                      // NV - Never (deprecated)
            default: condition_met = 1'b0;
        endcase
    end
    
    // Test task for condition codes
    task test_condition_code(input [31:0] instr, input string name, input [3:0] expected_cond,
                            input logic n, input logic z, input logic c, input logic v,
                            input logic expected_result);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Flags: N=%b Z=%b C=%b V=%b", n, z, c, v);
        
        instruction = instr;
        flag_n = n;
        flag_z = z;
        flag_c = c;
        flag_v = v;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decoded condition: %d (0x%x), Expected: %d (0x%x)", 
                 decode_condition, decode_condition, expected_cond, expected_cond);
        $display("  Condition met: %b, Expected: %b", condition_met, expected_result);
        
        // Check results
        test_passed = (decode_condition == expected_cond) && (condition_met == expected_result);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
            if (decode_condition != expected_cond) begin
                $display("    Condition decode error: got %d, expected %d", decode_condition, expected_cond);
            end
            if (condition_met != expected_result) begin
                $display("    Condition evaluation error: got %b, expected %b", condition_met, expected_result);
            end
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("condition_codes_test_tb.vcd");
        $dumpvars(0, condition_codes_test_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Condition Codes Test ===");
        
        // Test all 16 condition codes
        $display("\n=== Basic Condition Codes ===");
        
        // EQ (0000) - Equal (Z=1)
        test_condition_code(32'h0E000000, "ADDEQ R0,R0,#0", 4'h0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'h0E000000, "ADDEQ R0,R0,#0", 4'h0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False
        
        // NE (0001) - Not Equal (Z=0)
        test_condition_code(32'h1E000000, "ADDNE R0,R0,#0", 4'h1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'h1E000000, "ADDNE R0,R0,#0", 4'h1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0); // False
        
        // CS/HS (0010) - Carry Set (C=1)
        test_condition_code(32'h2E000000, "ADDCS R0,R0,#0", 4'h2, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // True
        test_condition_code(32'h2E000000, "ADDCS R0,R0,#0", 4'h2, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False
        
        // CC/LO (0011) - Carry Clear (C=0)
        test_condition_code(32'h3E000000, "ADDCC R0,R0,#0", 4'h3, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'h3E000000, "ADDCC R0,R0,#0", 4'h3, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // False
        
        // MI (0100) - Minus (N=1)
        test_condition_code(32'h4E000000, "ADDMI R0,R0,#0", 4'h4, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'h4E000000, "ADDMI R0,R0,#0", 4'h4, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False
        
        // PL (0101) - Plus (N=0)
        test_condition_code(32'h5E000000, "ADDPL R0,R0,#0", 4'h5, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'h5E000000, "ADDPL R0,R0,#0", 4'h5, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // False
        
        // VS (0110) - Overflow Set (V=1)
        test_condition_code(32'h6E000000, "ADDVS R0,R0,#0", 4'h6, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1); // True
        test_condition_code(32'h6E000000, "ADDVS R0,R0,#0", 4'h6, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False
        
        // VC (0111) - Overflow Clear (V=0)
        test_condition_code(32'h7E000000, "ADDVC R0,R0,#0", 4'h7, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'h7E000000, "ADDVC R0,R0,#0", 4'h7, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0); // False
        
        $display("\n=== Complex Condition Codes ===");
        
        // HI (1000) - Higher (C=1 and Z=0)
        test_condition_code(32'h8E000000, "ADDHI R0,R0,#0", 4'h8, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // True
        test_condition_code(32'h8E000000, "ADDHI R0,R0,#0", 4'h8, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0); // False (Z=1)
        test_condition_code(32'h8E000000, "ADDHI R0,R0,#0", 4'h8, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False (C=0)
        
        // LS (1001) - Lower or Same (C=0 or Z=1)
        test_condition_code(32'h9E000000, "ADDLS R0,R0,#0", 4'h9, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1); // True (Z=1)
        test_condition_code(32'h9E000000, "ADDLS R0,R0,#0", 4'h9, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True (C=0)
        test_condition_code(32'h9E000000, "ADDLS R0,R0,#0", 4'h9, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // False
        
        // GE (1010) - Greater or Equal (N=V)
        test_condition_code(32'hAE000000, "ADDGE R0,R0,#0", 4'hA, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True (N=V=0)
        test_condition_code(32'hAE000000, "ADDGE R0,R0,#0", 4'hA, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1); // True (N=V=1)
        test_condition_code(32'hAE000000, "ADDGE R0,R0,#0", 4'hA, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // False (N!=V)
        
        // LT (1011) - Less Than (N!=V)
        test_condition_code(32'hBE000000, "ADDLT R0,R0,#0", 4'hB, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1); // True (N!=V)
        test_condition_code(32'hBE000000, "ADDLT R0,R0,#0", 4'hB, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1); // True (N!=V)
        test_condition_code(32'hBE000000, "ADDLT R0,R0,#0", 4'hB, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False (N=V)
        
        // GT (1100) - Greater Than (Z=0 and N=V)
        test_condition_code(32'hCE000000, "ADDGT R0,R0,#0", 4'hC, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // True
        test_condition_code(32'hCE000000, "ADDGT R0,R0,#0", 4'hC, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0); // False (Z=1)
        test_condition_code(32'hCE000000, "ADDGT R0,R0,#0", 4'hC, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // False (N!=V)
        
        // LE (1101) - Less or Equal (Z=1 or N!=V)
        test_condition_code(32'hDE000000, "ADDLE R0,R0,#0", 4'hD, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1); // True (Z=1)
        test_condition_code(32'hDE000000, "ADDLE R0,R0,#0", 4'hD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1); // True (N!=V)
        test_condition_code(32'hDE000000, "ADDLE R0,R0,#0", 4'hD, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // False
        
        // AL (1110) - Always
        test_condition_code(32'hEE000000, "ADD R0,R0,#0", 4'hE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1); // Always true
        test_condition_code(32'hEE000000, "ADD R0,R0,#0", 4'hE, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1); // Always true
        
        // NV (1111) - Never (deprecated, should not be used)
        test_condition_code(32'hFE000000, "ADDNV R0,R0,#0", 4'hF, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // Never
        test_condition_code(32'hFE000000, "ADDNV R0,R0,#0", 4'hF, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0); // Never
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL CONDITION CODE TESTS PASSED!");
        end else begin
            $display("❌ SOME CONDITION CODE TESTS FAILED");
        end
        
        // Display condition code table
        $display("\n=== ARM7TDMI Condition Code Table ===");
        $display("0000 (0x0) EQ - Equal (Z=1)");
        $display("0001 (0x1) NE - Not Equal (Z=0)");
        $display("0010 (0x2) CS/HS - Carry Set (C=1)");
        $display("0011 (0x3) CC/LO - Carry Clear (C=0)");
        $display("0100 (0x4) MI - Minus (N=1)");
        $display("0101 (0x5) PL - Plus (N=0)");
        $display("0110 (0x6) VS - Overflow Set (V=1)");
        $display("0111 (0x7) VC - Overflow Clear (V=0)");
        $display("1000 (0x8) HI - Higher (C=1 and Z=0)");
        $display("1001 (0x9) LS - Lower or Same (C=0 or Z=1)");
        $display("1010 (0xA) GE - Greater or Equal (N=V)");
        $display("1011 (0xB) LT - Less Than (N!=V)");
        $display("1100 (0xC) GT - Greater Than (Z=0 and N=V)");
        $display("1101 (0xD) LE - Less or Equal (Z=1 or N!=V)");
        $display("1110 (0xE) AL - Always");
        $display("1111 (0xF) NV - Never (deprecated)");
        
        $finish;
    end
    
endmodule