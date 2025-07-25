// Basic execution test for ARM7TDMI ALU operations
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module basic_execution_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test signals for decode module only (not full core)
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
    
    // Register file for testing
    logic [31:0] registers [0:15];
    logic [31:0] cpsr;
    
    // ALU signals
    logic [31:0] alu_a, alu_b, alu_result;
    logic alu_carry_out, alu_overflow;
    logic alu_zero, alu_negative;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
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
    
    // Simple ALU for testing execution
    always_comb begin
        case (decode_alu_op)
            ALU_AND: alu_result = alu_a & alu_b;
            ALU_EOR: alu_result = alu_a ^ alu_b;
            ALU_SUB: {alu_carry_out, alu_result} = {1'b0, alu_a} - {1'b0, alu_b};
            ALU_RSB: {alu_carry_out, alu_result} = {1'b0, alu_b} - {1'b0, alu_a};
            ALU_ADD: {alu_carry_out, alu_result} = alu_a + alu_b;
            ALU_ADC: {alu_carry_out, alu_result} = alu_a + alu_b + cpsr[29]; // C flag
            ALU_SBC: {alu_carry_out, alu_result} = alu_a - alu_b - !cpsr[29]; // !C flag
            ALU_RSC: {alu_carry_out, alu_result} = alu_b - alu_a - !cpsr[29]; // !C flag
            ALU_TST: alu_result = alu_a & alu_b;  // Test
            ALU_TEQ: alu_result = alu_a ^ alu_b;  // Test equivalence
            ALU_CMP: {alu_carry_out, alu_result} = {1'b0, alu_a} - {1'b0, alu_b};
            ALU_CMN: {alu_carry_out, alu_result} = alu_a + alu_b;
            ALU_ORR: alu_result = alu_a | alu_b;
            ALU_MOV: alu_result = alu_b;
            ALU_BIC: alu_result = alu_a & ~alu_b;
            ALU_MVN: alu_result = ~alu_b;
            default: alu_result = 32'h0;
        endcase
        
        alu_zero = (alu_result == 32'h0);
        alu_negative = alu_result[31];
        alu_overflow = 1'b0; // Simplified for now
    end
    
    // Test instruction execution
    task test_instruction_execution(input [31:0] instr, input string name, 
                                   input [31:0] reg_rn_val, input [31:0] reg_rm_val,
                                   input [31:0] expected_result);
        tests_run++;
        instruction = instr;
        
        @(posedge clk);  // Let decode settle
        
        // Set up register values based on decoded register indices
        registers[decode_rn] = reg_rn_val;
        registers[decode_rm] = reg_rm_val;
        
        // Set up ALU inputs based on decode
        alu_a = registers[decode_rn];
        if (decode_imm_en) begin
            alu_b = {20'b0, decode_immediate};
        end else begin
            alu_b = registers[decode_rm]; // Simplified - no shifting for now
        end
        
        #1;  // Let ALU settle
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Decode: instr_type=%d, alu_op=%d, rd=%d, rn=%d, rm=%d", 
                 decode_instr_type, decode_alu_op, decode_rd, decode_rn, decode_rm);
        $display("  ALU: a=0x%08x, b=0x%08x, result=0x%08x", alu_a, alu_b, alu_result);
        $display("  Expected: 0x%08x", expected_result);
        
        if (alu_result == expected_result) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("basic_execution_tb.vcd");
        $dumpvars(0, basic_execution_tb);
        
        // Initialize
        cpsr = 32'h0;
        for (int i = 0; i < 16; i++) begin
            registers[i] = 32'h0;
        end
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== Basic ARM7TDMI Execution Test ===");
        
        // Test basic ALU operations
        test_instruction_execution(32'hE0820001, "ADD R0, R2, R1", 32'h10, 32'h20, 32'h30);
        test_instruction_execution(32'hE0420001, "SUB R0, R2, R1", 32'h30, 32'h10, 32'h20);
        test_instruction_execution(32'hE0000001, "AND R0, R0, R1", 32'hFF, 32'h0F, 32'h0F);
        test_instruction_execution(32'hE1800001, "ORR R0, R0, R1", 32'hF0, 32'h0F, 32'hFF);
        test_instruction_execution(32'hE1A00001, "MOV R0, R1", 32'h00, 32'h42, 32'h42);
        
        // Test with immediate values
        test_instruction_execution(32'hE2820005, "ADD R0, R2, #5", 32'h10, 32'h00, 32'h15);
        test_instruction_execution(32'hE2420003, "SUB R0, R2, #3", 32'h10, 32'h00, 32'h0D);
        
        // Test multiply instructions (simplified)
        $display("=== Testing Multiply Instructions ===");
        instruction = 32'hE0000291; // MUL R0, R1, R2
        @(posedge clk);
        $display("MUL decode: type=%d (expected 1)", decode_instr_type);
        
        instruction = 32'hE0203192; // MLA R0, R1, R3, R2
        @(posedge clk);  
        $display("MLA decode: type=%d (expected 1)", decode_instr_type);
        
        // Test branch instructions (decode only - can't test actual branching easily)
        $display("=== Testing Branch Decode ===");
        instruction = 32'hEA000000;  // B +0
        @(posedge clk);
        $display("Branch instruction decode: type=%d, is_branch=%d, offset=0x%06x", 
                 decode_instr_type, decode_is_branch, decode_branch_offset);
        
        instruction = 32'hE12FFF10;  // BX R0
        @(posedge clk);
        $display("BX instruction decode: type=%d, is_branch=%d", 
                 decode_instr_type, decode_is_branch);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL EXECUTION TESTS PASSED!");
        end else begin
            $display("❌ SOME EXECUTION TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule