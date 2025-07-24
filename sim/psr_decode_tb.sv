// PSR Transfer Decode Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module psr_decode_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Decode module signals
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h0;
    logic        instr_valid = 1'b1;
    logic        thumb_mode = 1'b0;
    
    // Decode outputs
    condition_t     condition;
    instr_type_t    instr_type;
    alu_op_t        alu_op;
    logic [3:0]     rd, rn, rm;
    logic [11:0]    immediate;
    logic           imm_en, set_flags;
    shift_type_t    shift_type;
    logic [4:0]     shift_amount;
    logic           is_branch;
    logic [23:0]    branch_offset;
    logic           branch_link;
    logic           is_memory, mem_load, mem_byte;
    logic           mem_pre, mem_up, mem_writeback;
    logic           psr_to_reg, psr_spsr, psr_immediate;
    logic [31:0]    pc_out;
    logic           decode_valid;
    logic           stall = 1'b0, flush = 1'b0;
    
    // Instantiate decode module
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
        .pc_out         (pc_out),
        .decode_valid   (decode_valid),
        .stall          (stall),
        .flush          (flush)
    );
    
    initial begin
        $dumpfile("psr_decode_tb.vcd");
        $dumpvars(0, psr_decode_tb);
        
        // Reset
        rst_n = 0;
        instruction = 32'h0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("=== PSR Transfer Decode Test ===");
        
        // Test 1: MRS R0, CPSR
        instruction = 32'hE10F0000;  // MRS R0, CPSR
        @(posedge clk);
        @(posedge clk);
        $display("Test 1 - MRS R0, CPSR (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  psr_to_reg = %b, psr_spsr = %b, psr_immediate = %b", psr_to_reg, psr_spsr, psr_immediate);
        $display("  rd = %d", rd);
        if (instr_type == INSTR_PSR_TRANSFER && psr_to_reg && !psr_spsr && !psr_immediate) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 2: MRS R1, SPSR  
        instruction = 32'hE14F1000;  // MRS R1, SPSR
        @(posedge clk);
        @(posedge clk);
        $display("Test 2 - MRS R1, SPSR (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  psr_to_reg = %b, psr_spsr = %b, psr_immediate = %b", psr_to_reg, psr_spsr, psr_immediate);
        $display("  rd = %d", rd);
        if (instr_type == INSTR_PSR_TRANSFER && psr_to_reg && psr_spsr && !psr_immediate) begin
            $display("  PASS");  
        end else begin
            $display("  FAIL");
        end
        
        // Test 3: MSR CPSR, R2
        instruction = 32'hE121F002;  // MSR CPSR, R2
        @(posedge clk);
        @(posedge clk);
        $display("Test 3 - MSR CPSR, R2 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  psr_to_reg = %b, psr_spsr = %b, psr_immediate = %b", psr_to_reg, psr_spsr, psr_immediate);
        $display("  rm = %d", rm);
        if (instr_type == INSTR_PSR_TRANSFER && !psr_to_reg && !psr_spsr && !psr_immediate) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 4: MSR SPSR, R3
        instruction = 32'hE161F003;  // MSR SPSR, R3  
        @(posedge clk);
        @(posedge clk);
        $display("Test 4 - MSR SPSR, R3 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  psr_to_reg = %b, psr_spsr = %b, psr_immediate = %b", psr_to_reg, psr_spsr, psr_immediate);
        $display("  rm = %d", rm);
        if (instr_type == INSTR_PSR_TRANSFER && !psr_to_reg && psr_spsr && !psr_immediate) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 5: MSR CPSR_flg, #0xF0000000  
        instruction = 32'hE32FF00F;  // MSR CPSR_flg, #0xF0000000
        @(posedge clk);
        @(posedge clk);
        $display("Test 5 - MSR CPSR_flg, #0xF0000000 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        $display("  psr_to_reg = %b, psr_spsr = %b, psr_immediate = %b", psr_to_reg, psr_spsr, psr_immediate);
        $display("  immediate = 0x%03h", immediate);
        if (instr_type == INSTR_PSR_TRANSFER && !psr_to_reg && !psr_spsr && psr_immediate) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 6: Regular data processing instruction (should not be PSR transfer)
        instruction = 32'hE0800001;  // ADD R0, R0, R1
        @(posedge clk);
        @(posedge clk);
        $display("Test 6 - ADD R0, R0, R1 (0x%08h):", instruction);
        $display("  instr_type = %d", instr_type);
        if (instr_type == INSTR_DATA_PROC) begin
            $display("  PASS - Correctly identified as data processing");
        end else begin
            $display("  FAIL - Should be data processing, got %d", instr_type);
        end
        
        $display("=== PSR Decode Test Complete ===");
        $finish;
    end
    
endmodule