// ARM7TDMI Memory Unit Test Bench
// Tests load/store operations, alignment, and exception handling

`timescale 1ns/1ps

module memory_test;
    
    // Test parameters
    localparam CLK_PERIOD = 10;
    
    // System signals
    logic clk = 0;
    logic rst_n = 1;
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Memory unit inputs (from execute)
    logic [3:0]  instr_type = 4'b0110;    // INSTR_SINGLE_DT
    logic [31:0] memory_address = 32'h1000;
    logic [31:0] store_data = 32'h12345678;
    logic        mem_req = 1'b1;
    logic        mem_write = 1'b0;        // Load operation
    logic [1:0]  mem_size = 2'b10;        // Word access
    logic [31:0] pc_in = 32'h100;
    logic        execute_valid = 1'b1;
    
    // Load/Store details
    logic        mem_load = 1'b1;
    logic        mem_byte = 1'b0;
    logic        mem_halfword = 1'b0;
    logic        mem_signed = 1'b0;
    logic        mem_pre = 1'b1;
    logic        mem_up = 1'b1;
    logic        mem_writeback = 1'b0;
    
    // Block transfer inputs (unused for single transfer tests)
    logic        block_en = 1'b0;
    logic        block_load = 1'b0;
    logic        block_pre = 1'b0;
    logic        block_up = 1'b0;
    logic        block_writeback = 1'b0;
    logic        block_user_mode = 1'b0;
    logic [15:0] register_list = 16'h0;
    logic [3:0]  base_register = 4'h1;
    logic [31:0] base_address = 32'h1000;
    
    // Pipeline control
    logic        stall = 1'b0;
    logic        flush = 1'b0;
    
    // Memory unit outputs
    logic [3:0]  reg_read_addr;
    logic [31:0] reg_read_data = 32'hDEADBEEF; // Simulated register data
    logic [3:0]  reg_write_addr;
    logic [31:0] reg_write_data;
    logic        reg_write_enable;
    
    // MMU interface
    logic [31:0] dmem_vaddr;
    logic        dmem_req;
    logic        dmem_write;
    logic [1:0]  dmem_size;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_byte_en;
    logic [31:0] dmem_rdata = 32'hABCDEF01; // Simulated memory data
    logic        dmem_ready = 1'b1;
    logic        dmem_abort = 1'b0;
    
    // Cache interface
    logic        cache_enable;
    logic        cache_flush;
    logic        cache_hit = 1'b1;
    logic        cache_busy = 1'b0;
    
    // Memory unit outputs
    logic [31:0] load_data;
    logic [31:0] pc_out;
    logic        memory_valid;
    logic        memory_complete;
    logic        data_abort;
    logic [31:0] abort_address;
    logic        alignment_fault;
    
    // Simple memory model for testing
    logic [31:0] test_memory [0:4095]; // 16KB test memory
    
    // Initialize test memory
    initial begin
        for (int i = 0; i < 4096; i++) begin
            test_memory[i] = 32'h01000000 + i; // Pattern: 0x01000000, 0x01000001, etc.
        end
        test_memory[1024] = 32'hDEADBEEF; // Address 0x1000
        test_memory[1025] = 32'h12345678; // Address 0x1004
        test_memory[1026] = 32'hABCDEF01; // Address 0x1008
    end
    
    // Simple memory model behavior
    always_ff @(posedge clk) begin
        if (dmem_req && dmem_ready) begin
            if (dmem_write) begin
                // Store operation
                test_memory[dmem_vaddr[15:2]] <= dmem_wdata;
            end else begin
                // Load operation
                dmem_rdata <= test_memory[dmem_vaddr[15:2]];
            end
        end
    end
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    task test_load_operation(
        input string test_name,
        input logic [31:0] addr,
        input logic [1:0] size,
        input logic signed_op,
        input logic [31:0] expected_data
    );
        test_count++;
        
        // Setup load operation
        memory_address = addr;
        mem_size = size;
        mem_signed = signed_op;
        mem_load = 1'b1;
        mem_write = 1'b0;
        mem_req = 1'b1;
        execute_valid = 1'b1;
        
        // Wait for completion
        @(posedge clk);
        wait(memory_complete);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Address: 0x%08x", addr);
        $display("  Size: %s", size == 2'b10 ? "Word" : size == 2'b01 ? "Halfword" : "Byte");
        $display("  Load Data: 0x%08x (expected: 0x%08x)", load_data, expected_data);
        $display("  Reg Write: R%d = 0x%08x (enable: %b)", reg_write_addr, reg_write_data, reg_write_enable);
        $display("  Memory Complete: %b", memory_complete);
        $display("  Data Abort: %b", data_abort);
        
        if (memory_complete && !data_abort && reg_write_enable) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Reset for next test
        mem_req = 1'b0;
        execute_valid = 1'b0;
        @(posedge clk);
    endtask
    
    task test_store_operation(
        input string test_name,
        input logic [31:0] addr,
        input logic [1:0] size,
        input logic [31:0] data
    );
        test_count++;
        
        // Setup store operation
        memory_address = addr;
        store_data = data;
        mem_size = size;
        mem_load = 1'b0;
        mem_write = 1'b1;
        mem_req = 1'b1;
        execute_valid = 1'b1;
        
        // Wait for completion
        @(posedge clk);
        wait(memory_complete);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Address: 0x%08x", addr);
        $display("  Size: %s", size == 2'b10 ? "Word" : size == 2'b01 ? "Halfword" : "Byte");
        $display("  Store Data: 0x%08x", data);
        $display("  Memory Address: 0x%08x", dmem_vaddr);
        $display("  Memory Write: %b", dmem_write);
        $display("  Memory Data: 0x%08x", dmem_wdata);
        $display("  Byte Enables: %b", dmem_byte_en);
        $display("  Memory Complete: %b", memory_complete);
        $display("  Data Abort: %b", data_abort);
        
        if (memory_complete && !data_abort && dmem_write) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Reset for next test
        mem_req = 1'b0;
        execute_valid = 1'b0;
        @(posedge clk);
    endtask
    
    task test_alignment_fault(
        input string test_name,
        input logic [31:0] addr,
        input logic [1:0] size
    );
        test_count++;
        
        // Setup misaligned access
        memory_address = addr;
        mem_size = size;
        mem_load = 1'b1;
        mem_req = 1'b1;
        execute_valid = 1'b1;
        
        @(posedge clk);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Address: 0x%08x", addr);
        $display("  Size: %s", size == 2'b10 ? "Word" : size == 2'b01 ? "Halfword" : "Byte");
        $display("  Alignment Fault: %b", alignment_fault);
        $display("  Data Abort: %b", data_abort);
        
        if (alignment_fault || data_abort) begin
            test_passed++;
            $display("  ✅ PASS - Alignment fault detected");
        end else begin
            $display("  ❌ FAIL - Should have generated alignment fault");
        end
        $display("");
        
        // Reset for next test
        mem_req = 1'b0;
        execute_valid = 1'b0;
        @(posedge clk);
    endtask
    
    // Instantiate memory unit
    arm7tdmi_memory u_memory (
        .clk              (clk),
        .rst_n            (rst_n),
        .instr_type       (instr_type),
        .memory_address   (memory_address),
        .store_data       (store_data),
        .mem_req          (mem_req),
        .mem_write        (mem_write),
        .mem_size         (mem_size),
        .pc_in            (pc_in),
        .execute_valid    (execute_valid),
        .mem_load         (mem_load),
        .mem_byte         (mem_byte),
        .mem_halfword     (mem_halfword),
        .mem_signed       (mem_signed),
        .mem_pre          (mem_pre),
        .mem_up           (mem_up),
        .mem_writeback    (mem_writeback),
        .block_en         (block_en),
        .block_load       (block_load),
        .block_pre        (block_pre),
        .block_up         (block_up),
        .block_writeback  (block_writeback),
        .block_user_mode  (block_user_mode),
        .register_list    (register_list),
        .base_register    (base_register),
        .base_address     (base_address),
        .reg_read_addr    (reg_read_addr),
        .reg_read_data    (reg_read_data),
        .reg_write_addr   (reg_write_addr),
        .reg_write_data   (reg_write_data),
        .reg_write_enable (reg_write_enable),
        .dmem_vaddr       (dmem_vaddr),
        .dmem_req         (dmem_req),
        .dmem_write       (dmem_write),
        .dmem_size        (dmem_size),
        .dmem_wdata       (dmem_wdata),
        .dmem_byte_en     (dmem_byte_en),
        .dmem_rdata       (dmem_rdata),
        .dmem_ready       (dmem_ready),
        .dmem_abort       (dmem_abort),
        .cache_enable     (cache_enable),
        .cache_flush      (cache_flush),
        .cache_hit        (cache_hit),
        .cache_busy       (cache_busy),
        .load_data        (load_data),
        .pc_out           (pc_out),
        .memory_valid     (memory_valid),
        .memory_complete  (memory_complete),
        .data_abort       (data_abort),
        .abort_address    (abort_address),
        .alignment_fault  (alignment_fault),
        .stall            (stall),
        .flush            (flush)
    );
    
    // Main test sequence
    initial begin
        $dumpfile("memory_test.vcd");
        $dumpvars(0, memory_test);
        
        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Memory Unit Test ===\n");
        
        // Test 1: Word load operations
        $display("=== Word Load Tests ===");
        test_load_operation("LDR R1, [0x1000]", 32'h1000, 2'b10, 1'b0, 32'hDEADBEEF);
        test_load_operation("LDR R2, [0x1004]", 32'h1004, 2'b10, 1'b0, 32'h12345678);
        
        // Test 2: Halfword load operations
        $display("=== Halfword Load Tests ===");
        test_load_operation("LDRH R3, [0x1000]", 32'h1000, 2'b01, 1'b0, 32'h0000BEEF);
        test_load_operation("LDRSH R4, [0x1002]", 32'h1002, 2'b01, 1'b1, 32'hFFFFDEAD);
        
        // Test 3: Byte load operations  
        $display("=== Byte Load Tests ===");
        test_load_operation("LDRB R5, [0x1000]", 32'h1000, 2'b00, 1'b0, 32'h000000EF);
        test_load_operation("LDRSB R6, [0x1003]", 32'h1003, 2'b00, 1'b1, 32'hFFFFFFDE);
        
        // Test 4: Store operations
        $display("=== Store Tests ===");
        test_store_operation("STR R7, [0x2000]", 32'h2000, 2'b10, 32'hFEEDFACE);
        test_store_operation("STRH R8, [0x2004]", 32'h2004, 2'b01, 32'h0000CAFE);
        test_store_operation("STRB R9, [0x2006]", 32'h2006, 2'b00, 32'h000000BE);
        
        // Test 5: Alignment fault tests
        $display("=== Alignment Fault Tests ===");
        test_alignment_fault("Misaligned word access", 32'h1001, 2'b10);
        test_alignment_fault("Misaligned halfword access", 32'h1001, 2'b01);
        
        // Test 6: Cache interface
        $display("=== Cache Interface Test ===");
        $display("Cache Enable: %b", cache_enable);
        $display("Cache Flush: %b", cache_flush);
        if (cache_enable) begin
            test_passed++;
            $display("✅ PASS - Cache interface working");
        end
        test_count++;
        
        // Final results
        repeat(5) @(posedge clk);
        $display("=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("✅ ALL MEMORY TESTS PASSED!");
        end else begin
            $display("❌ SOME MEMORY TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule