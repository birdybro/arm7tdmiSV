// Enhanced coprocessor interface test for ARM7TDMI with CP15 support
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module coprocessor_enhanced_test_tb;
    
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
    
    // Coprocessor decode outputs
    cp_op_t decode_cp_op;
    logic [3:0] decode_cp_num;
    logic [3:0] decode_cp_rd;
    logic [3:0] decode_cp_rn;
    logic [2:0] decode_cp_opcode1;
    logic [2:0] decode_cp_opcode2;
    logic decode_cp_load;
    
    // CP15 register set (System Control Coprocessor)
    logic [31:0] cp15_registers [0:15];
    
    // Register file for ARM registers (simplified)
    logic [31:0] arm_registers [0:15];
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
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
        
        .cp_op          (decode_cp_op),
        .cp_num         (decode_cp_num),
        .cp_rd          (decode_cp_rd),
        .cp_rn          (decode_cp_rn),
        .cp_opcode1     (decode_cp_opcode1),
        .cp_opcode2     (decode_cp_opcode2),
        .cp_load        (decode_cp_load),
        
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
        .thumb_instr_type (),
        .thumb_rd       (),
        .thumb_rs       (),
        .thumb_rn       (),
        .thumb_imm8     (),
        .thumb_imm5     (),
        .thumb_offset11 (),
        .thumb_offset8  ()
    );
    
    // CP15 register definitions (ARM7TDMI System Control Coprocessor)
    parameter CP15_ID_REG       = 4'h0;  // ID register (read-only)
    parameter CP15_CONTROL_REG  = 4'h1;  // Control register
    parameter CP15_TTB_REG      = 4'h2;  // Translation Table Base
    parameter CP15_DOMAIN_REG   = 4'h3;  // Domain Access Control
    parameter CP15_FSR_REG      = 4'h5;  // Fault Status Register
    parameter CP15_FAR_REG      = 4'h6;  // Fault Address Register
    parameter CP15_CACHE_REG    = 4'h7;  // Cache Operations
    parameter CP15_TLB_REG      = 4'h8;  // TLB Operations
    parameter CP15_CACHE_LOCK   = 4'h9;  // Cache Lockdown
    parameter CP15_TLB_LOCK     = 4'hA;  // TLB Lockdown
    parameter CP15_PID_REG      = 4'hD;  // Process ID Register
    
    // Initialize CP15 registers with realistic values
    initial begin
        cp15_registers[CP15_ID_REG]      = 32'h41007700;  // ARM7TDMI ID
        cp15_registers[CP15_CONTROL_REG] = 32'h00000000;  // All features disabled initially
        cp15_registers[CP15_TTB_REG]     = 32'h00000000;  // No translation table
        cp15_registers[CP15_DOMAIN_REG]  = 32'h00000000;  // No domain access
        cp15_registers[CP15_FSR_REG]     = 32'h00000000;  // No faults
        cp15_registers[CP15_FAR_REG]     = 32'h00000000;  // No fault address
        cp15_registers[CP15_CACHE_REG]   = 32'h00000000;  // Cache operations
        cp15_registers[CP15_TLB_REG]     = 32'h00000000;  // TLB operations
        cp15_registers[CP15_CACHE_LOCK]  = 32'h00000000;  // No cache lockdown
        cp15_registers[CP15_TLB_LOCK]    = 32'h00000000;  // No TLB lockdown
        cp15_registers[CP15_PID_REG]     = 32'h00000000;  // Process ID 0
        
        // Initialize unused registers
        for (int i = 0; i < 16; i++) begin
            if (i != CP15_ID_REG && i != CP15_CONTROL_REG && i != CP15_TTB_REG &&
                i != CP15_DOMAIN_REG && i != CP15_FSR_REG && i != CP15_FAR_REG &&
                i != CP15_CACHE_REG && i != CP15_TLB_REG && i != CP15_CACHE_LOCK &&
                i != CP15_TLB_LOCK && i != CP15_PID_REG) begin
                cp15_registers[i] = 32'h00000000;
            end
        end
        
        // Initialize ARM registers
        for (int i = 0; i < 16; i++) begin
            arm_registers[i] = 32'h00000000;
        end
    end
    
    // Simplified coprocessor execution logic
    always_comb begin
        if (decode_instr_type == INSTR_COPROCESSOR && decode_valid && decode_cp_num == 4'hF) begin
            // CP15 operations only
            case (decode_cp_op)
                CP_MRC: begin
                    // Move from coprocessor to ARM register
                    // In real implementation: arm_registers[decode_cp_rd] = cp15_registers[decode_cp_rn];
                end
                CP_MCR: begin
                    // Move from ARM register to coprocessor
                    // In real implementation: cp15_registers[decode_cp_rn] = arm_registers[decode_cp_rd];
                end
                CP_CDP: begin
                    // Coprocessor data processing (cache/TLB operations)
                    // Implementation depends on opcode1 and opcode2
                end
                default: begin
                    // Other coprocessor operations
                end
            endcase
        end
    end
    
    // Test task for coprocessor operations
    task test_coprocessor_instruction(input [31:0] instr, input string name,
                                     input cp_op_t expected_op, input [3:0] expected_cp_num,
                                     input [3:0] expected_rd, input [3:0] expected_rn,
                                     input [2:0] expected_opc1, input [2:0] expected_opc2);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        
        instruction = instr;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, cp_op=%d, cp_num=%d", 
                 decode_instr_type, decode_cp_op, decode_cp_num);
        $display("  Fields: rd=%d, rn=%d, opc1=%d, opc2=%d, load=%b", 
                 decode_cp_rd, decode_cp_rn, decode_cp_opcode1, decode_cp_opcode2, decode_cp_load);
        
        // Check results
        test_passed = (decode_instr_type == INSTR_COPROCESSOR) &&
                     (decode_cp_op == expected_op) &&
                     (decode_cp_num == expected_cp_num) &&
                     (decode_cp_rd == expected_rd) &&
                     (decode_cp_rn == expected_rn) &&
                     (decode_cp_opcode1 == expected_opc1) &&
                     (decode_cp_opcode2 == expected_opc2);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
            $display("    Expected: op=%d, cp=%d, rd=%d, rn=%d, opc1=%d, opc2=%d", 
                     expected_op, expected_cp_num, expected_rd, expected_rn, expected_opc1, expected_opc2);
            $display("    Got:      op=%d, cp=%d, rd=%d, rn=%d, opc1=%d, opc2=%d", 
                     decode_cp_op, decode_cp_num, decode_cp_rd, decode_cp_rn, decode_cp_opcode1, decode_cp_opcode2);
        end
        $display("");
    endtask
    
    // Test task for CP15 system operations
    task test_cp15_system_op(input [31:0] instr, input string name, input string description);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Description: %s", description);
        
        instruction = instr;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        // For system operations, just check that it decodes as coprocessor
        test_passed = (decode_instr_type == INSTR_COPROCESSOR) && (decode_cp_num == 4'hF);
        
        $display("  Decode: type=%d, cp_num=%d, cp_op=%d", 
                 decode_instr_type, decode_cp_num, decode_cp_op);
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL - Not recognized as CP15 operation");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("coprocessor_enhanced_test_tb.vcd");
        $dumpvars(0, coprocessor_enhanced_test_tb);
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Enhanced Coprocessor Interface Test ===");
        
        // Test CP15 MRC operations (Move from Coprocessor to Register)
        $display("\n=== CP15 MRC Operations (Move from Coprocessor) ===");
        // MRC p15, 0, R0, c0, c0, 0 - Read ID register
        test_coprocessor_instruction(32'hEE100F10, "MRC p15,0,R0,c0,c0,0 (ID)", CP_MRC, 4'hF, 4'h0, 4'h0, 3'h0, 3'h0);
        
        // MRC p15, 0, R1, c1, c0, 0 - Read Control register
        test_coprocessor_instruction(32'hEE111F10, "MRC p15,0,R1,c1,c0,0 (Control)", CP_MRC, 4'hF, 4'h1, 4'h1, 3'h0, 3'h0);
        
        // MRC p15, 0, R2, c2, c0, 0 - Read Translation Table Base
        test_coprocessor_instruction(32'hEE122F10, "MRC p15,0,R2,c2,c0,0 (TTB)", CP_MRC, 4'hF, 4'h2, 4'h2, 3'h0, 3'h0);
        
        // MRC p15, 0, R3, c5, c0, 0 - Read Fault Status Register
        test_coprocessor_instruction(32'hEE153F10, "MRC p15,0,R3,c5,c0,0 (FSR)", CP_MRC, 4'hF, 4'h3, 4'h5, 3'h0, 3'h0);
        
        // Test CP15 MCR operations (Move from Register to Coprocessor)
        $display("\n=== CP15 MCR Operations (Move to Coprocessor) ===");
        // MCR p15, 0, R0, c1, c0, 0 - Write Control register
        test_coprocessor_instruction(32'hEE010F10, "MCR p15,0,R0,c1,c0,0 (Control)", CP_MCR, 4'hF, 4'h0, 4'h1, 3'h0, 3'h0);
        
        // MCR p15, 0, R1, c2, c0, 0 - Write Translation Table Base
        test_coprocessor_instruction(32'hEE021F10, "MCR p15,0,R1,c2,c0,0 (TTB)", CP_MCR, 4'hF, 4'h1, 4'h2, 3'h0, 3'h0);
        
        // MCR p15, 0, R2, c3, c0, 0 - Write Domain Access Control
        test_coprocessor_instruction(32'hEE032F10, "MCR p15,0,R2,c3,c0,0 (Domain)", CP_MCR, 4'hF, 4'h2, 4'h3, 3'h0, 3'h0);
        
        // MCR p15, 0, R4, c8, c7, 0 - Invalidate entire TLB
        test_coprocessor_instruction(32'hEE048F17, "MCR p15,0,R4,c8,c7,0 (TLB flush)", CP_MCR, 4'hF, 4'h4, 4'h8, 3'h0, 3'h7);
        
        // Test CP15 Cache Operations (CDP format)
        $display("\n=== CP15 Cache Operations (CDP) ===");
        // CDP p15, 0, c7, c7, c0, 0 - Invalidate entire cache
        test_cp15_system_op(32'hEE077F10, "CDP p15,0,c7,c7,c0,0", "Invalidate entire cache");
        
        // CDP p15, 0, c7, c10, c4, 1 - Drain write buffer
        test_cp15_system_op(32'hEE07AF94, "CDP p15,0,c7,c10,c4,1", "Drain write buffer");
        
        // Test other coprocessors
        $display("\n=== Other Coprocessor Operations ===");
        // MRC p10, 0, R0, c0, c0, 0 - VFP/FPU operation
        test_coprocessor_instruction(32'hEE100A10, "MRC p10,0,R0,c0,c0,0", CP_MRC, 4'hA, 4'h0, 4'h0, 3'h0, 3'h0);
        
        // MCR p11, 0, R1, c1, c0, 0 - VFP/FPU operation
        test_coprocessor_instruction(32'hEE011B10, "MCR p11,0,R1,c1,c0,0", CP_MCR, 4'hB, 4'h1, 4'h1, 3'h0, 3'h0);
        
        // Test coprocessor data transfer (LDC/STC)
        $display("\n=== Coprocessor Data Transfer ===");
        // Note: LDC/STC instructions need different decode handling
        // These would be decoded differently in the actual implementation
        
        // Test invalid coprocessor numbers
        $display("\n=== Edge Cases ===");
        // MRC p0, 0, R0, c0, c0, 0 - Coprocessor 0 (should decode but may not exist)
        test_coprocessor_instruction(32'hEE100010, "MRC p0,0,R0,c0,c0,0", CP_MRC, 4'h0, 4'h0, 4'h0, 3'h0, 3'h0);
        
        // Test with different opcodes
        // MRC p15, 1, R5, c0, c0, 1 - Different opcode1 and opcode2
        test_coprocessor_instruction(32'hEE305F11, "MRC p15,1,R5,c0,c0,1", CP_MRC, 4'hF, 4'h5, 4'h0, 3'h1, 3'h1);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL COPROCESSOR TESTS PASSED!");
        end else begin
            $display("❌ SOME COPROCESSOR TESTS FAILED");
        end
        
        // Display CP15 register summary
        $display("\n=== CP15 Register Summary ===");
        $display("ID Register (c0):      0x%08x", cp15_registers[CP15_ID_REG]);
        $display("Control Register (c1): 0x%08x", cp15_registers[CP15_CONTROL_REG]);
        $display("TTB Register (c2):     0x%08x", cp15_registers[CP15_TTB_REG]);
        $display("Domain Register (c3):  0x%08x", cp15_registers[CP15_DOMAIN_REG]);
        $display("FSR Register (c5):     0x%08x", cp15_registers[CP15_FSR_REG]);
        $display("FAR Register (c6):     0x%08x", cp15_registers[CP15_FAR_REG]);
        
        $finish;
    end
    
endmodule