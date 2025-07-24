// ARM Shifter Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module shifter_test_tb;
    
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
    
    // Shifter test signals
    logic [31:0] shift_data_in = 32'h80000001;
    logic [31:0] shift_data_out;
    logic shift_carry_out;
    logic shift_carry_in = 1'b0;
    
    // Instantiate shifter
    arm7tdmi_shifter u_shifter (
        .data_in    (shift_data_in),
        .shift_type (decode_shift_type),
        .shift_amount (decode_shift_amount),
        .carry_in   (shift_carry_in),
        .data_out   (shift_data_out),
        .carry_out  (shift_carry_out)
    );
    
    initial begin
        $dumpfile("shifter_test_tb.vcd");
        $dumpvars(0, shifter_test_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM Shifter Test ===");
        
        // Test 1: LSL immediate - MOV R0, R1, LSL #4 (E1A00201)
        instruction = 32'hE1A00201;
        @(posedge clk);
        $display("Test 1 - MOV R0, R1, LSL #4:");
        $display("  Decode: instr_type=%d, shift_type=%d, shift_amount=%d, shift_reg=%d", 
                 decode_instr_type, decode_shift_type, decode_shift_amount, decode_shift_reg);
        $display("  Shifter: 0x%08h << %d = 0x%08h, carry=%d", 
                 shift_data_in, decode_shift_amount, shift_data_out, shift_carry_out);
        
        // Test 2: LSR immediate - MOV R0, R1, LSR #4 (E1A00221)  
        instruction = 32'hE1A00221;
        @(posedge clk);
        $display("Test 2 - MOV R0, R1, LSR #4:");
        $display("  Decode: instr_type=%d, shift_type=%d, shift_amount=%d, shift_reg=%d", 
                 decode_instr_type, decode_shift_type, decode_shift_amount, decode_shift_reg);
        $display("  Shifter: 0x%08h >> %d = 0x%08h, carry=%d", 
                 shift_data_in, decode_shift_amount, shift_data_out, shift_carry_out);
        
        // Test 3: ASR immediate - MOV R0, R1, ASR #4 (E1A00241)
        instruction = 32'hE1A00241;
        @(posedge clk);
        $display("Test 3 - MOV R0, R1, ASR #4:");
        $display("  Decode: instr_type=%d, shift_type=%d, shift_amount=%d, shift_reg=%d", 
                 decode_instr_type, decode_shift_type, decode_shift_amount, decode_shift_reg);
        $display("  Shifter: 0x%08h ASR %d = 0x%08h, carry=%d", 
                 shift_data_in, decode_shift_amount, shift_data_out, shift_carry_out);
        
        // Test 4: ROR immediate - MOV R0, R1, ROR #4 (E1A00261)
        instruction = 32'hE1A00261;
        @(posedge clk);
        $display("Test 4 - MOV R0, R1, ROR #4:");
        $display("  Decode: instr_type=%d, shift_type=%d, shift_amount=%d, shift_reg=%d", 
                 decode_instr_type, decode_shift_type, decode_shift_amount, decode_shift_reg);
        $display("  Shifter: 0x%08h ROR %d = 0x%08h, carry=%d", 
                 shift_data_in, decode_shift_amount, shift_data_out, shift_carry_out);
        
        // Test 5: RRX - MOV R0, R1, RRX (E1A00061)
        instruction = 32'hE1A00061;
        shift_carry_in = 1'b1;  // Set carry for RRX test
        @(posedge clk);
        $display("Test 5 - MOV R0, R1, RRX (carry_in=1):");
        $display("  Decode: instr_type=%d, shift_type=%d, shift_amount=%d, shift_reg=%d", 
                 decode_instr_type, decode_shift_type, decode_shift_amount, decode_shift_reg);
        $display("  Shifter: 0x%08h RRX = 0x%08h, carry=%d", 
                 shift_data_in, shift_data_out, shift_carry_out);
        
        // Test 6: Register-controlled shift - MOV R0, R1, LSL R2 (E1A00211)
        instruction = 32'hE1A00211;
        @(posedge clk);
        $display("Test 6 - MOV R0, R1, LSL R2:");
        $display("  Decode: instr_type=%d, shift_type=%d, shift_amount=%d, shift_reg=%d, shift_rs=%d", 
                 decode_instr_type, decode_shift_type, decode_shift_amount, decode_shift_reg, decode_shift_rs);
        
        $display("=== Shifter Test Complete ===");
        $finish;
    end
    
endmodule