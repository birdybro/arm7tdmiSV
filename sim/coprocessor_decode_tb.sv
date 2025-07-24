// Coprocessor Decode Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module coprocessor_decode_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Decode stage signals
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h00000000;
    logic        instr_valid = 1'b1;
    logic        thumb_mode = 1'b0;
    logic        stall = 1'b0;
    logic        flush = 1'b0;
    
    // Decoded outputs
    condition_t  condition;
    instr_type_t instr_type;
    alu_op_t     alu_op;
    logic [3:0]  rd, rn, rm;
    logic [11:0] immediate;
    logic        imm_en, set_flags;
    shift_type_t shift_type;
    logic [4:0]  shift_amount;
    logic        is_branch, branch_link;
    logic [23:0] branch_offset;
    logic        is_memory, mem_load, mem_byte;
    logic        mem_pre, mem_up, mem_writeback;
    logic        psr_to_reg, psr_spsr, psr_immediate;
    cp_op_t      cp_op;
    logic [3:0]  cp_num, cp_rd, cp_rn;
    logic [2:0]  cp_opcode1, cp_opcode2;
    logic        cp_load;
    logic [31:0] pc_out;
    logic        decode_valid;
    
    // DUT instantiation
    arm7tdmi_decode u_decode (
        .clk            (clk),
        .rst_n          (rst_n),
        .instruction    (instruction),
        .pc_in          (pc_in),
        .instr_valid    (instr_valid),
        .thumb_mode     (thumb_mode),
        .condition      (condition),
        .instr_type     (instr_type),
        .alu_op         (alu_op),
        .rd             (rd),
        .rn             (rn),
        .rm             (rm),
        .immediate      (immediate),
        .imm_en         (imm_en),
        .set_flags      (set_flags),
        .shift_type     (shift_type),
        .shift_amount   (shift_amount),
        .is_branch      (is_branch),
        .branch_offset  (branch_offset),
        .branch_link    (branch_link),
        .is_memory      (is_memory),
        .mem_load       (mem_load),
        .mem_byte       (mem_byte),
        .mem_pre        (mem_pre),
        .mem_up         (mem_up),
        .mem_writeback  (mem_writeback),
        .psr_to_reg     (psr_to_reg),
        .psr_spsr       (psr_spsr),
        .psr_immediate  (psr_immediate),
        .cp_op          (cp_op),
        .cp_num         (cp_num),
        .cp_rd          (cp_rd),
        .cp_rn          (cp_rn),
        .cp_opcode1     (cp_opcode1),
        .cp_opcode2     (cp_opcode2),
        .cp_load        (cp_load),
        .pc_out         (pc_out),
        .decode_valid   (decode_valid),
        .stall          (stall),
        .flush          (flush)
    );
    
    initial begin
        $dumpfile("coprocessor_decode_tb.vcd");
        $dumpvars(0, coprocessor_decode_tb);
        
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("=== Coprocessor Decode Test ===");
        
        // Test 1: MRC p15, 0, R0, c0, c0, 0 (Read CP15 ID register)
        instruction = 32'hEE100F10;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 1 - MRC p15, 0, R0, c0, c0, 0 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  cp_op = %d, cp_num = %d", cp_op, cp_num);
        $display("  cp_rd = %d, cp_rn = %d", cp_rd, cp_rn);
        $display("  cp_opcode1 = %d, cp_opcode2 = %d", cp_opcode1, cp_opcode2);
        if (instr_type == INSTR_COPROCESSOR && cp_op == CP_MRC && cp_num == 15 && 
            cp_rd == 0 && cp_rn == 0 && cp_opcode1 == 0 && cp_opcode2 == 0) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 2: MCR p15, 0, R2, c1, c0, 0 (Write CP15 Control register)
        instruction = 32'hEE012F10;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 2 - MCR p15, 0, R2, c1, c0, 0 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  cp_op = %d, cp_num = %d", cp_op, cp_num);
        $display("  cp_rd = %d, cp_rn = %d", cp_rd, cp_rn);
        $display("  cp_opcode1 = %d, cp_opcode2 = %d", cp_opcode1, cp_opcode2);
        if (instr_type == INSTR_COPROCESSOR && cp_op == CP_MCR && cp_num == 15 && 
            cp_rd == 2 && cp_rn == 1 && cp_opcode1 == 0 && cp_opcode2 == 0) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 3: LDC p10, c5, [R1, #16] (Load coprocessor)
        instruction = 32'hED915A04;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 3 - LDC p10, c5, [R1, #16] (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  cp_op = %d, cp_num = %d", cp_op, cp_num);
        $display("  cp_rd = %d, cp_load = %b", cp_rd, cp_load);
        $display("  cp_opcode1 = %d", cp_opcode1);
        if (instr_type == INSTR_COPROCESSOR && cp_op == CP_LDC && cp_num == 10 && 
            cp_rd == 5 && cp_load == 1) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 4: STC p10, c4, [R2, #-8] (Store coprocessor)
        instruction = 32'hED024AFE;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 4 - STC p10, c4, [R2, #-8] (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  cp_op = %d, cp_num = %d", cp_op, cp_num);
        $display("  cp_rd = %d, cp_load = %b", cp_rd, cp_load);
        $display("  cp_opcode1 = %d", cp_opcode1);
        if (instr_type == INSTR_COPROCESSOR && cp_op == CP_STC && cp_num == 10 && 
            cp_rd == 4 && cp_load == 0) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 5: CDP p10, 2, c4, c5, c6, 3 (Coprocessor data processing)  
        instruction = 32'hEE464A66;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 5 - CDP p10, 2, c4, c5, c6, 3 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  cp_op = %d, cp_num = %d", cp_op, cp_num);
        $display("  cp_rd = %d, cp_rn = %d", cp_rd, cp_rn);
        $display("  cp_opcode1 = %d, cp_opcode2 = %d", cp_opcode1, cp_opcode2);
        if (instr_type == INSTR_COPROCESSOR && cp_op == CP_CDP && cp_num == 10 && 
            cp_rd == 4 && cp_rn == 6 && cp_opcode1 == 2 && cp_opcode2 == 3) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 6: ADD R0, R0, R1 (Verify non-coprocessor instruction still works)
        instruction = 32'hE0800001;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 6 - ADD R0, R0, R1 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        if (instr_type == INSTR_DATA_PROC) begin
            $display("  PASS - Correctly identified as data processing");
        end else begin
            $display("  FAIL - Should be data processing");
        end
        
        $display("=== Coprocessor Decode Test Complete ===");
        $finish;
    end
    
endmodule