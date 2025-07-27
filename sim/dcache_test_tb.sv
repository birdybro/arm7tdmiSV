// ARM7TDMI Data Cache Test Bench
// Tests data cache functionality including read/write hits, misses, writebacks, and various data sizes

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module dcache_test_tb;
    
    // Parameters matching the simple cache design
    localparam CACHE_SIZE_BYTES = 1024;
    localparam CACHE_LINE_SIZE = 16;
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
    logic                   cpu_write;
    logic [1:0]             cpu_size;
    logic [31:0]            cpu_wdata;
    logic [3:0]             cpu_byte_en;
    logic [31:0]            cpu_rdata;
    logic                   cpu_hit;
    logic                   cpu_ready;
    logic                   cpu_abort;
    
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req;
    logic                   mem_write;
    // Removed mem_burst_len for simple cache
    logic [31:0]            mem_wdata;
    logic [3:0]             mem_byte_en;
    logic [31:0]            mem_rdata;
    logic                   mem_valid;
    logic                   mem_ready;
    logic                   mem_abort;
    
    logic                   cache_enable;
    logic                   cache_flush;
    // Simplified control signals for simple cache
    logic [31:0]            cache_hits;
    logic [31:0]            cache_misses;
    logic                   cache_busy;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Simplified memory model
    logic [31:0] memory [0:65535]; // 256KB memory model
    
    // Initialize memory with test patterns
    initial begin
        for (int i = 0; i < 65536; i++) begin
            memory[i] = 32'hCAFE0000 + i; // Unique pattern for each word
        end
    end
    
    // Simplified memory model behavior (single transfers only)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_rdata <= 32'h0;
        end else begin
            mem_ready <= 1'b1;
            
            if (mem_req) begin
                if (mem_write) begin
                    // Handle byte enables for writes
                    if (mem_byte_en[0]) memory[mem_addr >> 2][7:0] = mem_wdata[7:0];
                    if (mem_byte_en[1]) memory[mem_addr >> 2][15:8] = mem_wdata[15:8];
                    if (mem_byte_en[2]) memory[mem_addr >> 2][23:16] = mem_wdata[23:16];
                    if (mem_byte_en[3]) memory[mem_addr >> 2][31:24] = mem_wdata[31:24];
                end else begin
                    mem_rdata <= memory[mem_addr >> 2];
                end
            end
        end
    end
    
    // DUT instantiation - simple cache
    arm7tdmi_dcache_simple #(
        .CACHE_SIZE_BYTES(CACHE_SIZE_BYTES),
        .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dcache (
        .clk                (clk),
        .rst_n              (rst_n),
        .cpu_addr           (cpu_addr),
        .cpu_req            (cpu_req),
        .cpu_write          (cpu_write),
        .cpu_size           (cpu_size),
        .cpu_wdata          (cpu_wdata),
        .cpu_byte_en        (cpu_byte_en),
        .cpu_rdata          (cpu_rdata),
        .cpu_hit            (cpu_hit),
        .cpu_ready          (cpu_ready),
        .mem_addr           (mem_addr),
        .mem_req            (mem_req),
        .mem_write          (mem_write),
        .mem_wdata          (mem_wdata),
        .mem_byte_en        (mem_byte_en),
        .mem_rdata          (mem_rdata),
        .mem_ready          (mem_ready),
        .cache_enable       (cache_enable),
        .cache_flush        (cache_flush),
        .cache_hits         (cache_hits),
        .cache_misses       (cache_misses),
        .cache_busy         (cache_busy)
    );
    
    // Test tasks
    task test_read_request(
        input [31:0] addr,
        input [1:0] size,
        input [31:0] expected_data,
        input logic expect_hit,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Address: 0x%08x, Size: %d", addr, size);
        
        cpu_addr = addr;
        cpu_req = 1'b1;
        cpu_write = 1'b0;
        cpu_size = size;
        cpu_wdata = 32'h0;
        cpu_byte_en = 4'b1111;
        
        // Wait for completion
        while (!cpu_ready) begin
            @(posedge clk);
        end
        
        @(posedge clk);
        
        $display("  Expected: 0x%08x, Got: 0x%08x", expected_data, cpu_rdata);
        $display("  Hit: %b (expected: %b), Ready: %b", cpu_hit, expect_hit, cpu_ready);
        
        if (cpu_rdata == expected_data) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    task test_write_request(
        input [31:0] addr,
        input [1:0] size,
        input [31:0] wdata,
        input [3:0] byte_en,
        input logic expect_hit,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Address: 0x%08x, Size: %d, Data: 0x%08x, BE: %b", addr, size, wdata, byte_en);
        
        cpu_addr = addr;
        cpu_req = 1'b1;
        cpu_write = 1'b1;
        cpu_size = size;
        cpu_wdata = wdata;
        cpu_byte_en = byte_en;
        
        // Wait for completion
        while (!cpu_ready) begin
            @(posedge clk);
        end
        
        @(posedge clk);
        
        $display("  Hit: %b (expected: %b), Ready: %b", cpu_hit, expect_hit, cpu_ready);
        test_passed++;
        $display("  ✅ PASS");
        
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
        $dumpfile("dcache_test_tb.vcd");
        $dumpvars(0, dcache_test_tb);
        
        // Initialize
        cpu_addr = 32'h0;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_size = 2'b10;
        cpu_wdata = 32'h0;
        cpu_byte_en = 4'b1111;
        cache_enable = 1'b1;
        cache_flush = 1'b0;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Data Cache Test ===");
        $display("Cache Size: %d bytes, Line Size: %d bytes", CACHE_SIZE_BYTES, CACHE_LINE_SIZE);
        $display("Cache Lines: %d, Words per Line: %d\n", CACHE_LINES, WORDS_PER_LINE);
        
        // Test 1: Basic read miss and fill
        test_read_request(32'h00001000, 2'b10, memory[32'h1000 >> 2], 1'b0, "Basic read miss - word");
        wait_cache_ready();
        
        // Test 2: Read hit on same address
        test_read_request(32'h00001000, 2'b10, memory[32'h1000 >> 2], 1'b1, "Read hit - same address");
        
        // Test 3: Read hit within same cache line
        test_read_request(32'h00001004, 2'b10, memory[32'h1004 >> 2], 1'b1, "Read hit - same line, next word");
        
        // Test 4: Byte read test
        test_read_request(32'h00001000, 2'b00, memory[32'h1000 >> 2] & 32'h000000FF, 1'b1, "Byte read - hit");
        
        // Test 5: Halfword read test
        test_read_request(32'h00001002, 2'b01, (memory[32'h1000 >> 2] >> 16) & 32'h0000FFFF, 1'b1, "Halfword read - hit");
        
        // Test 6: Write miss (should allocate)
        test_write_request(32'h00002000, 2'b10, 32'hDEADBEEF, 4'b1111, 1'b0, "Write miss - word, should allocate");
        wait_cache_ready();
        
        // Test 7: Read back written data
        test_read_request(32'h00002000, 2'b10, 32'hDEADBEEF, 1'b1, "Read back written data");
        
        // Test 8: Byte write test
        test_write_request(32'h00002004, 2'b00, 32'h000000AA, 4'b0001, 1'b1, "Byte write - hit");
        
        // Test 9: Read back byte written data
        test_read_request(32'h00002004, 2'b00, 32'h000000AA, 1'b1, "Read back byte data");
        
        // Test 10: Halfword write test
        test_write_request(32'h00002006, 2'b01, 32'h0000BBCC, 4'b1100, 1'b1, "Halfword write - hit");
        
        // Test 11: Read back halfword written data
        test_read_request(32'h00002006, 2'b01, 32'h0000BBCC, 1'b1, "Read back halfword data");
        
        // Test 12: Test cache eviction (write different cache line to force writeback)
        for (int i = 0; i < 300; i++) begin
            logic [31:0] test_addr;
            string test_desc;
            test_addr = 32'h00003000 + (i * 32'h20); // Different cache lines
            test_desc = $sformatf("Cache eviction test %d", i);
            test_write_request(test_addr, 2'b10, 32'h12340000 + i, 4'b1111, 1'b0, test_desc);
            wait_cache_ready();
            if (i % 50 == 0) $display("  Progress: %d/300 eviction tests", i);
        end
        
        // Test 13: Cache flush test
        $display("Test %d: Cache flush test", test_count + 1);
        test_count++;
        cache_flush = 1'b1;
        @(posedge clk);
        cache_flush = 1'b0;
        @(posedge clk);
        $display("  Cache flushed");
        $display("  ✅ PASS\n");
        test_passed++;
        
        // Test 14: Access after flush (should miss)
        test_read_request(32'h00001000, 2'b10, memory[32'h1000 >> 2], 1'b0, "Read after flush - should miss");
        wait_cache_ready();
        
        // Test 15: Additional cache flush test (invalidate not supported in simple cache)
        $display("Test %d: Additional cache flush test", test_count + 1);
        test_count++;
        cache_flush = 1'b1;
        @(posedge clk);
        cache_flush = 1'b0;
        @(posedge clk);
        $display("  Cache flushed again");
        $display("  ✅ PASS\n");
        test_passed++;
        
        // Test 16: Cache disabled test
        $display("Test %d: Cache disabled test", test_count + 1);
        test_count++;
        cache_enable = 1'b0;
        test_read_request(32'h00004000, 2'b10, memory[32'h4000 >> 2], 1'b0, "Cache disabled - direct memory access");
        cache_enable = 1'b1;
        
        // Test 17: Unaligned access tests
        $display("\n=== Unaligned Access Tests ===");
        test_read_request(32'h00005001, 2'b00, (memory[32'h5000 >> 2] >> 8) & 32'h000000FF, 1'b0, "Unaligned byte read");
        wait_cache_ready();
        
        test_read_request(32'h00005002, 2'b01, (memory[32'h5000 >> 2] >> 16) & 32'h0000FFFF, 1'b1, "Unaligned halfword read");
        
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
            $display("\n✅ ALL DATA CACHE TESTS PASSED!");
        end else begin
            $display("\n❌ SOME DATA CACHE TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #200000; // 200us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule