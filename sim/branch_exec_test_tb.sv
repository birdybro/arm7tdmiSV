// Branch execution test for ARM7TDMI (B/BL/BX)
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module branch_exec_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test signals for decode module
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h00001000; // Starting PC
    logic instr_valid = 1;
    logic stall = 0;
    logic flush = 0;
    logic thumb_mode = 0;
    
    // Decode outputs
    condition_t decode_condition;
    instr_type_t decode_instr_type;
    alu_op_t decode_alu_op;
    logic [3:0] decode_rd, decode_rn, decode_rm;
    logic [11:0] decode_immediate;
    logic decode_imm_en, decode_set_flags;
    logic decode_is_memory, decode_mem_load, decode_mem_byte;
    logic decode_mem_pre, decode_mem_up, decode_mem_writeback;
    logic [31:0] decode_pc;
    logic decode_valid;
    logic decode_is_branch;
    logic [23:0] decode_branch_offset;
    logic decode_branch_link;
    
    // Program counter and condition flags
    logic [31:0] current_pc;
    logic [31:0] next_pc;
    logic [31:0] link_register; // R14
    
    // Condition flags (CPSR)
    logic flag_n, flag_z, flag_c, flag_v;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
    // Task variables
    logic test_passed;
    logic [31:0] expected_pc;
    logic [31:0] expected_lr;
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
        .alu_op         (decode_alu_op),
        .rd             (decode_rd),
        .rn             (decode_rn),
        .rm             (decode_rm),
        .immediate      (decode_immediate),
        .imm_en         (decode_imm_en),
        .set_flags      (decode_set_flags),
        .is_memory      (decode_is_memory),
        .mem_load       (decode_mem_load),
        .mem_byte       (decode_mem_byte),
        .mem_pre        (decode_mem_pre),
        .mem_up         (decode_mem_up),
        .mem_writeback  (decode_mem_writeback),
        .pc_out         (decode_pc),
        .decode_valid   (decode_valid),
        .is_branch      (decode_is_branch),
        .branch_offset  (decode_branch_offset),
        .branch_link    (decode_branch_link),
        
        // Unused outputs
        .shift_type     (),
        .shift_amount   (),
        .shift_reg      (),
        .shift_rs       (),
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
    
    // Branch execution logic
    always_comb begin
        if (decode_is_branch && decode_valid && condition_met) begin
            // Sign extend 24-bit offset to 32 bits and shift left by 2 (word alignment)
            logic [31:0] signed_offset;
            signed_offset = {{6{decode_branch_offset[23]}}, decode_branch_offset, 2'b00};
            
            // Calculate target address: (PC of this instruction) + 8 + offset 
            // ARM pipeline: PC+8 is the effective PC when branch executes
            next_pc = pc_in + 32'd8 + signed_offset;
            
            // Handle link register for BL instructions
            if (decode_branch_link) begin
                link_register = pc_in + 32'd4; // Return address (next instruction)
            end else begin
                link_register = 32'h0; // No change for B instructions
            end
        end else begin
            // No branch taken - PC advances normally
            next_pc = current_pc + 32'd4;
            link_register = 32'h0;
        end
    end
    
    // Test task for branch operations
    task test_branch_instruction(input [31:0] instr, input string name,
                                 input [31:0] start_pc, input [31:0] expected_target,
                                 input [31:0] expected_link,
                                 input logic n_flag, input logic z_flag, 
                                 input logic c_flag, input logic v_flag);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Start PC: 0x%08x, Flags: N=%b Z=%b C=%b V=%b", 
                 start_pc, n_flag, z_flag, c_flag, v_flag);
        
        // Set up test conditions
        current_pc = start_pc;
        pc_in = start_pc;
        instruction = instr;
        expected_pc = expected_target;
        expected_lr = expected_link;
        
        // Set condition flags
        flag_n = n_flag;
        flag_z = z_flag;
        flag_c = c_flag;
        flag_v = v_flag;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, is_branch=%b, branch_link=%b, condition=%d", 
                 decode_instr_type, decode_is_branch, decode_branch_link, decode_condition);
        $display("  Branch offset: 0x%06x, Condition met: %b", 
                 decode_branch_offset, condition_met);
        $display("  Next PC: 0x%08x, Expected: 0x%08x", next_pc, expected_pc);
        
        if (decode_branch_link) begin
            $display("  Link Register: 0x%08x, Expected: 0x%08x", link_register, expected_lr);
        end
        
        // Check results
        test_passed = (next_pc == expected_pc);
        if (decode_branch_link && expected_lr != 32'h0) begin
            test_passed = test_passed && (link_register == expected_lr);
        end
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
            if (next_pc != expected_pc) begin
                $display("    PC mismatch: got 0x%08x, expected 0x%08x", next_pc, expected_pc);
            end
            if (decode_branch_link && link_register != expected_lr) begin
                $display("    LR mismatch: got 0x%08x, expected 0x%08x", link_register, expected_lr);
            end
        end
        $display("");
    endtask
    
    // Test task for BX (Branch and Exchange) operations
    task test_bx_instruction(input [31:0] instr, input string name,
                            input [31:0] start_pc, input [31:0] target_reg_value,
                            input [31:0] expected_target, input logic expected_thumb);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Start PC: 0x%08x, Target reg: 0x%08x", start_pc, target_reg_value);
        
        // Set up test conditions  
        current_pc = start_pc;
        pc_in = start_pc;
        instruction = instr;
        expected_pc = expected_target;
        
        // Note: BX instruction execution would need register file access
        // For this test, we're mainly validating decode behavior
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, is_branch=%b, rm=%d", 
                 decode_instr_type, decode_is_branch, decode_rm);
        $display("  Expected target: 0x%08x, Expected Thumb: %b", expected_target, expected_thumb);
        
        // For BX, we mainly check decode correctness
        test_passed = (decode_instr_type == INSTR_BRANCH_EX);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS (Decode correct)");
        end else begin
            $display("  ❌ FAIL - Decode error");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("branch_exec_test_tb.vcd");
        $dumpvars(0, branch_exec_test_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Branch Execution Test ===");
        
        // Test unconditional branches
        $display("\n=== Unconditional Branch (B) Operations ===");
        // B +4: Forward branch by 4 bytes (1 instruction)
        test_branch_instruction(32'hEA000001, "B +4", 32'h1000, 32'h100C, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // B -16: Backward branch by 16 bytes  
        test_branch_instruction(32'hEAFFFFFD, "B -16", 32'h1000, 32'hFFC, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // B +1020: Forward branch by 1020 bytes
        test_branch_instruction(32'hEA0000FF, "B +1020", 32'h1000, 32'h1404, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // Test branch with link (BL)
        $display("\n=== Branch with Link (BL) Operations ===");
        // BL +4: Forward branch with link (1 instruction)
        test_branch_instruction(32'hEB000001, "BL +4", 32'h1000, 32'h100C, 32'h1004, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // BL +96: Forward branch with link to subroutine (24 instructions)
        test_branch_instruction(32'hEB000018, "BL +96", 32'h2000, 32'h2068, 32'h2004, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // Test conditional branches - taken
        $display("\n=== Conditional Branches (Taken) ===");
        // BEQ +12 (taken when Z=1) - offset 3 = 12 bytes forward
        test_branch_instruction(32'h0A000003, "BEQ +12 (taken)", 32'h1000, 32'h1014, 32'h0, 1'b0, 1'b1, 1'b0, 1'b0);
        
        // BMI +4 (taken when N=1) - offset 1 = 4 bytes forward  
        test_branch_instruction(32'h4A000001, "BMI +4 (taken)", 32'h1000, 32'h100C, 32'h0, 1'b1, 1'b0, 1'b0, 1'b0);
        
        // BCS +8 (taken when C=1) - offset 2 = 8 bytes forward
        test_branch_instruction(32'h2A000002, "BCS +8 (taken)", 32'h1000, 32'h1010, 32'h0, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // Test conditional branches - not taken
        $display("\n=== Conditional Branches (Not Taken) ===");
        // BEQ +12 (not taken when Z=0) - should advance normally
        test_branch_instruction(32'h0A000003, "BEQ +12 (not taken)", 32'h1000, 32'h1004, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // BMI +4 (not taken when N=0) - should advance normally
        test_branch_instruction(32'h4A000001, "BMI +4 (not taken)", 32'h1000, 32'h1004, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // BCS +8 (not taken when C=0) - should advance normally
        test_branch_instruction(32'h2A000002, "BCS +8 (not taken)", 32'h1000, 32'h1004, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // Test complex conditional branches
        $display("\n=== Complex Conditional Branches ===");
        // BGT +16 (taken when Z=0 and N=V) - offset 4 = 16 bytes forward
        test_branch_instruction(32'hCA000004, "BGT +16 (taken)", 32'h1000, 32'h1018, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // BLE +12 (taken when Z=1 or N!=V) - offset 3 = 12 bytes forward
        test_branch_instruction(32'hDA000003, "BLE +12 (taken)", 32'h1000, 32'h1014, 32'h0, 1'b1, 1'b1, 1'b0, 1'b0);
        
        // Test BX (Branch and Exchange) instructions
        $display("\n=== Branch and Exchange (BX) Operations ===");
        // BX R0 (branch to ARM mode)
        test_bx_instruction(32'hE12FFF10, "BX R0", 32'h1000, 32'h2000, 32'h2000, 1'b0);
        
        // BX R1 (branch to Thumb mode - bit 0 set)
        test_bx_instruction(32'hE12FFF11, "BX R1", 32'h1000, 32'h2001, 32'h2000, 1'b1);
        
        // Test edge cases
        $display("\n=== Edge Cases ===");
        // Maximum positive branch offset: 0x7FFFFF * 4 = 0x1FFFFFC bytes forward
        test_branch_instruction(32'hEA7FFFFF, "B +max", 32'h1000, 32'h2001004, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // Maximum negative branch offset: 0x800000 * 4 = 0x2000000 bytes backward  
        test_branch_instruction(32'hEA800000, "B -max", 32'h2000000, 32'h8, 32'h0, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL BRANCH EXECUTION TESTS PASSED!");
        end else begin
            $display("❌ SOME BRANCH EXECUTION TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule