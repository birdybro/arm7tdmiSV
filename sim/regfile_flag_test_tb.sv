// Register file and flag validation test for ARM7TDMI
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module regfile_flag_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test signals for register file module
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
    
    // Register file signals
    logic [3:0] reg_rd_addr, reg_rn_addr, reg_rm_addr;
    logic [31:0] reg_rd_data, reg_rn_data, reg_rm_data;
    logic reg_rd_we;
    logic [31:0] reg_rd_write_data;
    logic [31:0] reg_pc_out, reg_pc_in;
    logic reg_pc_we;
    processor_mode_t current_mode, target_mode;
    logic mode_change;
    
    // CPSR (Current Program Status Register)
    logic [31:0] cpsr_out, cpsr_in;
    logic cpsr_we;
    logic [31:0] spsr_out, spsr_in;
    logic spsr_we;
    
    // ALU signals
    logic [31:0] alu_a, alu_b, alu_result;
    logic alu_carry_out, alu_overflow;
    logic alu_zero, alu_negative;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    logic [31:0] actual_rd_value;
    
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
    
    // Instantiate register file
    arm7tdmi_regfile u_regfile (
        .clk            (clk),
        .rst_n          (rst_n),
        .rn_addr        (reg_rn_addr),
        .rm_addr        (reg_rm_addr),
        .rn_data        (reg_rn_data),
        .rm_data        (reg_rm_data),
        .rd_addr        (reg_rd_addr),
        .rd_data        (reg_rd_write_data),
        .rd_we          (reg_rd_we),
        .pc_out         (reg_pc_out),
        .pc_in          (reg_pc_in),
        .pc_we          (reg_pc_we),
        .current_mode   (current_mode),
        .target_mode    (target_mode),
        .mode_change    (mode_change),
        .cpsr_out       (cpsr_out),
        .cpsr_in        (cpsr_in),
        .cpsr_we        (cpsr_we),
        .spsr_out       (spsr_out),
        .spsr_in        (spsr_in),
        .spsr_we        (spsr_we)
    );
    
    // ALU for execution
    always_comb begin
        logic [32:0] temp_add, temp_sub;
        
        case (decode_alu_op)
            ALU_AND: {alu_carry_out, alu_result} = {1'b0, alu_a & alu_b};
            ALU_EOR: {alu_carry_out, alu_result} = {1'b0, alu_a ^ alu_b};
            ALU_SUB: begin
                temp_sub = {1'b0, alu_a} + {1'b0, ~alu_b} + 1;  // Two's complement subtraction
                alu_carry_out = temp_sub[32];
                alu_result = temp_sub[31:0];
            end
            ALU_RSB: begin  
                temp_sub = {1'b0, alu_b} + {1'b0, ~alu_a} + 1;  // Two's complement subtraction
                alu_carry_out = temp_sub[32];
                alu_result = temp_sub[31:0];
            end
            ALU_ADD: begin
                temp_add = {1'b0, alu_a} + {1'b0, alu_b};
                alu_carry_out = temp_add[32];
                alu_result = temp_add[31:0];
            end
            ALU_ADC: begin
                temp_add = {1'b0, alu_a} + {1'b0, alu_b} + {32'b0, cpsr_out[29]};
                alu_carry_out = temp_add[32];
                alu_result = temp_add[31:0];
            end
            ALU_SBC: {alu_carry_out, alu_result} = alu_a - alu_b - !cpsr_out[29]; // !C flag
            ALU_RSC: {alu_carry_out, alu_result} = alu_b - alu_a - !cpsr_out[29]; // !C flag
            ALU_TST: {alu_carry_out, alu_result} = {1'b0, alu_a & alu_b};  // Test
            ALU_TEQ: {alu_carry_out, alu_result} = {1'b0, alu_a ^ alu_b};  // Test equivalence
            ALU_CMP: begin
                temp_sub = {1'b0, alu_a} + {1'b0, ~alu_b} + 1;  // Two's complement subtraction
                alu_carry_out = temp_sub[32];
                alu_result = temp_sub[31:0];
            end
            ALU_CMN: begin
                temp_add = {1'b0, alu_a} + {1'b0, alu_b};
                alu_carry_out = temp_add[32];
                alu_result = temp_add[31:0];
            end
            ALU_ORR: {alu_carry_out, alu_result} = {1'b0, alu_a | alu_b};
            ALU_MOV: {alu_carry_out, alu_result} = {1'b0, alu_b};
            ALU_BIC: {alu_carry_out, alu_result} = {1'b0, alu_a & ~alu_b};
            ALU_MVN: {alu_carry_out, alu_result} = {1'b0, ~alu_b};
            default: {alu_carry_out, alu_result} = {1'b0, 32'h0};
        endcase
        
        alu_zero = (alu_result == 32'h0);
        alu_negative = alu_result[31];
        alu_overflow = 1'b0; // Simplified for now
    end
    
    // Manual control signals for testing
    logic manual_control = 0;
    logic [3:0] manual_rd_addr;
    logic manual_rd_we;
    logic [31:0] manual_rd_data;
    logic manual_cpsr_we;
    logic [31:0] manual_cpsr_data;
    
    // Register file control logic
    always_comb begin
        // Address assignments for reading - can be overridden by manual control
        if (manual_control) begin
            // Manual control can override read addresses if needed
            reg_rm_addr = decode_rm;  // Keep rm from decode
            // reg_rn_addr will be set manually in the task
        end else begin
            reg_rn_addr = decode_rn;
            reg_rm_addr = decode_rm;
        end
        
        // ALU operands
        alu_a = reg_rn_data;
        if (decode_imm_en) begin
            alu_b = {20'b0, decode_immediate};
        end else begin
            alu_b = reg_rm_data;
        end
        
        // Write control - either manual or automatic
        if (manual_control) begin
            reg_rd_addr = manual_rd_addr;
            reg_rd_we = manual_rd_we;
            reg_rd_write_data = manual_rd_data;
            cpsr_we = manual_cpsr_we;
            cpsr_in = manual_cpsr_data;
        end else begin
            // Automatic execution control
            reg_rd_addr = decode_rd;
            // Don't write to registers for comparison operations (CMP, CMN, TST, TEQ)
            reg_rd_we = (decode_instr_type == INSTR_DATA_PROC) && !decode_is_branch && 
                       !(decode_alu_op == ALU_CMP || decode_alu_op == ALU_CMN || 
                         decode_alu_op == ALU_TST || decode_alu_op == ALU_TEQ);
            reg_rd_write_data = alu_result;
            cpsr_we = decode_set_flags && (decode_instr_type == INSTR_DATA_PROC);
            cpsr_in = {alu_negative, alu_zero, alu_carry_out, alu_overflow, cpsr_out[27:0]};
        end
        
        // Mode control (simplified for testing)
        current_mode = MODE_USER;
        target_mode = MODE_USER;
        mode_change = 1'b0;
        reg_pc_in = reg_pc_out;
        reg_pc_we = 1'b0;
        spsr_in = 32'h0;
        spsr_we = 1'b0;
    end
    
    // Test task for register and flag validation
    task test_regfile_operation(input [31:0] instr, input string name,
                               input [31:0] reg_rn_init, input [31:0] reg_rm_init,
                               input [31:0] expected_rd_result,
                               input expected_n, input expected_z, input expected_c, input expected_v);
        
        logic [31:0] initial_cpsr;
        logic [31:0] reg_snapshot [0:15];
        int i;
        
        tests_run++;
        
        // Take snapshot of all registers before operation
        for (i = 0; i < 16; i++) begin
            @(posedge clk);
            reg_rn_addr = i[3:0];
            @(posedge clk);
            reg_snapshot[i] = reg_rn_data;
        end
        initial_cpsr = cpsr_out;
        
        $display("Testing: %s", name);
        
        // Set up instruction
        instruction = instr;
        @(posedge clk);
        
        // Initialize source registers manually
        manual_control = 1'b1;  // Enable manual control
        manual_cpsr_we = 1'b0;
        
        manual_rd_addr = decode_rn;
        manual_rd_we = 1'b1;
        manual_rd_data = reg_rn_init;
        @(posedge clk);
        
        manual_rd_addr = decode_rm;
        manual_rd_data = reg_rm_init;
        @(posedge clk);
        
        // Disable manual register write and switch to automatic control
        manual_rd_we = 1'b0;
        manual_control = 1'b0;  // Switch to automatic execution control
        @(posedge clk);
        
        // Wait for combinational logic to settle and execute
        #1;
        @(posedge clk);
        
        // Check results - use manual control to read the destination register
        manual_control = 1'b1;
        manual_rd_we = 1'b0;
        manual_cpsr_we = 1'b0;
        @(posedge clk);
        
        $display("  Instruction: 0x%08x", instr);
        $display("  Decode: rd=%d, rn=%d, rm=%d, set_flags=%b", decode_rd, decode_rn, decode_rm, decode_set_flags);
        $display("  ALU: a=0x%08x, b=0x%08x, result=0x%08x", alu_a, alu_b, alu_result);
        $display("  Expected: rd=0x%08x, N=%b, Z=%b, C=%b, V=%b", expected_rd_result, expected_n, expected_z, expected_c, expected_v);
        
        // Read the destination register by temporarily changing the read address
        reg_rn_addr = decode_rd;  // Point to destination register
        #1;  // Let combinational logic settle
        actual_rd_value = reg_rn_data;
        
        $display("  Got:      rd=0x%08x, N=%b, Z=%b, C=%b, V=%b", actual_rd_value, cpsr_out[31], cpsr_out[30], cpsr_out[29], cpsr_out[28]);
        
        // Validate register result
        if (actual_rd_value == expected_rd_result && 
            (!decode_set_flags || (cpsr_out[31] == expected_n && cpsr_out[30] == expected_z && 
                                  cpsr_out[29] == expected_c && cpsr_out[28] == expected_v))) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        
        // Reset manual control for next test
        manual_control = 1'b0;
        $display("");
    endtask
    
    initial begin
        $dumpfile("regfile_flag_test_tb.vcd");
        $dumpvars(0, regfile_flag_test_tb);
        
        // Initialize
        manual_control = 1'b0;
        manual_rd_we = 1'b0;
        manual_cpsr_we = 1'b0;
        spsr_we = 1'b0;
        reg_pc_we = 1'b0;
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Register File and Flag Validation Test ===");
        
        // Test register writeback (without flag setting)
        $display("=== Testing Register Writeback ===");
        test_regfile_operation(32'hE1A00001, "MOV R0, R1", 32'h00, 32'h12345678, 32'h12345678, 1'b0, 1'b0, 1'b0, 1'b0);
        test_regfile_operation(32'hE0821003, "ADD R1, R2, R3", 32'h100, 32'h200, 32'h300, 1'b0, 1'b0, 1'b0, 1'b0);
        test_regfile_operation(32'hE0432001, "SUB R2, R3, R1", 32'h500, 32'h200, 32'h300, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // Test flag setting operations (S bit set)
        $display("=== Testing Flag Setting ===");
        test_regfile_operation(32'hE1B00001, "MOVS R0, R1", 32'h00, 32'h00000000, 32'h00000000, 1'b0, 1'b1, 1'b0, 1'b0); // Zero flag
        test_regfile_operation(32'hE1B00001, "MOVS R0, R1", 32'h00, 32'h80000000, 32'h80000000, 1'b1, 1'b0, 1'b0, 1'b0); // Negative flag
        test_regfile_operation(32'hE0921003, "ADDS R1, R2, R3", 32'hFFFFFFFF, 32'h00000001, 32'h00000000, 1'b0, 1'b1, 1'b1, 1'b0); // Carry flag
        
        // Test comparison operations (always set flags)
        $display("=== Testing Comparison Operations ===");
        test_regfile_operation(32'hE1520003, "CMP R2, R3", 32'h100, 32'h100, 32'h80000000, 1'b0, 1'b1, 1'b1, 1'b0); // Equal comparison - R0 keeps previous value
        test_regfile_operation(32'hE1520003, "CMP R2, R3", 32'h200, 32'h100, 32'h80000000, 1'b0, 1'b0, 1'b1, 1'b0); // Greater comparison - R0 keeps previous value  
        test_regfile_operation(32'hE1520003, "CMP R2, R3", 32'h100, 32'h200, 32'h80000000, 1'b1, 1'b0, 1'b0, 1'b0); // Less comparison - R0 keeps previous value
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL REGISTER FILE AND FLAG TESTS PASSED!");
        end else begin
            $display("❌ SOME REGISTER FILE AND FLAG TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule