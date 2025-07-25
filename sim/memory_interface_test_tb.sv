// Memory interface validation test for ARM7TDMI
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module memory_interface_test_tb;
    
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
    
    // Decode outputs for memory operations
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
    
    // Register file signals
    logic [31:0] reg_rn_data = 32'h1000; // Base address
    logic [31:0] reg_rm_data = 32'h12345678; // Data to store
    
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
    
    // Memory address calculation (simplified from top-level)
    logic [31:0] mem_address;
    always_comb begin
        if (decode_imm_en) begin
            // Immediate offset: [Rn, #+/-immediate]
            mem_address = reg_rn_data + (decode_mem_up ? {20'b0, decode_immediate} : -{20'b0, decode_immediate});
        end else begin
            // Register offset: [Rn, +/-Rm] - but for basic LDR/STR without offset, just use base
            mem_address = reg_rn_data;  // For [Rn] addressing mode
        end
    end
    
    // Memory control logic (simplified from top-level)
    assign mem_addr = mem_address;
    assign mem_we = decode_is_memory && !decode_mem_load && decode_valid;  // Store
    assign mem_re = decode_is_memory && decode_mem_load && decode_valid;   // Load
    assign mem_wdata = reg_rm_data;  // Store data
    
    // Byte enable generation
    always_comb begin
        if (decode_mem_byte) begin
            // Byte access
            mem_be = 1'b1 << mem_address[1:0];
        end else begin
            // Word access
            mem_be = 4'b1111;
        end
    end
    
    // Test task
    task test_memory_instruction(input [31:0] instr, input string name,
                                input [31:0] base_addr, input [31:0] test_data,
                                input [31:0] expected_result, input logic is_load,
                                input [31:0] expected_addr = 32'h0);
        tests_run++;
        
        $display("Testing: %s", name);
        $display("  Instruction: 0x%08x", instr);
        $display("  Base addr: 0x%08x, Data: 0x%08x", base_addr, test_data);
        
        // Set up
        reg_rn_data = base_addr;
        reg_rm_data = test_data;
        instruction = instr;
        
        // Clear memory
        for (int i = 0; i < 256; i++) begin
            memory[i] = 32'h0;
        end
        
        if (is_load) begin
            // Pre-populate memory for load at the address that will be accessed
            actual_mem = (expected_addr != 32'h0) ? expected_addr : base_addr;
            memory[actual_mem[9:2]] = test_data;
            $display("  Pre-loaded memory[0x%08x] = 0x%08x", actual_mem, test_data);
        end
        
        @(posedge clk);
        @(posedge clk);  // Let decode settle
        
        $display("  Decode: type=%d, is_memory=%b, load=%b, byte=%b", 
                 decode_instr_type, decode_is_memory, decode_mem_load, decode_mem_byte);
        $display("  Decode: imm_en=%b, immediate=0x%03x, mem_up=%b", 
                 decode_imm_en, decode_immediate, decode_mem_up);
        $display("  Memory: addr=0x%08x, we=%b, re=%b, be=0x%x", 
                 mem_addr, mem_we, mem_re, mem_be);
        
        @(posedge clk);  // Memory operation
        
        // Check results
        test_passed = 1'b0;
        
        if (is_load) begin
            $display("  Load completed - data read: 0x%08x", mem_rdata);
            test_passed = (mem_rdata == expected_result);
        end else begin
            // For stores, check if memory was updated correctly at the accessed address
            actual_mem = memory[mem_address[9:2]];
            $display("  Store completed - memory: 0x%08x", actual_mem);
            test_passed = (actual_mem == expected_result);
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
        $dumpfile("memory_interface_test_tb.vcd");
        $dumpvars(0, memory_interface_test_tb);
        
        // Initialize
        for (int i = 0; i < 256; i++) begin
            memory[i] = 32'h0;
        end
        
        // Reset
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("=== ARM7TDMI Memory Interface Test ===");
        
        // Test Single Data Transfer - Word Operations
        $display("\n=== Word Operations ===");
        test_memory_instruction(32'hE5810000, "STR R0, [R1]", 32'h1000, 32'h12345678, 32'h12345678, 1'b0, 32'h1000);
        test_memory_instruction(32'hE5910000, "LDR R0, [R1]", 32'h1004, 32'h87654321, 32'h87654321, 1'b1, 32'h1004);
        
        // Test with immediate offset
        test_memory_instruction(32'hE5810004, "STR R0, [R1, #4]", 32'h1000, 32'hAABBCCDD, 32'hAABBCCDD, 1'b0, 32'h1004);
        test_memory_instruction(32'hE5910008, "LDR R0, [R1, #8]", 32'h1000, 32'h11223344, 32'h11223344, 1'b1, 32'h1008);
        
        // Test Byte Operations
        $display("\n=== Byte Operations ===");
        test_memory_instruction(32'hE5C10000, "STRB R0, [R1]", 32'h1010, 32'h000000AB, 32'h000000AB, 1'b0, 32'h1010);
        test_memory_instruction(32'hE5D10000, "LDRB R0, [R1]", 32'h1014, 32'h000000CD, 32'h000000CD, 1'b1, 32'h1014);
        
        // Summary
        @(posedge clk);
        $display("=== Test Summary ===");
        $display("Tests Run: %d", tests_run);
        $display("Tests Passed: %d", tests_passed);
        $display("Pass Rate: %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL MEMORY INTERFACE TESTS PASSED!");
        end else begin
            $display("❌ SOME MEMORY INTERFACE TESTS FAILED");
        end
        
        $finish;
    end
    
endmodule