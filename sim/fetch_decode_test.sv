// Test integration between fetch and decode units
`timescale 1ns/1ps

module fetch_decode_test;
    
    // Test parameters
    localparam CLK_PERIOD = 10;
    
    // System signals
    logic clk = 0;
    logic rst_n = 1;
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Fetch unit signals
    logic fetch_en = 1;
    logic branch_taken = 0;
    logic [31:0] branch_target = 0;
    logic thumb_mode = 0;
    logic high_vectors = 0;
    logic stall = 0;
    logic flush = 0;
    
    // Memory interface signals  
    logic [31:0] imem_vaddr;
    logic imem_req;
    logic imem_write;
    logic [1:0] imem_size;
    logic [31:0] imem_wdata;
    logic [31:0] imem_rdata;
    logic imem_ready;
    logic imem_abort;
    
    // Fetch to decode signals
    logic [31:0] instruction;
    logic [31:0] pc_out;
    logic instr_valid;
    logic fetch_abort;
    logic [31:0] fetch_abort_addr;
    
    // Decode outputs (basic subset for testing)
    logic [3:0] condition;
    logic [3:0] alu_op;
    logic [3:0] rd, rn, rm;
    logic [11:0] immediate;
    logic imm_en;
    
    // Memory model for instruction fetch
    logic [31:0] imem_array [0:4095]; // 16KB instruction memory
    
    // Initialize instruction memory
    initial begin
        // ARM instructions (same as fetch test)
        imem_array[0] = 32'hE3A00001;  // MOV R0, #1
        imem_array[1] = 32'hE3A01002;  // MOV R1, #2  
        imem_array[2] = 32'hE0802001;  // ADD R2, R0, R1
        imem_array[3] = 32'hE3A03003;  // MOV R3, #3
        imem_array[4] = 32'hE1A04000;  // MOV R4, R0
        
        // Fill rest with NOPs
        for (int i = 5; i < 4096; i++) begin
            imem_array[i] = 32'hE1A00000;  // MOV R0, R0 (NOP)
        end
    end
    
    // Simple memory model
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ready <= 1'b0;
            imem_abort <= 1'b0;
            imem_rdata <= 32'h0;
        end else begin
            imem_ready <= 1'b1;  // Always ready
            imem_abort <= 1'b0;  // No aborts
            
            if (imem_req && !imem_write) begin
                imem_rdata <= imem_array[imem_vaddr[15:2]];
            end
        end
    end
    
    // Instantiate fetch unit
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
    
    // Simple decode logic (manual decoding for test)
    always_comb begin
        condition = instruction[31:28];
        alu_op = instruction[24:21];
        rd = instruction[15:12];
        rn = instruction[19:16];
        rm = instruction[3:0];
        immediate = instruction[11:0];
        imm_en = instruction[25];
    end
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    task test_fetch_decode(
        input string test_name,
        input logic [31:0] expected_instr,
        input logic [31:0] expected_pc,
        input logic [3:0] expected_alu_op,
        input logic [3:0] expected_rd
    );
        test_count++;
        
        // Wait for instruction to be valid
        wait(instr_valid);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  PC: 0x%08x (expected: 0x%08x)", pc_out, expected_pc);
        $display("  Instruction: 0x%08x (expected: 0x%08x)", instruction, expected_instr);
        $display("  ALU Op: 0x%x (expected: 0x%x)", alu_op, expected_alu_op);
        $display("  Rd: 0x%x (expected: 0x%x)", rd, expected_rd);
        
        if (instruction == expected_instr && pc_out == expected_pc && 
            alu_op == expected_alu_op && rd == expected_rd) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Advance to next instruction
        repeat(2) @(posedge clk);
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("fetch_decode_test.vcd");
        $dumpvars(0, fetch_decode_test);
        
        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Fetch-Decode Integration Test ===\n");
        
        // Test 1: MOV R0, #1
        test_fetch_decode("MOV R0, #1", 32'hE3A00001, 32'h00000000, 4'hD, 4'h0);
        
        // Test 2: MOV R1, #2
        test_fetch_decode("MOV R1, #2", 32'hE3A01002, 32'h00000004, 4'hD, 4'h1);
        
        // Test 3: ADD R2, R0, R1
        test_fetch_decode("ADD R2, R0, R1", 32'hE0802001, 32'h00000008, 4'h4, 4'h2);
        
        // Test 4: MOV R3, #3
        test_fetch_decode("MOV R3, #3", 32'hE3A03003, 32'h0000000C, 4'hD, 4'h3);
        
        // Final results
        repeat(5) @(posedge clk);
        $display("=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("✅ ALL FETCH-DECODE TESTS PASSED!");
        end else begin
            $display("❌ SOME FETCH-DECODE TESTS FAILED");
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