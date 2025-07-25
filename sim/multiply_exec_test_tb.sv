// Multiply instruction execution test for ARM7TDMI (MUL/MLA)
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module multiply_exec_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
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
    logic decode_is_memory, decode_mem_load, decode_mem_byte;
    logic decode_mem_pre, decode_mem_up, decode_mem_writeback;
    logic [31:0] decode_pc;
    logic decode_valid;
    
    // Register file signals (simplified for testing) - indexed by register number
    logic [31:0] register_file [0:15];
    
    // Current operand values based on instruction fields
    logic [31:0] reg_rm_data, reg_rs_data, reg_rn_data, reg_rd_data;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
    // Task variables
    logic test_passed;
    logic [31:0] expected_result;
    
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
    
    // Extract register fields from instruction for multiply operations
    logic [3:0] rs_field;
    assign rs_field = instruction[11:8];
    
    // For multiply instructions, use correct register field mappings:
    // MLA Rd, Rm, Rs, Rn format: Rd=[19:16], Rn=[15:12], Rs=[11:8], Rm=[3:0] 
    // But decoder uses standard mapping: decode_rn=[19:16], decode_rd=[15:12], decode_rm=[3:0]
    // So for multiply: decode_rn=Rd_field, decode_rd=Rn_field, decode_rm=Rm_field
    assign reg_rm_data = register_file[decode_rm];      // Rm from bits[3:0] ✓
    assign reg_rs_data = register_file[rs_field];       // Rs from bits[11:8] ✓ 
    assign reg_rn_data = register_file[decode_rd];      // Rn from bits[15:12] (mapped to decode_rd)
    
    // Simple multiply execution logic (for testing decode)
    // In a real implementation, this would be handled by a multiply unit
    always_comb begin
        if (decode_instr_type == INSTR_MUL && decode_valid) begin
            if (decode_alu_op == 4'b0000) begin
                // MUL: Rd = Rm * Rs  
                reg_rd_data = reg_rm_data * reg_rs_data;
            end else if (decode_alu_op == 4'b0001) begin
                // MLA: Rd = (Rm * Rs) + Rn
                reg_rd_data = (reg_rm_data * reg_rs_data) + reg_rn_data;
            end else begin
                reg_rd_data = 32'h0;
            end
        end else begin
            reg_rd_data = 32'h0;
        end
    end
    
    // Test task for multiply operations
    task test_multiply_instruction(input [31:0] instr, input string name,
                                  input [31:0] rm_val, input [31:0] rs_val, 
                                  input [31:0] rn_val, input [31:0] expected);
        logic [3:0] rm_reg, rs_reg, rn_reg, rd_reg;
        
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Rm=0x%08x, Rs=0x%08x, Rn=0x%08x", rm_val, rs_val, rn_val);
        
        // Extract register fields from instruction
        rm_reg = instr[3:0];   // Rm
        rs_reg = instr[11:8];  // Rs
        rn_reg = instr[15:12]; // Rn
        rd_reg = instr[19:16]; // Rd
        
        // Initialize register file with zero
        for (int i = 0; i < 16; i++) begin
            register_file[i] = 32'h0;
        end
        
        // Set up operand registers based on instruction fields
        register_file[rm_reg] = rm_val;
        register_file[rs_reg] = rs_val;
        register_file[rn_reg] = rn_val;
        
        // Debug: Show what we set in register file
        $display("  Setting registers: R%d=0x%08x, R%d=0x%08x, R%d=0x%08x", 
                 rm_reg, rm_val, rs_reg, rs_val, rn_reg, rn_val);
        
        instruction = instr;
        expected_result = expected;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, alu_op=0x%x, set_flags=%b", 
                 decode_instr_type, decode_alu_op, decode_set_flags);
        $display("  Register mapping: Rd=R%d, Rm=R%d, Rs=R%d, Rn=R%d", 
                 rd_reg, rm_reg, rs_reg, rn_reg);
        $display("  Decode fields: Rd=%d, Rm=%d, Rs=%d, Rn=%d", 
                 decode_rd, decode_rm, rs_field, decode_rn);
        $display("  Register values: Rm=0x%08x, Rs=0x%08x, Rn=0x%08x", 
                 reg_rm_data, reg_rs_data, reg_rn_data);
        $display("  Result: 0x%08x, Expected: 0x%08x", reg_rd_data, expected_result);
        
        // Check results
        test_passed = (reg_rd_data == expected_result);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL - Expected 0x%08x, got 0x%08x", expected_result, reg_rd_data);
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("multiply_exec_test_tb.vcd");
        $dumpvars(0, multiply_exec_test_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Multiply Execution Test ===");
        
        // Test MUL operations
        // Format: cond 0000000 S Rd 0000 Rs 1001 Rm 
        $display("\n=== Multiply (MUL) Operations ===");
        test_multiply_instruction(32'hE0010392, "MUL R1, R2, R3", 32'h5, 32'h7, 32'h0, 32'h23);
        test_multiply_instruction(32'hE0040596, "MUL R4, R6, R5", 32'hA, 32'hC, 32'h0, 32'h78);
        test_multiply_instruction(32'hE0070899, "MUL R7, R9, R8", 32'h3, 32'h4, 32'h0, 32'hC);
        test_multiply_instruction(32'hE00A0B9C, "MUL R10, R12, R11", 32'hFFFF, 32'h2, 32'h0, 32'h1FFFE);
        
        // Test MUL with S bit (set flags)
        $display("\n=== Multiply with Flags (MULS) Operations ===");
        test_multiply_instruction(32'hE0110392, "MULS R1, R2, R3", 32'h5, 32'h7, 32'h0, 32'h23);
        test_multiply_instruction(32'hE0150596, "MULS R5, R6, R5", 32'h0, 32'hC, 32'h0, 32'h0); // Zero result
        
        // Test MLA operations  
        // Format: cond 0000001 S Rd Rn Rs 1001 Rm
        $display("\n=== Multiply-Accumulate (MLA) Operations ===");
        test_multiply_instruction(32'hE0213492, "MLA R1, R2, R4, R3", 32'h5, 32'h7, 32'h10, 32'h33); // 5*7+16=51
        test_multiply_instruction(32'hE0256795, "MLA R5, R5, R7, R6", 32'h3, 32'h4, 32'h8, 32'h14);  // 3*4+8=20
        test_multiply_instruction(32'hE0298A9B, "MLA R9, R11, R10, R8", 32'h2, 32'h6, 32'h5, 32'h11); // 2*6+5=17
        
        // Test MLA with S bit (set flags)
        $display("\n=== Multiply-Accumulate with Flags (MLAS) Operations ===");
        test_multiply_instruction(32'hE0313492, "MLAS R1, R2, R4, R3", 32'h5, 32'h7, 32'h10, 32'h33);
        
        // Test edge cases
        $display("\n=== Edge Cases ===");
        test_multiply_instruction(32'hE0010392, "MUL R1, R2, R3 (zero)", 32'h0, 32'h7, 32'h0, 32'h0);
        test_multiply_instruction(32'hE0010392, "MUL R1, R2, R3 (one)", 32'h1, 32'h7, 32'h0, 32'h7);
        test_multiply_instruction(32'hE0213492, "MLA R1, R2, R4, R3 (zero mul)", 32'h0, 32'h0, 32'h42, 32'h42);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL MULTIPLY EXECUTION TESTS PASSED!");
        end else begin
            $display("❌ SOME MULTIPLY EXECUTION TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule