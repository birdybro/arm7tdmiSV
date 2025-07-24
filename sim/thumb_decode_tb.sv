// Thumb Decode Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module thumb_decode_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Decode stage signals
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h00000000;
    logic        instr_valid = 1'b1;
    logic        thumb_mode = 1'b1;  // Enable Thumb mode
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
    
    // Thumb-specific outputs
    thumb_instr_type_t thumb_instr_type;
    logic [2:0]  thumb_rd, thumb_rs, thumb_rn;
    logic [7:0]  thumb_imm8, thumb_offset8;
    logic [4:0]  thumb_imm5;
    logic [10:0] thumb_offset11;
    
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
        .thumb_instr_type (thumb_instr_type),
        .thumb_rd       (thumb_rd),
        .thumb_rs       (thumb_rs),
        .thumb_rn       (thumb_rn),
        .thumb_imm8     (thumb_imm8),
        .thumb_imm5     (thumb_imm5),
        .thumb_offset11 (thumb_offset11),
        .thumb_offset8  (thumb_offset8),
        .pc_out         (pc_out),
        .decode_valid   (decode_valid),
        .stall          (stall),
        .flush          (flush)
    );
    
    initial begin
        $dumpfile("thumb_decode_tb.vcd");
        $dumpvars(0, thumb_decode_tb);
        
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("=== Thumb Decode Test ===");
        
        // Test 1: LSL R0, R1, #5 (Shift by immediate - 0x0148)
        instruction = 32'h00000148;  // Only use lower 16 bits for Thumb
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 1 - LSL R0, R1, #5 (0x%04h):", instruction[15:0]);
        $display("  instr_type = %d", instr_type);
        $display("  thumb_instr_type = %d", thumb_instr_type);
        $display("  thumb_rd = %d, thumb_rs = %d", thumb_rd, thumb_rs);
        $display("  thumb_imm5 = %d", thumb_imm5);
        if (instr_type == INSTR_DATA_PROC && thumb_instr_type == THUMB_SHIFT && 
            thumb_rd == 0 && thumb_rs == 1 && thumb_imm5 == 5) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 2: ADD R2, #100 (MOV/CMP/ADD/SUB immediate - 0x3264)
        instruction = 32'h00003264;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 2 - ADD R2, #100 (0x%04h):", instruction[15:0]);
        $display("  instr_type = %d", instr_type);
        $display("  thumb_instr_type = %d", thumb_instr_type);
        $display("  thumb_rd = %d, thumb_imm8 = %d", thumb_rd, thumb_imm8);
        if (instr_type == INSTR_DATA_PROC && thumb_instr_type == THUMB_CMP_MOV_IMM && 
            thumb_rd == 2 && thumb_imm8 == 100) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 3: ADD R0, R1 (ALU register operations - 0x4408 = ADD R0, R1)  
        instruction = 32'h00004408;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 3 - ADD R0, R1 (0x%04h):", instruction[15:0]);
        $display("  instr_type = %d", instr_type);
        $display("  thumb_instr_type = %d", thumb_instr_type);
        $display("  thumb_rd = %d, thumb_rs = %d", thumb_rd, thumb_rs);
        if (instr_type == INSTR_DATA_PROC && thumb_instr_type == THUMB_ALU_HI && 
            thumb_rd == 0 && thumb_rs == 1) begin
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 4: B #100 (Branch unconditional - 0xE832)  
        instruction = 32'h0000E832;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 4 - B #100 (0x%04h):", instruction[15:0]);
        $display("  instr_type = %d", instr_type);
        $display("  thumb_instr_type = %d", thumb_instr_type);
        $display("  thumb_offset11 = %d", thumb_offset11);
        if (instr_type == INSTR_BRANCH && thumb_instr_type == THUMB_BRANCH_UNCOND && 
            thumb_offset11 == 50) begin  // 0x32 = 50 decimal
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        // Test 5: LDR R3, [R4, #20] (Load immediate offset - 0x6A63)
        instruction = 32'h00006A63;
        @(posedge clk);
        @(posedge clk);  // Wait for decode
        $display("Test 5 - LDR R3, [R4, #20] (0x%04h):", instruction[15:0]);
        $display("  instr_type = %d", instr_type);
        $display("  thumb_instr_type = %d", thumb_instr_type);
        $display("  thumb_rd = %d, thumb_rs = %d, thumb_imm5 = %d", thumb_rd, thumb_rs, thumb_imm5);
        if (instr_type == INSTR_SINGLE_DT && thumb_instr_type == THUMB_LOAD_STORE && 
            thumb_rd == 3 && thumb_rs == 4) begin  // Register offset load/store
            $display("  PASS");
        end else begin
            $display("  FAIL");
        end
        
        $display("=== Thumb Decode Test Complete ===");
        $finish;
    end
    
endmodule