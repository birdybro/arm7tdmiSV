// Register-controlled shift test for ARM7TDMI
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module register_shift_test_tb;

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
    shift_type_t decode_shift_type;
    logic [4:0] decode_shift_amount;
    logic decode_shift_reg;
    logic [3:0] decode_shift_rs;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
    // Task variables
    logic test_passed;
    
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
        .shift_type     (decode_shift_type),
        .shift_amount   (decode_shift_amount),
        .shift_reg      (decode_shift_reg),
        .shift_rs       (decode_shift_rs),
        
        // Unused outputs
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
    
    // Test task for register-controlled shift instructions
    task test_register_shift(input [31:0] instr, input string name, 
                            input [3:0] expected_rm, input [3:0] expected_rs);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Expected Rm: %d, Rs: %d", expected_rm, expected_rs);
        
        instruction = instr;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, shift_reg=%b", decode_instr_type, decode_shift_reg);
        $display("  Rm: %d, Rs: %d", decode_rm, decode_shift_rs);
        $display("  Shift type: %d, amount: %d", decode_shift_type, decode_shift_amount);
        
        // Check that register-controlled shift is detected correctly
        test_passed = (decode_instr_type == INSTR_DATA_PROC) && decode_shift_reg && 
                     (decode_rm == expected_rm) && (decode_shift_rs == expected_rs);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    // Test task for immediate shift instructions
    task test_immediate_shift(input [31:0] instr, input string name, 
                            input [3:0] expected_rm, input [4:0] expected_amount);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Expected Rm: %d, shift amount: %d", expected_rm, expected_amount);
        
        instruction = instr;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, shift_reg=%b", decode_instr_type, decode_shift_reg);
        $display("  Rm: %d, shift amount: %d", decode_rm, decode_shift_amount);
        $display("  Shift type: %d", decode_shift_type);
        
        // Check that immediate shift is detected correctly
        test_passed = (decode_instr_type == INSTR_DATA_PROC) && !decode_shift_reg && 
                     (decode_rm == expected_rm) && (decode_shift_amount == expected_amount);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("register_shift_test_tb.vcd");
        $dumpvars(0, register_shift_test_tb);
        
        // Initial reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Register-Controlled Shift Test ===");
        
        // Test register-controlled shift instructions
        $display("\n=== Register-Controlled Shift Instructions ===");
        
        // ADD r0, r1, r2 LSL r3 - register-controlled shift
        // 31-28: 1110 (AL), 27-26: 00, 25: 0, 24-21: 0100 (ADD), 20: 0, 19-16: 0001 (Rn=1)
        // 15-12: 0000 (Rd=0), 11-8: 0011 (Rs=3), 7: 0, 6-5: 00 (LSL), 4: 1, 3-0: 0010 (Rm=2)
        test_register_shift(32'hE0810312, "ADD r0, r1, r2 LSL r3", 4'd2, 4'd3);
        
        // ORR r4, r5, r6 LSR r7 - register-controlled shift  
        // 31-28: 1110 (AL), 27-26: 00, 25: 0, 24-21: 1100 (ORR), 20: 0, 19-16: 0101 (Rn=5)
        // 15-12: 0100 (Rd=4), 11-8: 0111 (Rs=7), 7: 0, 6-5: 01 (LSR), 4: 1, 3-0: 0110 (Rm=6)
        test_register_shift(32'hE18C4736, "ORR r4, r5, r6 LSR r7", 4'd6, 4'd7);
        
        // Test immediate shift instructions (for comparison)
        $display("\n=== Immediate Shift Instructions ===");
        
        // ADD r0, r1, r2 LSL #4 - immediate shift
        // 31-28: 1110 (AL), 27-26: 00, 25: 0, 24-21: 0100 (ADD), 20: 0, 19-16: 0001 (Rn=1)
        // 15-12: 0000 (Rd=0), 11-7: 00100 (shift amount=4), 6-5: 00 (LSL), 4: 0, 3-0: 0010 (Rm=2)
        test_immediate_shift(32'hE0810202, "ADD r0, r1, r2 LSL #4", 4'd2, 5'd4);
        
        // MOV r1, r2 ROR #8 - immediate shift
        // 31-28: 1110 (AL), 27-26: 00, 25: 0, 24-21: 1101 (MOV), 20: 0, 19-16: 0000 (Rn=0)
        // 15-12: 0001 (Rd=1), 11-7: 01000 (shift amount=8), 6-5: 11 (ROR), 4: 0, 3-0: 0010 (Rm=2)
        test_immediate_shift(32'hE1A01462, "MOV r1, r2 ROR #8", 4'd2, 5'd8);
        
        // Summary
        @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL REGISTER SHIFT TESTS PASSED!");
        end else begin
            $display("❌ SOME REGISTER SHIFT TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule