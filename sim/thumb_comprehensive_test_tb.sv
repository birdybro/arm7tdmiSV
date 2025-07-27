// Comprehensive Thumb instruction test for ARM7TDMI
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module thumb_comprehensive_test_tb;
    
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
    logic thumb_mode = 1;  // Enable Thumb mode
    
    // Decode outputs
    condition_t decode_condition;
    instr_type_t decode_instr_type;
    logic decode_valid;
    
    // Thumb-specific outputs
    thumb_instr_type_t decode_thumb_instr_type;
    logic [2:0] decode_thumb_rd;
    logic [2:0] decode_thumb_rs;
    logic [2:0] decode_thumb_rn;
    logic [7:0] decode_thumb_imm8;
    logic [4:0] decode_thumb_imm5;
    logic [10:0] decode_thumb_offset11;
    logic [7:0] decode_thumb_offset8;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    int category_tests[19]; // Track tests per category
    int category_passed[19]; // Track passes per category
    
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
        .decode_valid   (decode_valid),
        
        .thumb_instr_type (decode_thumb_instr_type),
        .thumb_rd       (decode_thumb_rd),
        .thumb_rs       (decode_thumb_rs),
        .thumb_rn       (decode_thumb_rn),
        .thumb_imm8     (decode_thumb_imm8),
        .thumb_imm5     (decode_thumb_imm5),
        .thumb_offset11 (decode_thumb_offset11),
        .thumb_offset8  (decode_thumb_offset8),
        
        // Unused outputs
        .alu_op         (),
        .rd             (),
        .rn             (),
        .rm             (),
        .immediate      (),
        .imm_en         (),
        .set_flags      (),
        .is_memory      (),
        .mem_load       (),
        .mem_byte       (),
        .mem_pre        (),
        .mem_up         (),
        .mem_writeback  (),
        .pc_out         (),
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
        .cp_load        ()
    );
    
    // Helper function to get instruction type name
    function string get_thumb_type_name(thumb_instr_type_t instr_type);
        case (instr_type)
            THUMB_ALU_IMM: return "THUMB_ALU_IMM";
            THUMB_ALU_REG: return "THUMB_ALU_REG";
            THUMB_SHIFT: return "THUMB_SHIFT";
            THUMB_CMP_MOV_IMM: return "THUMB_CMP_MOV_IMM";
            THUMB_ALU_HI: return "THUMB_ALU_HI";
            THUMB_PC_REL_LOAD: return "THUMB_PC_REL_LOAD";
            THUMB_LOAD_STORE: return "THUMB_LOAD_STORE";
            THUMB_LOAD_STORE_IMM: return "THUMB_LOAD_STORE_IMM";
            THUMB_LOAD_STORE_HW: return "THUMB_LOAD_STORE_HW";
            THUMB_SP_REL_LOAD: return "THUMB_SP_REL_LOAD";
            THUMB_GET_REL_ADDR: return "THUMB_GET_REL_ADDR";
            THUMB_ADD_SUB_SP: return "THUMB_ADD_SUB_SP";
            THUMB_PUSH_POP: return "THUMB_PUSH_POP";
            THUMB_LOAD_STORE_MULT: return "THUMB_LOAD_STORE_MULT";
            THUMB_BRANCH_COND: return "THUMB_BRANCH_COND";
            THUMB_BRANCH_UNCOND: return "THUMB_BRANCH_UNCOND";
            THUMB_BL_HIGH: return "THUMB_BL_HIGH";
            THUMB_BL_LOW: return "THUMB_BL_LOW";
            THUMB_SWI: return "THUMB_SWI";
            default: return "UNKNOWN";
        endcase
    endfunction
    
    // Test task for Thumb instructions
    task test_thumb_instruction(input [15:0] instr, input string name, 
                               input thumb_instr_type_t expected_type,
                               input [2:0] expected_rd = 3'b0,
                               input [2:0] expected_rs = 3'b0,
                               input [2:0] expected_rn = 3'b0);
        int category_idx;
        category_idx = expected_type;
        category_tests[category_idx]++;
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%04x", instr);
        $display("  Expected Type: %s (%d)", get_thumb_type_name(expected_type), expected_type);
        
        instruction = {16'h0000, instr}; // Upper 16 bits don't matter in Thumb mode
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decoded Type: %s (%d)", get_thumb_type_name(decode_thumb_instr_type), decode_thumb_instr_type);
        $display("  Fields: rd=%d, rs=%d, rn=%d", decode_thumb_rd, decode_thumb_rs, decode_thumb_rn);
        $display("  Immediates: imm8=0x%02x, imm5=0x%02x", decode_thumb_imm8, decode_thumb_imm5);
        
        // Check results
        test_passed = (decode_thumb_instr_type == expected_type);
        
        if (test_passed) begin
            tests_passed++;
            category_passed[category_idx]++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
            $display("    Expected type: %s, Got: %s", 
                     get_thumb_type_name(expected_type), 
                     get_thumb_type_name(decode_thumb_instr_type));
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("thumb_comprehensive_test_tb.vcd");
        $dumpvars(0, thumb_comprehensive_test_tb);
        
        // Initialize category counters
        for (int i = 0; i < 19; i++) begin
            category_tests[i] = 0;
            category_passed[i] = 0;
        end
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Comprehensive Thumb Instruction Test ===");
        
        $display("\n=== Format 1: Move shifted register ===");
        test_thumb_instruction(16'h0000, "LSL R0, R0, #0", THUMB_SHIFT);
        test_thumb_instruction(16'h0048, "LSL R0, R1, #1", THUMB_SHIFT);
        test_thumb_instruction(16'h0C00, "LSR R0, R0, #32", THUMB_SHIFT);
        test_thumb_instruction(16'h1000, "ASR R0, R0, #32", THUMB_SHIFT);
        
        $display("\n=== Format 2: Add/subtract ===");
        test_thumb_instruction(16'h1800, "ADD R0, R0, R0", THUMB_ALU_IMM);
        test_thumb_instruction(16'h1A00, "SUB R0, R0, R0", THUMB_ALU_IMM);
        test_thumb_instruction(16'h1C00, "ADD R0, R0, #0", THUMB_ALU_IMM);
        test_thumb_instruction(16'h1E00, "SUB R0, R0, #0", THUMB_ALU_IMM);
        
        $display("\n=== Format 3: Move/compare/add/subtract immediate ===");
        test_thumb_instruction(16'h2000, "MOV R0, #0", THUMB_CMP_MOV_IMM);
        test_thumb_instruction(16'h2800, "CMP R0, #0", THUMB_CMP_MOV_IMM);
        test_thumb_instruction(16'h3000, "ADD R0, #0", THUMB_CMP_MOV_IMM);
        test_thumb_instruction(16'h3800, "SUB R0, #0", THUMB_CMP_MOV_IMM);
        
        $display("\n=== Format 4: ALU operations ===");
        test_thumb_instruction(16'h4000, "AND R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4040, "EOR R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4080, "LSL R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h40C0, "LSR R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4100, "ASR R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4140, "ADC R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4180, "SBC R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h41C0, "ROR R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4200, "TST R0, R0", THUMB_ALU_REG); // Missing implementation
        test_thumb_instruction(16'h4240, "NEG R0, R0", THUMB_ALU_REG); // Missing implementation
        test_thumb_instruction(16'h4280, "CMP R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h42C0, "CMN R0, R0", THUMB_ALU_REG); // Missing implementation
        test_thumb_instruction(16'h4300, "ORR R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4340, "MUL R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h4380, "BIC R0, R0", THUMB_ALU_REG);
        test_thumb_instruction(16'h43C0, "MVN R0, R0", THUMB_ALU_REG);
        
        $display("\n=== Format 5: Hi register operations/branch exchange ===");
        test_thumb_instruction(16'h4400, "ADD R0, R8", THUMB_ALU_HI);
        test_thumb_instruction(16'h4500, "CMP R0, R8", THUMB_ALU_HI);
        test_thumb_instruction(16'h4600, "MOV R0, R8", THUMB_ALU_HI);
        test_thumb_instruction(16'h4700, "BX R0", THUMB_ALU_HI); // Branch exchange
        
        $display("\n=== Format 6: PC-relative load ===");
        test_thumb_instruction(16'h4800, "LDR R0, [PC, #0]", THUMB_PC_REL_LOAD);
        test_thumb_instruction(16'h4FFF, "LDR R7, [PC, #1020]", THUMB_PC_REL_LOAD);
        
        $display("\n=== Format 7: Load/store with register offset ===");
        test_thumb_instruction(16'h5000, "STR R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5200, "STRH R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5400, "STRB R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5600, "LDRSB R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5800, "LDR R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5A00, "LDRH R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5C00, "LDRB R0, [R0, R0]", THUMB_LOAD_STORE);
        test_thumb_instruction(16'h5E00, "LDRSH R0, [R0, R0]", THUMB_LOAD_STORE);
        
        $display("\n=== Format 8: Load/store word/byte immediate offset ===");
        test_thumb_instruction(16'h6000, "STR R0, [R0, #0]", THUMB_LOAD_STORE_IMM);
        test_thumb_instruction(16'h6800, "LDR R0, [R0, #0]", THUMB_LOAD_STORE_IMM);
        test_thumb_instruction(16'h7000, "STRB R0, [R0, #0]", THUMB_LOAD_STORE_IMM);
        test_thumb_instruction(16'h7800, "LDRB R0, [R0, #0]", THUMB_LOAD_STORE_IMM);
        
        $display("\n=== Format 9: Load/store halfword ===");
        test_thumb_instruction(16'h8000, "STRH R0, [R0, #0]", THUMB_LOAD_STORE_HW);
        test_thumb_instruction(16'h8800, "LDRH R0, [R0, #0]", THUMB_LOAD_STORE_HW);
        
        $display("\n=== Format 10: SP-relative load/store ===");
        test_thumb_instruction(16'h9000, "STR R0, [SP, #0]", THUMB_SP_REL_LOAD);
        test_thumb_instruction(16'h9800, "LDR R0, [SP, #0]", THUMB_SP_REL_LOAD);
        
        $display("\n=== Format 11: Load address ===");
        test_thumb_instruction(16'hA000, "ADD R0, PC, #0", THUMB_GET_REL_ADDR);
        test_thumb_instruction(16'hA800, "ADD R0, SP, #0", THUMB_GET_REL_ADDR);
        
        $display("\n=== Format 12: Add offset to Stack Pointer ===");
        test_thumb_instruction(16'hB000, "ADD SP, #0", THUMB_ADD_SUB_SP);
        test_thumb_instruction(16'hB080, "SUB SP, #0", THUMB_ADD_SUB_SP);
        
        $display("\n=== Format 13: Push/pop registers ===");
        test_thumb_instruction(16'hB400, "PUSH {}", THUMB_PUSH_POP);
        test_thumb_instruction(16'hB500, "PUSH {LR}", THUMB_PUSH_POP);
        test_thumb_instruction(16'hBC00, "POP {}", THUMB_PUSH_POP);
        test_thumb_instruction(16'hBD00, "POP {PC}", THUMB_PUSH_POP);
        
        $display("\n=== Format 14: Multiple load/store ===");
        test_thumb_instruction(16'hC000, "STMIA R0!, {}", THUMB_LOAD_STORE_MULT);
        test_thumb_instruction(16'hC800, "LDMIA R0!, {}", THUMB_LOAD_STORE_MULT);
        
        $display("\n=== Format 15: Conditional branch ===");
        test_thumb_instruction(16'hD000, "BEQ #0", THUMB_BRANCH_COND);
        test_thumb_instruction(16'hD100, "BNE #0", THUMB_BRANCH_COND);
        test_thumb_instruction(16'hD200, "BCS #0", THUMB_BRANCH_COND);
        test_thumb_instruction(16'hDF00, "SWI #0", THUMB_SWI);
        
        $display("\n=== Format 16: Unconditional branch ===");
        test_thumb_instruction(16'hE000, "B #0", THUMB_BRANCH_UNCOND);
        test_thumb_instruction(16'hE7FF, "B #2046", THUMB_BRANCH_UNCOND);
        
        $display("\n=== Format 17: Long branch with link ===");
        test_thumb_instruction(16'hF000, "BL prefix", THUMB_BL_HIGH);
        test_thumb_instruction(16'hF800, "BL suffix", THUMB_BL_LOW);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Total Tests Run: %d", tests_run);
        $display("Total Tests Passed: %d", tests_passed);
        $display("Overall Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        $display("\n=== Category Breakdown ===");
        $display("THUMB_ALU_IMM: %d/%d (%.1f%%)", 
                category_passed[0], category_tests[0], 
                category_tests[0] > 0 ? (category_passed[0] * 100.0) / category_tests[0] : 0.0);
        $display("THUMB_ALU_REG: %d/%d (%.1f%%)", 
                category_passed[1], category_tests[1],
                category_tests[1] > 0 ? (category_passed[1] * 100.0) / category_tests[1] : 0.0);
        $display("THUMB_SHIFT: %d/%d (%.1f%%)", 
                category_passed[2], category_tests[2],
                category_tests[2] > 0 ? (category_passed[2] * 100.0) / category_tests[2] : 0.0);
        $display("THUMB_CMP_MOV_IMM: %d/%d (%.1f%%)", 
                category_passed[3], category_tests[3],
                category_tests[3] > 0 ? (category_passed[3] * 100.0) / category_tests[3] : 0.0);
        $display("THUMB_ALU_HI: %d/%d (%.1f%%)", 
                category_passed[4], category_tests[4],
                category_tests[4] > 0 ? (category_passed[4] * 100.0) / category_tests[4] : 0.0);
        $display("THUMB_PC_REL_LOAD: %d/%d (%.1f%%)", 
                category_passed[5], category_tests[5],
                category_tests[5] > 0 ? (category_passed[5] * 100.0) / category_tests[5] : 0.0);
        $display("THUMB_LOAD_STORE: %d/%d (%.1f%%)", 
                category_passed[6], category_tests[6],
                category_tests[6] > 0 ? (category_passed[6] * 100.0) / category_tests[6] : 0.0);
        $display("THUMB_LOAD_STORE_IMM: %d/%d (%.1f%%)", 
                category_passed[7], category_tests[7],
                category_tests[7] > 0 ? (category_passed[7] * 100.0) / category_tests[7] : 0.0);
        $display("THUMB_LOAD_STORE_HW: %d/%d (%.1f%%)", 
                category_passed[8], category_tests[8],
                category_tests[8] > 0 ? (category_passed[8] * 100.0) / category_tests[8] : 0.0);
        $display("THUMB_SP_REL_LOAD: %d/%d (%.1f%%)", 
                category_passed[9], category_tests[9],
                category_tests[9] > 0 ? (category_passed[9] * 100.0) / category_tests[9] : 0.0);
        $display("THUMB_GET_REL_ADDR: %d/%d (%.1f%%)", 
                category_passed[10], category_tests[10],
                category_tests[10] > 0 ? (category_passed[10] * 100.0) / category_tests[10] : 0.0);
        $display("THUMB_ADD_SUB_SP: %d/%d (%.1f%%)", 
                category_passed[11], category_tests[11],
                category_tests[11] > 0 ? (category_passed[11] * 100.0) / category_tests[11] : 0.0);
        $display("THUMB_PUSH_POP: %d/%d (%.1f%%)", 
                category_passed[12], category_tests[12],
                category_tests[12] > 0 ? (category_passed[12] * 100.0) / category_tests[12] : 0.0);
        $display("THUMB_LOAD_STORE_MULT: %d/%d (%.1f%%)", 
                category_passed[13], category_tests[13],
                category_tests[13] > 0 ? (category_passed[13] * 100.0) / category_tests[13] : 0.0);
        $display("THUMB_BRANCH_COND: %d/%d (%.1f%%)", 
                category_passed[14], category_tests[14],
                category_tests[14] > 0 ? (category_passed[14] * 100.0) / category_tests[14] : 0.0);
        $display("THUMB_BRANCH_UNCOND: %d/%d (%.1f%%)", 
                category_passed[15], category_tests[15],
                category_tests[15] > 0 ? (category_passed[15] * 100.0) / category_tests[15] : 0.0);
        $display("THUMB_BL_HIGH: %d/%d (%.1f%%)", 
                category_passed[16], category_tests[16],
                category_tests[16] > 0 ? (category_passed[16] * 100.0) / category_tests[16] : 0.0);
        $display("THUMB_BL_LOW: %d/%d (%.1f%%)", 
                category_passed[17], category_tests[17],
                category_tests[17] > 0 ? (category_passed[17] * 100.0) / category_tests[17] : 0.0);
        $display("THUMB_SWI: %d/%d (%.1f%%)", 
                category_passed[18], category_tests[18],
                category_tests[18] > 0 ? (category_passed[18] * 100.0) / category_tests[18] : 0.0);
        
        if (tests_passed == tests_run) begin
            $display("\n✅ ALL THUMB INSTRUCTION TESTS PASSED!");
        end else begin
            $display("\n❌ SOME THUMB INSTRUCTION TESTS FAILED");
            $display("Issues found in instruction decode - need implementation fixes");
        end
        
        $finish;
    end
    
endmodule