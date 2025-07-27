// ARM7TDMI Instruction Fetch Unit Test Bench
// Tests fetching, prefetch buffer, MMU integration, ARM/Thumb modes

`timescale 1ns/1ps

module fetch_test_tb;

    // Test parameters
    localparam CLK_PERIOD = 10;
    
    // DUT signals
    logic        clk = 0;
    logic        rst_n = 1;
    
    // Control signals
    logic        fetch_en;
    logic        branch_taken;
    logic [31:0] branch_target;
    logic        thumb_mode;
    logic        high_vectors;
    
    // MMU interface
    logic [31:0] imem_vaddr;
    logic        imem_req;
    logic        imem_write;
    logic [1:0]  imem_size;
    logic [31:0] imem_wdata;
    logic [31:0] imem_rdata;
    logic        imem_ready;
    logic        imem_abort;
    
    // Output signals
    logic [31:0] instruction;
    logic [31:0] pc_out;
    logic        instr_valid;
    
    // Pipeline control
    logic        stall;
    logic        flush;
    
    // Exception handling
    logic        fetch_abort;
    logic [31:0] fetch_abort_addr;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Memory model for instruction fetch
    logic [31:0] imem_array [0:4095]; // 16KB instruction memory
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // DUT instantiation
    arm7tdmi_fetch u_fetch (
        .clk              (clk),
        .rst_n            (rst_n),
        .fetch_en         (fetch_en),
        .branch_taken     (branch_taken),
        .branch_target    (branch_target),
        .thumb_mode       (thumb_mode),
        .high_vectors     (high_vectors),
        .imem_vaddr       (imem_vaddr),
        .imem_req         (imem_req),
        .imem_write       (imem_write),
        .imem_size        (imem_size),
        .imem_wdata       (imem_wdata),
        .imem_rdata       (imem_rdata),
        .imem_ready       (imem_ready),
        .imem_abort       (imem_abort),
        .instruction      (instruction),
        .pc_out           (pc_out),
        .instr_valid      (instr_valid),
        .stall            (stall),
        .flush            (flush),
        .fetch_abort      (fetch_abort),
        .fetch_abort_addr (fetch_abort_addr)
    );
    
    // Simple memory model
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ready <= 1'b0;
            imem_abort <= 1'b0;
            imem_rdata <= 32'h0;
        end else begin
            imem_ready <= 1'b1;  // Always ready for this test
            imem_abort <= 1'b0;  // No aborts for basic test
            
            if (imem_req && !imem_write) begin
                // Word-aligned access
                imem_rdata <= imem_array[imem_vaddr[15:2]];
            end
        end
    end
    
    // Initialize instruction memory with test patterns
    initial begin
        // ARM instructions (32-bit, little-endian)
        imem_array[0] = 32'hE3A00001;  // MOV R0, #1
        imem_array[1] = 32'hE3A01002;  // MOV R1, #2  
        imem_array[2] = 32'hE0802001;  // ADD R2, R0, R1
        imem_array[3] = 32'hE3A03003;  // MOV R3, #3
        imem_array[4] = 32'hE1A04000;  // MOV R4, R0
        imem_array[5] = 32'hEAFFFFFE;  // B . (infinite loop)
        
        // Thumb instructions (16-bit pairs in 32-bit words)
        imem_array[16] = 32'h21012001;  // MOVS R1, #1; MOVS R0, #1
        imem_array[17] = 32'h18403102;  // ADDS R0, R0, R1; MOVS R2, #3
        imem_array[18] = 32'hE7FE4603;  // MOV R3, R0; B .
        
        // Fill rest with NOPs
        for (int i = 6; i < 16; i++) begin
            imem_array[i] = 32'hE1A00000;  // MOV R0, R0 (NOP)
        end
        for (int i = 19; i < 4096; i++) begin
            imem_array[i] = 32'h46C046C0;  // NOP; NOP (Thumb)
        end
    end
    
    // Test task
    task test_case(
        input string test_name,
        input logic expected_valid,
        input logic [31:0] expected_instruction,
        input logic [31:0] expected_pc
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        
        // Wait for instruction to be valid
        wait(instr_valid == expected_valid);
        @(posedge clk);
        
        $display("  PC: 0x%08x (expected: 0x%08x)", pc_out, expected_pc);
        $display("  Instruction: 0x%08x (expected: 0x%08x)", instruction, expected_instruction);
        $display("  Valid: %b (expected: %b)", instr_valid, expected_valid);
        
        if (instr_valid == expected_valid && 
            instruction == expected_instruction && 
            pc_out == expected_pc) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    task wait_cycles(input int cycles);
        repeat(cycles) @(posedge clk);
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("fetch_test_tb.vcd");
        $dumpvars(0, fetch_test_tb);
        
        // Initialize signals
        fetch_en = 1'b0;
        branch_taken = 1'b0;
        branch_target = 32'h0;
        thumb_mode = 1'b0;
        high_vectors = 1'b0;
        stall = 1'b0;
        flush = 1'b0;
        
        // Reset sequence
        rst_n = 0;
        wait_cycles(5);
        rst_n = 1;
        wait_cycles(5);
        
        $display("=== ARM7TDMI Instruction Fetch Test ===\n");
        
        // Test 1: Basic ARM instruction fetch
        $display("=== ARM Mode Tests ===");
        thumb_mode = 1'b0;
        fetch_en = 1'b1;
        
        test_case("ARM fetch - MOV R0, #1", 1'b1, 32'hE3A00001, 32'h00000000);
        
        // Let instruction be consumed
        wait_cycles(1);
        test_case("ARM fetch - MOV R1, #2", 1'b1, 32'hE3A01002, 32'h00000004);
        
        wait_cycles(1);
        test_case("ARM fetch - ADD R2, R0, R1", 1'b1, 32'hE0802001, 32'h00000008);
        
        // Test 2: Pipeline stall
        $display("=== Pipeline Stall Test ===");
        stall = 1'b1;
        wait_cycles(3);
        $display("Stall active - instruction should remain valid");
        if (instr_valid && instruction == 32'hE0802001) begin
            $display("  ✅ PASS - Instruction held during stall");
            test_passed++;
        end else begin
            $display("  ❌ FAIL - Instruction not held during stall");
        end
        test_count++;
        
        stall = 1'b0;
        wait_cycles(1);
        test_case("ARM fetch after stall", 1'b1, 32'hE3A03003, 32'h0000000C);
        
        // Test 3: Branch taken
        $display("=== Branch Test ===");
        branch_taken = 1'b1;
        branch_target = 32'h00000010;
        wait_cycles(1);
        branch_taken = 1'b0;
        
        // Should fetch from new address after prefetch buffer refill
        wait_cycles(2);
        test_case("ARM fetch after branch", 1'b1, 32'hE1A04000, 32'h00000010);
        
        // Test 4: Thumb mode
        $display("=== Thumb Mode Tests ===");
        thumb_mode = 1'b1;
        branch_taken = 1'b1;
        branch_target = 32'h00000040;  // Address 64 (imem_array[16])
        wait_cycles(1);
        branch_taken = 1'b0;
        
        wait_cycles(2);
        test_case("Thumb fetch - MOVS R0, #1", 1'b1, 32'h00002001, 32'h00000040);
        
        wait_cycles(1);
        test_case("Thumb fetch - MOVS R1, #1", 1'b1, 32'h00002101, 32'h00000042);
        
        wait_cycles(1);
        test_case("Thumb fetch - ADDS R0, R0, R1", 1'b1, 32'h00001840, 32'h00000044);
        
        // Test 5: Pipeline flush
        $display("=== Pipeline Flush Test ===");
        flush = 1'b1;
        wait_cycles(1);
        flush = 1'b0;
        
        // After flush, should start fetching again
        wait_cycles(3);
        $display("After flush - checking if new instruction is fetched");
        if (instr_valid) begin
            $display("  ✅ PASS - New instruction fetched after flush");
            test_passed++;
        end else begin
            $display("  ❌ FAIL - No instruction after flush");
        end
        test_count++;
        
        // Test 6: High vectors
        $display("=== High Vectors Test ===");
        high_vectors = 1'b1;
        rst_n = 0;
        wait_cycles(2);
        rst_n = 1;
        wait_cycles(1);
        
        if (pc_out == 32'hFFFF0000) begin
            $display("  ✅ PASS - PC starts at high vectors (0x%08x)", pc_out);
            test_passed++;
        end else begin
            $display("  ❌ FAIL - PC should start at 0xFFFF0000, got 0x%08x", pc_out);
        end
        test_count++;
        
        // Final results
        wait_cycles(5);
        $display("=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("✅ ALL FETCH TESTS PASSED!");
        end else begin
            $display("❌ SOME FETCH TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000;
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule