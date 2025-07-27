// Debug decode test for specific failing instructions
`timescale 1ns/1ps

// import arm7tdmi_pkg::*;

module debug_decode_tb;
    
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;
    
    // Test signals for decode module
    logic [31:0] instruction;
    logic [31:0] pc_in = 32'h00000000;
    logic instr_valid = 1;
    logic stall = 0;
    logic flush = 0;
    logic thumb_mode = 0;
    
    // Decode outputs
    logic [3:0] decode_condition;
    logic [3:0] decode_instr_type; 
    logic [3:0] decode_alu_op;
    logic [3:0] decode_rd, decode_rn, decode_rm;
    logic [11:0] decode_immediate;
    logic decode_imm_en, decode_set_flags;
    logic [1:0] decode_shift_type;
    logic [4:0] decode_shift_amount;
    logic decode_shift_reg;
    logic [3:0] decode_shift_rs;
    logic decode_is_branch, decode_branch_link;
    logic [23:0] decode_branch_offset;
    logic decode_is_memory, decode_mem_load, decode_mem_byte;
    logic decode_mem_pre, decode_mem_up, decode_mem_writeback;
    logic decode_psr_to_reg, decode_psr_spsr, decode_psr_immediate;
    logic [2:0] decode_cp_op;
    logic [3:0] decode_cp_num, decode_cp_rd, decode_cp_rn;
    logic [2:0] decode_cp_opcode1, decode_cp_opcode2;
    logic decode_cp_load;
    logic [4:0] decode_thumb_instr_type;
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
    
    task test_instruction(input [31:0] instr, input string name, input logic [3:0] expected_type);
        instruction = instr;
        @(posedge clk);
        $display("Instruction: %s (0x%08x = %b)", name, instr, instr);
        $display("  Bits [27:25] = %b (%d)", instr[27:25], instr[27:25]);
        $display("  Bits [24:21] = %b (%d)", instr[24:21], instr[24:21]);
        $display("  Bits [7:4]   = %b (%d)", instr[7:4], instr[7:4]);
        $display("  Expected type: %d, Got type: %d", expected_type, decode_instr_type);
        if (decode_instr_type == expected_type) begin
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("debug_decode_tb.vcd");
        $dumpvars(0, debug_decode_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== Debug Decode Test ===");
        
        // Test BX instruction
        thumb_mode = 0;
        $display("=== ARM BX Instruction Debug ===");
        instruction = 32'hE12FFF10;
        @(posedge clk);
        $display("Instruction: BX R0 (0x%08x = %b)", instruction, instruction);
        $display("  Bits [31:28] = %b (%d) [condition]", instruction[31:28], instruction[31:28]);
        $display("  Bits [27:25] = %b (%d)", instruction[27:25], instruction[27:25]);
        $display("  Bits [27:4] = %b", instruction[27:4]);
        $display("  Expected pattern: %b", 24'b000100101111111111110001);
        $display("  Pattern match: %s", (instruction[27:4] == 24'b000100101111111111110001) ? "YES" : "NO");
        $display("  Expected type: 4 (INSTR_BRANCH_EX), Got type: %d", decode_instr_type);
        if (decode_instr_type == 4) begin
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Test a few BX variants
        $display("=== BX Instruction Variants ===");
        
        // BX R1
        instruction = 32'hE12FFF11;
        @(posedge clk);
        $display("BX R1 (0x%08x): Expected type 4, Got type %d", instruction, decode_instr_type);
        
        // BX R14 (LR)
        instruction = 32'hE12FFF1E;
        @(posedge clk);
        $display("BX LR (0x%08x): Expected type 4, Got type %d", instruction, decode_instr_type);
        
        $display("=== Debug Test Complete ===");
        $finish;
    end
    
endmodule