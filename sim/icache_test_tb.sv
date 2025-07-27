// ARM7TDMI Instruction Cache Test Bench
// Tests cache functionality including hits, misses, and Thumb mode support

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module icache_test_tb;
    
    // Parameters matching the cache design
    localparam CACHE_SIZE_BYTES = 4096;
    localparam CACHE_LINE_SIZE = 32;
    localparam ADDR_WIDTH = 32;
    localparam CACHE_LINES = CACHE_SIZE_BYTES / CACHE_LINE_SIZE;
    localparam WORDS_PER_LINE = CACHE_LINE_SIZE / 4;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // DUT signals
    logic [ADDR_WIDTH-1:0]  cpu_addr;
    logic                   cpu_req;
    logic                   cpu_thumb_mode;
    logic [31:0]            cpu_data;
    logic                   cpu_hit;
    logic                   cpu_ready;
    
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req;
    logic [2:0]             mem_burst_len;
    logic [31:0]            mem_data;
    logic                   mem_valid;
    logic                   mem_ready;
    
    logic                   cache_enable;
    logic                   cache_flush;
    logic                   cache_invalidate;
    
    logic [31:0]            cache_hits;
    logic [31:0]            cache_misses;
    logic                   cache_busy;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Memory model
    logic [31:0] memory [0:65535]; // 256KB memory model
    logic [2:0]  burst_counter;
    logic        mem_burst_active;
    
    // Initialize memory with test patterns
    initial begin
        for (int i = 0; i < 65536; i++) begin
            memory[i] = 32'hDEAD0000 + i; // Unique pattern for each word
        end
    end
    
    // Memory model behavior
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_valid <= 1'b0;
            mem_ready <= 1'b1;
            burst_counter <= 3'b0;
            mem_burst_active <= 1'b0;
        end else begin
            mem_valid <= 1'b0;
            
            if (mem_req && mem_ready && !mem_burst_active) begin
                // Start burst
                mem_burst_active <= 1'b1;
                burst_counter <= 3'b0;
                mem_ready <= 1'b0;
            end else if (mem_burst_active) begin
                // Continue burst
                mem_valid <= 1'b1;
                mem_data <= memory[(mem_addr >> 2) + burst_counter];
                burst_counter <= burst_counter + 1;
                
                if (burst_counter == mem_burst_len) begin
                    mem_burst_active <= 1'b0;
                    mem_ready <= 1'b1;
                end
            end
        end
    end
    
    // DUT instantiation
    arm7tdmi_icache #(
        .CACHE_SIZE_BYTES(CACHE_SIZE_BYTES),
        .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_icache (
        .clk                (clk),
        .rst_n              (rst_n),
        .cpu_addr           (cpu_addr),
        .cpu_req            (cpu_req),
        .cpu_thumb_mode     (cpu_thumb_mode),
        .cpu_data           (cpu_data),
        .cpu_hit            (cpu_hit),
        .cpu_ready          (cpu_ready),
        .mem_addr           (mem_addr),
        .mem_req            (mem_req),
        .mem_burst_len      (mem_burst_len),
        .mem_data           (mem_data),
        .mem_valid          (mem_valid),
        .mem_ready          (mem_ready),
        .cache_enable       (cache_enable),
        .cache_flush        (cache_flush),
        .cache_invalidate   (cache_invalidate),
        .cache_hits         (cache_hits),
        .cache_misses       (cache_misses),
        .cache_busy         (cache_busy)
    );
    
    // Test tasks
    task test_cache_request(
        input [31:0] addr,
        input logic thumb_mode,
        input [31:0] expected_data,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Address: 0x%08x, Thumb: %b", addr, thumb_mode);
        
        cpu_addr = addr;
        cpu_thumb_mode = thumb_mode;
        cpu_req = 1'b1;
        
        // Wait for ready
        while (!cpu_ready) begin
            @(posedge clk);
        end
        
        @(posedge clk);
        
        $display("  Expected: 0x%08x, Got: 0x%08x", expected_data, cpu_data);
        $display("  Hit: %b, Ready: %b", cpu_hit, cpu_ready);
        
        if (cpu_data == expected_data) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    task wait_cache_ready;
        while (cache_busy) begin
            @(posedge clk);
        end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("icache_test_tb.vcd");
        $dumpvars(0, icache_test_tb);
        
        // Initialize
        cpu_addr = 32'h0;
        cpu_req = 1'b0;
        cpu_thumb_mode = 1'b0;
        cache_enable = 1'b1;
        cache_flush = 1'b0;
        cache_invalidate = 1'b0;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Instruction Cache Test ===");
        $display("Cache Size: %d bytes, Line Size: %d bytes", CACHE_SIZE_BYTES, CACHE_LINE_SIZE);
        $display("Cache Lines: %d, Words per Line: %d\n", CACHE_LINES, WORDS_PER_LINE);
        
        // Test 1: Basic cache miss and fill (ARM mode)
        test_cache_request(32'h00001000, 1'b0, memory[32'h1000 >> 2], "Basic cache miss - ARM mode");
        wait_cache_ready();
        
        // Test 2: Cache hit on same address
        test_cache_request(32'h00001000, 1'b0, memory[32'h1000 >> 2], "Cache hit - same address");
        
        // Test 3: Cache hit on same cache line (different word)
        test_cache_request(32'h00001004, 1'b0, memory[32'h1004 >> 2], "Cache hit - same line, next word");
        
        // Test 4: Cache hit on same cache line (last word)
        test_cache_request(32'h0000101C, 1'b0, memory[32'h101C >> 2], "Cache hit - same line, last word");
        
        // Test 5: Thumb mode - lower halfword
        test_cache_request(32'h00001020, 1'b1, memory[32'h1020 >> 2] & 32'h0000FFFF, "Thumb mode - lower halfword");
        wait_cache_ready();
        
        // Test 6: Thumb mode - upper halfword  
        test_cache_request(32'h00001022, 1'b1, (memory[32'h1020 >> 2] >> 16) & 32'h0000FFFF, "Thumb mode - upper halfword");
        
        // Test 7: Different cache line (should miss)
        test_cache_request(32'h00002000, 1'b0, memory[32'h2000 >> 2], "Different cache line - miss");
        wait_cache_ready();
        
        // Test 8: Return to first cache line (should hit if still cached)
        test_cache_request(32'h00001008, 1'b0, memory[32'h1008 >> 2], "Return to first line - hit");
        
        // Test 9: Cache flush test
        $display("Test %d: Cache flush test", test_count + 1);
        test_count++;
        cache_flush = 1'b1;
        @(posedge clk);
        cache_flush = 1'b0;
        @(posedge clk);
        
        // Should miss after flush
        test_cache_request(32'h00001000, 1'b0, memory[32'h1000 >> 2], "After flush - should miss");
        wait_cache_ready();
        
        // Test 10: Cache invalidate test
        $display("Test %d: Cache invalidate test", test_count + 1);
        test_count++;
        cache_invalidate = 1'b1;
        @(posedge clk);
        cache_invalidate = 1'b0;
        @(posedge clk);
        
        // Should miss after invalidate
        test_cache_request(32'h00001000, 1'b0, memory[32'h1000 >> 2], "After invalidate - should miss");
        wait_cache_ready();
        
        // Test 11: Cache disabled test
        $display("Test %d: Cache disabled test", test_count + 1);
        test_count++;
        cache_enable = 1'b0;
        test_cache_request(32'h00003000, 1'b0, memory[32'h3000 >> 2], "Cache disabled - should not cache");
        cache_enable = 1'b1;
        
        // Test 12: Multiple different addresses (stress test)
        $display("\n=== Stress Test - Multiple Addresses ===");
        for (int i = 0; i < 10; i++) begin
            logic [31:0] test_addr;
            string test_desc;
            test_addr = 32'h00004000 + (i * 32'h100);
            test_desc = $sformatf("Stress test addr %d", i);
            test_cache_request(test_addr, 1'b0, memory[test_addr >> 2], test_desc);
            wait_cache_ready();
        end
        
        // Final statistics
        @(posedge clk);
        $display("\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        $display("\n=== Cache Statistics ===");
        $display("Cache Hits: %d", cache_hits);
        $display("Cache Misses: %d", cache_misses);
        $display("Hit Rate: %.1f%%", (cache_hits * 100.0) / (cache_hits + cache_misses));
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL CACHE TESTS PASSED!");
        end else begin
            $display("\n❌ SOME CACHE TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000; // 50us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule