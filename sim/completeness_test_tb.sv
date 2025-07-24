// ARM7TDMI Instruction Set Completeness Verification
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module completeness_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test completion counters
    int arm_instructions_tested = 0;
    int thumb_instructions_tested = 0;
    int passed_tests = 0;
    int total_tests = 0;
    
    // Test signals for decode module
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h00000000;
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
    shift_type_t decode_shift_type;
    logic [4:0] decode_shift_amount;
    logic decode_shift_reg;
    logic [3:0] decode_shift_rs;
    logic decode_is_branch, decode_branch_link;
    logic [23:0] decode_branch_offset;
    logic decode_is_memory, decode_mem_load, decode_mem_byte;
    logic decode_mem_pre, decode_mem_up, decode_mem_writeback;
    logic decode_psr_to_reg, decode_psr_spsr, decode_psr_immediate;
    cp_op_t decode_cp_op;
    logic [3:0] decode_cp_num, decode_cp_rd, decode_cp_rn;
    logic [2:0] decode_cp_opcode1, decode_cp_opcode2;
    logic decode_cp_load;
    thumb_instr_type_t decode_thumb_instr_type;
    logic [2:0] decode_thumb_rd, decode_thumb_rs, decode_thumb_rn;
    logic [7:0] decode_thumb_imm8, decode_thumb_offset8;
    logic [4:0] decode_thumb_imm5;
    logic [10:0] decode_thumb_offset11;
    logic [31:0] decode_pc;
    logic decode_valid;
    
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
        .shift_type     (decode_shift_type),
        .shift_amount   (decode_shift_amount),
        .shift_reg      (decode_shift_reg),
        .shift_rs       (decode_shift_rs),
        .is_branch      (decode_is_branch),
        .branch_offset  (decode_branch_offset),
        .branch_link    (decode_branch_link),
        .is_memory      (decode_is_memory),
        .mem_load       (decode_mem_load),
        .mem_byte       (decode_mem_byte),
        .mem_pre        (decode_mem_pre),
        .mem_up         (decode_mem_up),
        .mem_writeback  (decode_mem_writeback),
        .psr_to_reg     (decode_psr_to_reg),
        .psr_spsr       (decode_psr_spsr),
        .psr_immediate  (decode_psr_immediate),
        .cp_op          (decode_cp_op),
        .cp_num         (decode_cp_num),
        .cp_rd          (decode_cp_rd),
        .cp_rn          (decode_cp_rn),
        .cp_opcode1     (decode_cp_opcode1),
        .cp_opcode2     (decode_cp_opcode2),
        .cp_load        (decode_cp_load),
        .thumb_instr_type (decode_thumb_instr_type),
        .thumb_rd       (decode_thumb_rd),
        .thumb_rs       (decode_thumb_rs),
        .thumb_rn       (decode_thumb_rn),
        .thumb_imm8     (decode_thumb_imm8),
        .thumb_imm5     (decode_thumb_imm5),
        .thumb_offset11 (decode_thumb_offset11),
        .thumb_offset8  (decode_thumb_offset8),
        .pc_out         (decode_pc),
        .decode_valid   (decode_valid)
    );
    
    task test_arm_instruction(input [31:0] instr, input string name, input instr_type_t expected_type);
        instruction = instr;
        thumb_mode = 0;
        @(posedge clk);
        total_tests++;
        if (decode_instr_type == expected_type && decode_valid) begin
            passed_tests++;
            $display("PASS: %s - Type: %d", name, decode_instr_type);
        end else begin
            $display("FAIL: %s - Expected: %d, Got: %d", name, expected_type, decode_instr_type);
        end
        arm_instructions_tested++;
    endtask
    
    task test_thumb_instruction(input [31:0] instr, input string name, input thumb_instr_type_t expected_type);
        instruction = instr;
        thumb_mode = 1;
        @(posedge clk);
        total_tests++;
        if (decode_thumb_instr_type == expected_type && decode_valid) begin
            passed_tests++;
            $display("PASS: %s - Type: %d", name, decode_thumb_instr_type);
        end else begin
            $display("FAIL: %s - Expected: %d, Got: %d", name, expected_type, decode_thumb_instr_type);
        end
        thumb_instructions_tested++;
    endtask
    
    initial begin
        $dumpfile("completeness_test_tb.vcd");
        $dumpvars(0, completeness_test_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Instruction Set Completeness Test ===");
        
        // ARM Mode Instruction Tests
        $display("\n--- ARM Mode Instructions ---");
        
        // Data Processing Instructions
        test_arm_instruction(32'hE0820001, "ADD R0, R2, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE0420001, "SUB R0, R2, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE1A00001, "MOV R0, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE0000001, "AND R0, R0, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE1800001, "ORR R0, R0, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE0200001, "EOR R0, R0, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE1C00001, "BIC R0, R0, R1", INSTR_DATA_PROC);
        test_arm_instruction(32'hE1E00001, "MVN R0, R1", INSTR_DATA_PROC);
        
        // Multiply Instructions
        test_arm_instruction(32'hE0000291, "MUL R0, R1, R2", INSTR_MUL);
        test_arm_instruction(32'hE0200391, "MLA R0, R1, R3, R2", INSTR_MUL);
        test_arm_instruction(32'hE0800291, "UMULL R0, R1, R2, R2", INSTR_MUL_LONG);
        test_arm_instruction(32'hE0C00291, "SMULL R0, R1, R2, R2", INSTR_MUL_LONG);
        
        // Memory Instructions
        test_arm_instruction(32'hE5910000, "LDR R0, [R1]", INSTR_SINGLE_DT);
        test_arm_instruction(32'hE5810000, "STR R0, [R1]", INSTR_SINGLE_DT);
        test_arm_instruction(32'hE5D10000, "LDRB R0, [R1]", INSTR_SINGLE_DT);
        test_arm_instruction(32'hE8910003, "LDM R1, {R0, R1}", INSTR_BLOCK_DT);
        
        // Halfword Instructions
        test_arm_instruction(32'hE1D100B0, "LDRH R0, [R1]", INSTR_HALFWORD_DT);
        test_arm_instruction(32'hE1D100D0, "LDRSB R0, [R1]", INSTR_HALFWORD_DT);
        test_arm_instruction(32'hE1D100F0, "LDRSH R0, [R1]", INSTR_HALFWORD_DT);
        
        // Branch Instructions
        test_arm_instruction(32'hEA000000, "B +0", INSTR_BRANCH);
        test_arm_instruction(32'hEB000000, "BL +0", INSTR_BRANCH);
        test_arm_instruction(32'hE12FFF10, "BX R0", INSTR_BRANCH_EX);
        
        // Swap Instructions
        test_arm_instruction(32'hE1000091, "SWP R0, R1, [R0]", INSTR_SINGLE_SWAP);
        test_arm_instruction(32'hE1400091, "SWPB R0, R1, [R0]", INSTR_SINGLE_SWAP);
        
        // PSR Transfer
        test_arm_instruction(32'hE10F0000, "MRS R0, CPSR", INSTR_PSR_TRANSFER);
        test_arm_instruction(32'hE129F000, "MSR CPSR, R0", INSTR_PSR_TRANSFER);
        
        // System Instructions
        test_arm_instruction(32'hEF000000, "SWI 0", INSTR_SWI);
        
        // Coprocessor Instructions  
        test_arm_instruction(32'hEE000000, "CDP p0, 0, c0, c0, c0", INSTR_COPROCESSOR);
        test_arm_instruction(32'hEC100000, "LDC p0, c0, [R0]", INSTR_COPROCESSOR);
        test_arm_instruction(32'hEE000010, "MCR p0, 0, R0, c0, c0", INSTR_COPROCESSOR);
        
        // Thumb Mode Instruction Tests
        $display("\n--- Thumb Mode Instructions ---");
        
        // Test key Thumb instructions
        test_thumb_instruction(32'h0148, "LSL R0, R1, #5", THUMB_SHIFT);
        test_thumb_instruction(32'h3205, "MOV R2, #5", THUMB_CMP_MOV_IMM);
        test_thumb_instruction(32'h1888, "ADD R0, R1, R2", THUMB_ALU_IMM);
        test_thumb_instruction(32'h4408, "ADD R0, R1 (hi)", THUMB_ALU_HI);
        test_thumb_instruction(32'h4700, "BX R0", THUMB_ALU_HI);
        test_thumb_instruction(32'h6800, "LDR R0, [R0]", THUMB_LOAD_STORE_IMM);
        test_thumb_instruction(32'h8800, "LDRH R0, [R0]", THUMB_LOAD_STORE_HW);
        test_thumb_instruction(32'hC800, "LDM R0!, {R3}", THUMB_LOAD_STORE_MULT);
        test_thumb_instruction(32'hD000, "BEQ +0", THUMB_BRANCH_COND);
        test_thumb_instruction(32'hE000, "B +0", THUMB_BRANCH_UNCOND);
        test_thumb_instruction(32'hF000, "BL prefix (11110)", THUMB_BL_HIGH);
        test_thumb_instruction(32'hF800, "BL suffix (11111)", THUMB_BL_LOW);
        
        // Summary
        @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("ARM Instructions Tested: %d", arm_instructions_tested);
        $display("Thumb Instructions Tested: %d", thumb_instructions_tested);
        $display("Total Tests: %d", total_tests);
        $display("Passed Tests: %d", passed_tests);
        $display("Pass Rate: %0.1f%%", (passed_tests * 100.0) / total_tests);
        
        if (passed_tests == total_tests) begin
            $display("\n✅ ALL TESTS PASSED - ARM7TDMI INSTRUCTION SET COMPLETE!");
        end else begin
            $display("\n❌ SOME TESTS FAILED - INSTRUCTION SET INCOMPLETE");
        end
        
        $display("=== Completeness Test Complete ===");
        $finish;
    end
    
endmodule