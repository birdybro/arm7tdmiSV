// Swap operation test for ARM7TDMI (SWP/SWPB)
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module swap_test_tb;
    
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
    
    // Register file signals (simplified for testing)
    logic [31:0] reg_rn_data = 32'h4000; // Base address
    logic [31:0] reg_rm_data = 32'hDEADBEEF; // Data to swap in
    logic [31:0] reg_rd_data; // Will receive swapped out data
    
    // Memory interface
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_we;
    logic        mem_re;
    logic [3:0]  mem_be;
    logic        mem_ready = 1;
    
    // Test results tracking
    int tests_run = 0;
    int tests_passed = 0;
    
    // Task variables  
    logic test_passed;
    logic [31:0] actual_mem;
    logic [31:0] original_mem;
    
    // Simple memory model
    logic [31:0] memory [0:255];  // 1KB memory
    always_ff @(posedge clk) begin
        if (mem_we && mem_ready) begin
            if (mem_be[0]) memory[mem_addr[9:2]][7:0]   <= mem_wdata[7:0];
            if (mem_be[1]) memory[mem_addr[9:2]][15:8]  <= mem_wdata[15:8];
            if (mem_be[2]) memory[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
            if (mem_be[3]) memory[mem_addr[9:2]][31:24] <= mem_wdata[31:24];
        end
    end
    assign mem_rdata = mem_re ? memory[mem_addr[9:2]] : 32'h0;
    
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
    
    // Memory address calculation (for swap, always use base register)
    logic [31:0] mem_address;
    assign mem_address = reg_rn_data;
    
    // Memory control logic - simplified swap implementation
    // In a real implementation, this would be a multi-cycle operation
    assign mem_addr = mem_address;
    assign mem_we = decode_is_memory && decode_valid && (decode_instr_type == INSTR_SINGLE_SWAP);
    assign mem_re = decode_is_memory && decode_valid && (decode_instr_type == INSTR_SINGLE_SWAP);
    assign mem_wdata = reg_rm_data;  // Data to write (swap in)
    
    // Byte enable generation for swap operations
    always_comb begin
        if (decode_mem_byte) begin
            // Byte swap (SWPB)
            mem_be = 1'b1 << mem_address[1:0];
        end else begin
            // Word swap (SWP)
            mem_be = 4'b1111;
        end
    end
    
    // Test task for swap operations
    task test_swap_instruction(input [31:0] instr, input string name,
                              input [31:0] base_addr, input [31:0] swap_in_data,
                              input [31:0] memory_data, input logic is_byte);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Base addr: 0x%08x, Swap in: 0x%08x, Memory: 0x%08x", 
                 base_addr, swap_in_data, memory_data);
        
        // Set up
        reg_rn_data = base_addr;
        reg_rm_data = swap_in_data;
        instruction = instr;
        original_mem = memory_data;
        
        // Clear memory
        for (int i = 0; i < 256; i++) begin
            memory[i] = 32'h0;
        end
        
        // Pre-populate memory with original value
        memory[base_addr[9:2]] = memory_data;
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, is_memory=%b, byte=%b", 
                 decode_instr_type, decode_is_memory, decode_mem_byte);
        $display("  Memory: addr=0x%08x, we=%b, re=%b, be=0x%x", 
                 mem_addr, mem_we, mem_re, mem_be);
        $display("  Read data: 0x%08x, Write data: 0x%08x", mem_rdata, mem_wdata);
        
        @(posedge clk);  // Memory operation
        
        // Check results
        test_passed = 1'b1;
        
        // For swap, check that memory now contains the swap-in data
        actual_mem = memory[base_addr[9:2]];
        
        if (is_byte) begin
            // For byte swap, only check the relevant byte
            logic [7:0] expected_byte = swap_in_data[7:0];
            logic [7:0] actual_byte;
            case (base_addr[1:0])
                2'b00: actual_byte = actual_mem[7:0];
                2'b01: actual_byte = actual_mem[15:8];
                2'b10: actual_byte = actual_mem[23:16];
                2'b11: actual_byte = actual_mem[31:24];
            endcase
            
            if (actual_byte != expected_byte) begin
                $display("  Byte mismatch: expected 0x%02x, got 0x%02x", 
                        expected_byte, actual_byte);
                test_passed = 1'b0;
            end
            
            // Simulate reading back the original byte value that should go to Rd
            reg_rd_data = {24'b0, memory_data[7:0]};  // Zero-extended byte
            $display("  Swap completed - Memory byte: 0x%02x, Rd should get: 0x%08x", 
                     actual_byte, reg_rd_data);
        end else begin
            // For word swap, check the entire word
            if (actual_mem != swap_in_data) begin
                $display("  Word mismatch: expected 0x%08x, got 0x%08x", 
                        swap_in_data, actual_mem);
                test_passed = 1'b0;
            end
            
            // Simulate the original memory value that should go to Rd
            reg_rd_data = memory_data;
            $display("  Swap completed - Memory: 0x%08x, Rd should get: 0x%08x", 
                     actual_mem, reg_rd_data);
        end
        
        if (test_passed) begin
            tests_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("swap_test_tb.vcd");
        $dumpvars(0, swap_test_tb);
        
        // Initialize
        for (int i = 0; i < 256; i++) begin
            memory[i] = 32'h0;
        end
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Swap Operations Test ===");
        
        // Test Word Swap Operations (SWP)
        // Format: cond 00010 B 00 Rn Rd 0000 1001 Rm
        $display("\n=== Word Swap Operations (SWP) ===");
        test_swap_instruction(32'hE1000091, "SWP R0, R1, [R0]", 32'h4000, 32'hDEADBEEF, 32'h12345678, 1'b0);
        test_swap_instruction(32'hE1032094, "SWP R2, R4, [R3]", 32'h4004, 32'hCAFEBABE, 32'h87654321, 1'b0);
        test_swap_instruction(32'hE1056095, "SWP R5, R6, [R5]", 32'h4008, 32'hFEEDFACE, 32'hABCDEF00, 1'b0);
        
        // Test Byte Swap Operations (SWPB) 
        $display("\n=== Byte Swap Operations (SWPB) ===");
        test_swap_instruction(32'hE1400091, "SWPB R0, R1, [R0]", 32'h400C, 32'h000000AB, 32'h12345678, 1'b1);
        test_swap_instruction(32'hE1432094, "SWPB R2, R4, [R3]", 32'h400D, 32'h000000CD, 32'h87654321, 1'b1);
        test_swap_instruction(32'hE1456095, "SWPB R5, R6, [R5]", 32'h400E, 32'h000000EF, 32'hABCDEF00, 1'b1);
        
        // Test Swap with Same Register
        $display("\n=== Swap with Same Register ===");
        test_swap_instruction(32'hE1000090, "SWP R0, R0, [R0]", 32'h4010, 32'hAAAAAAAA, 32'hBBBBBBBB, 1'b0);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL SWAP TESTS PASSED!");
        end else begin
            $display("❌ SOME SWAP TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule