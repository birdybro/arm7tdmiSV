// Block transfer user mode test for ARM7TDMI
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module block_user_mode_test_tb;

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
    alu_op_t decode_alu_op;
    logic [3:0] decode_rd, decode_rn, decode_rm;
    logic [11:0] decode_immediate;
    logic decode_imm_en, decode_set_flags;
    logic decode_is_memory, decode_mem_load, decode_mem_byte;
    logic decode_mem_pre, decode_mem_up, decode_mem_writeback;
    logic [31:0] decode_pc;
    logic decode_valid;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
    // Task variables
    logic test_passed;
    logic expected_user_mode;
    logic actual_user_mode;
    
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
        
        // Unused outputs
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
    
    // Simulate the user mode logic from arm7tdmi_top
    assign actual_user_mode = (decode_instr_type == INSTR_BLOCK_DT) ? instruction[22] : 1'b0;
    
    // Test task for block transfer instructions
    task test_block_transfer(input [31:0] instr, input string name, input logic expect_user_mode);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Expected user mode: %b", expect_user_mode);
        
        instruction = instr;
        expected_user_mode = expect_user_mode;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, is_block=%b", decode_instr_type, (decode_instr_type == INSTR_BLOCK_DT));
        $display("  Actual user mode: %b", actual_user_mode);
        $display("  S bit (bit 22): %b", instruction[22]);
        
        // Check that block transfer is detected correctly and user mode is right
        test_passed = (decode_instr_type == INSTR_BLOCK_DT) && (actual_user_mode == expected_user_mode);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    // Test task for non-block instructions
    task test_non_block_transfer(input [31:0] instr, input string name);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        
        instruction = instr;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, is_block=%b", decode_instr_type, (decode_instr_type == INSTR_BLOCK_DT));
        $display("  User mode output: %b", actual_user_mode);
        
        // For non-block instructions, user_mode should always be 0
        test_passed = (decode_instr_type != INSTR_BLOCK_DT) && (actual_user_mode == 1'b0);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("block_user_mode_test_tb.vcd");
        $dumpvars(0, block_user_mode_test_tb);
        
        // Initial reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Block Transfer User Mode Test ===");
        
        // Test block transfer instructions with S bit clear (normal mode)
        $display("\n=== Block Transfer Instructions (S=0) ===");
        
        // LDMIA r0, {r1,r2,r3} - S bit = 0 (bit 22 = 0)
        test_block_transfer(32'hE890000E, "LDMIA r0, {r1,r2,r3} (S=0)", 1'b0);
        
        // STMDB r13!, {r4,r5,lr} - S bit = 0 (bit 22 = 0)  
        test_block_transfer(32'hE92D4030, "STMDB r13!, {r4,r5,lr} (S=0)", 1'b0);
        
        // Test block transfer instructions with S bit set (user mode access)
        $display("\n=== Block Transfer Instructions (S=1) ===");
        
        // LDMIA r0, {r1,r2,r3}^ - S bit = 1 (bit 22 = 1)
        test_block_transfer(32'hE8F0000E, "LDMIA r0, {r1,r2,r3}^ (S=1)", 1'b1);
        
        // STMDB r13!, {r4,r5,lr}^ - S bit = 1 (bit 22 = 1)
        test_block_transfer(32'hE96D4030, "STMDB r13!, {r4,r5,lr}^ (S=1)", 1'b1);
        
        // Test non-block transfer instructions (should not affect user_mode)
        $display("\n=== Non-Block Transfer Instructions ===");
        
        // MOV r0, r1 (with bit 22 = 1, but not a block transfer)
        test_non_block_transfer(32'h1400001E, "MOV r0, r1 (bit 22=1)");
        
        // LDR r0, [r1] (with bit 22 = 1, but not a block transfer)
        test_non_block_transfer(32'h1400005E, "LDR r0, [r1] (bit 22=1)");
        
        // ADD r0, r1, r2 (with bit 22 = 1, but not a block transfer)
        test_non_block_transfer(32'h2001408E, "ADD r0, r1, r2 (bit 22=1)");
        
        // Summary
        @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL BLOCK USER MODE TESTS PASSED!");
        end else begin
            $display("❌ SOME BLOCK USER MODE TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule