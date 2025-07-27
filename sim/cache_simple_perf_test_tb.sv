// ARM7TDMI Simple Cache Performance Test
// Tests simple cache with performance monitoring integration

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module cache_simple_perf_test_tb;
    
    // Parameters
    localparam CACHE_SIZE_BYTES = 256;
    localparam CACHE_LINE_SIZE = 16;
    localparam ADDR_WIDTH = 32;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Simple cache signals
    logic [ADDR_WIDTH-1:0]  cpu_addr;
    logic                   cpu_req;
    logic                   cpu_write;
    logic [1:0]             cpu_size;
    logic [31:0]            cpu_wdata;
    logic [3:0]             cpu_byte_en;
    logic [31:0]            cpu_rdata;
    logic                   cpu_hit;
    logic                   cpu_ready;
    
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req;
    logic                   mem_write;
    logic [31:0]            mem_wdata;
    logic [3:0]             mem_byte_en;
    logic [31:0]            mem_rdata;
    logic                   mem_ready;
    
    logic                   cache_enable;
    logic                   cache_flush;
    
    logic [31:0]            cache_hits;
    logic [31:0]            cache_misses;
    logic                   cache_busy;
    
    // Performance monitor signals
    logic                   perf_reset;
    logic                   perf_enable;
    logic [3:0]             perf_sample_period;
    
    logic [31:0]            perf_total_accesses;
    logic [31:0]            perf_total_hits;
    logic [31:0]            perf_total_misses;
    logic [31:0]            perf_total_writes;
    logic [31:0]            perf_total_writebacks;
    logic [15:0]            perf_hit_rate_percent;
    logic [31:0]            perf_efficiency_metric;
    logic                   monitor_active;
    logic                   counters_overflow;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Simple memory model
    logic [31:0] memory [0:4095]; // 16KB memory
    
    initial begin
        for (int i = 0; i < 4096; i++) begin
            memory[i] = 32'hCAFE0000 + i;
        end
    end
    
    // Memory model behavior
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_rdata <= 32'h0;
        end else begin
            mem_ready <= 1'b1;
            if (mem_req && !mem_write) begin
                mem_rdata <= memory[mem_addr >> 2];
            end else if (mem_req && mem_write) begin
                if (mem_byte_en[0]) memory[mem_addr >> 2][7:0] <= mem_wdata[7:0];
                if (mem_byte_en[1]) memory[mem_addr >> 2][15:8] <= mem_wdata[15:8];
                if (mem_byte_en[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
                if (mem_byte_en[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
            end
        end
    end
    
    // Simple cache instantiation
    arm7tdmi_dcache_simple #(
        .CACHE_SIZE_BYTES(CACHE_SIZE_BYTES),
        .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dcache (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .cpu_addr               (cpu_addr),
        .cpu_req                (cpu_req),
        .cpu_write              (cpu_write),
        .cpu_size               (cpu_size),
        .cpu_wdata              (cpu_wdata),
        .cpu_byte_en            (cpu_byte_en),
        .cpu_rdata              (cpu_rdata),
        .cpu_hit                (cpu_hit),
        .cpu_ready              (cpu_ready),
        .mem_addr               (mem_addr),
        .mem_req                (mem_req),
        .mem_write              (mem_write),
        .mem_wdata              (mem_wdata),
        .mem_byte_en            (mem_byte_en),
        .mem_rdata              (mem_rdata),
        .mem_ready              (mem_ready),
        .cache_enable           (cache_enable),
        .cache_flush            (cache_flush),
        .coherency_addr         (),
        .coherency_write        (),
        .coherency_req          (),
        .coherency_ready        (),
        .cache_hits             (cache_hits),
        .cache_misses           (cache_misses),
        .cache_busy             (cache_busy)
    );
    
    // Performance monitor instantiation
    arm7tdmi_cache_perf_monitor #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_perf_monitor (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .icache_access              (1'b0),
        .icache_hit                 (1'b0),
        .icache_miss                (1'b0),
        .icache_eviction            (1'b0),
        .icache_fill                (1'b0),
        .icache_addr                (32'h0),
        .dcache_access              (cpu_req && cache_enable),
        .dcache_hit                 (cpu_hit && cpu_ready),
        .dcache_miss                (cpu_req && cache_enable && !cpu_hit && cpu_ready),
        .dcache_eviction            (1'b0),
        .dcache_fill                (mem_req && !mem_write),
        .dcache_write               (cpu_write && cpu_req && cache_enable),
        .dcache_writeback           (mem_req && mem_write),
        .dcache_addr                (cpu_addr),
        .coherency_invalidation     (1'b0),
        .coherency_conflict         (1'b0),
        .coherency_addr             (32'h0),
        .mmu_tlb_access             (1'b0),
        .mmu_tlb_hit                (1'b0),
        .mmu_tlb_miss               (1'b0),
        .mmu_page_fault             (1'b0),
        .mmu_asid_switch            (1'b0),
        .icache_total_accesses      (),
        .icache_total_hits          (),
        .icache_total_misses        (),
        .icache_total_evictions     (),
        .dcache_total_accesses      (perf_total_accesses),
        .dcache_total_hits          (perf_total_hits),
        .dcache_total_misses        (perf_total_misses),
        .dcache_total_evictions     (),
        .dcache_total_writes        (perf_total_writes),
        .dcache_total_writebacks    (perf_total_writebacks),
        .coherency_total_invalidations(),
        .coherency_total_conflicts  (),
        .mmu_total_accesses         (),
        .mmu_total_hits             (),
        .mmu_total_misses           (),
        .mmu_total_page_faults      (),
        .mmu_total_asid_switches    (),
        .icache_hit_rate_percent    (),
        .dcache_hit_rate_percent    (perf_hit_rate_percent),
        .mmu_hit_rate_percent       (),
        .total_memory_accesses      (),
        .cache_efficiency_metric    (perf_efficiency_metric),
        .perf_reset                 (perf_reset),
        .perf_enable                (perf_enable),
        .perf_sample_period         (perf_sample_period),
        .monitor_active             (monitor_active),
        .counters_overflow          (counters_overflow)
    );
    
    // Cache access task
    task cache_access(input [31:0] addr, input logic write, input [31:0] wdata);
        cpu_addr = addr;
        cpu_req = 1'b1;
        cpu_write = write;
        cpu_wdata = wdata;
        cpu_size = 2'b10;
        cpu_byte_en = 4'b1111;
        
        wait(cpu_ready);
        @(posedge clk);
        
        cpu_req = 1'b0;
        @(posedge clk);
    endtask
    
    task test_basic_cache_performance();
        test_count++;
        $display("Test %d: Basic Cache Performance Tracking", test_count);
        
        // Reset everything
        perf_reset = 1'b1;
        cache_flush = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        cache_flush = 1'b0;
        @(posedge clk);
        
        $display("  Generating cache misses...");
        
        // Create cache misses by accessing different cache lines
        for (int i = 0; i < 4; i++) begin
            cache_access(32'h1000 + (i * 256), 1'b0, 32'h0); // Different cache sets
        end
        
        $display("  Generating cache hits...");
        
        // Create cache hits by re-accessing same lines
        for (int i = 0; i < 4; i++) begin
            cache_access(32'h1000 + (i * 256), 1'b0, 32'h0); // Should hit
        end
        
        $display("  Testing write operations...");
        
        // Test write operations
        for (int i = 0; i < 2; i++) begin
            cache_access(32'h1000 + (i * 256), 1'b1, 32'hDEADBEEF + i);
        end
        
        // Wait for performance calculations
        repeat(32) @(posedge clk);
        
        $display("  Results:");
        $display("    Cache Module - Hits: %d, Misses: %d", cache_hits, cache_misses);
        $display("    Monitor - Accesses: %d, Hits: %d, Misses: %d", perf_total_accesses, perf_total_hits, perf_total_misses);
        $display("    Monitor - Writes: %d, Writebacks: %d", perf_total_writes, perf_total_writebacks);
        $display("    Hit Rate: %.2f%%", perf_hit_rate_percent / 100.0);
        $display("    Efficiency: %d%%", perf_efficiency_metric);
        
        // Verify counters make sense
        if (perf_total_accesses >= 10 && perf_total_hits > 0 && perf_total_misses > 0) begin
            test_passed++;
            $display("  ✅ PASS: Performance tracking working");
        end else begin
            $display("  ❌ FAIL: Performance tracking issues");
        end
    endtask
    
    task test_write_back_monitoring();
        test_count++;
        $display("Test %d: Write-Back Cache Performance", test_count);
        
        // Reset
        perf_reset = 1'b1;
        cache_flush = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        cache_flush = 1'b0;
        @(posedge clk);
        
        $display("  Testing write-back behavior...");
        
        // Fill cache with write data
        for (int i = 0; i < 8; i++) begin
            cache_access(32'h2000 + (i * 64), 1'b1, 32'hABCD0000 + i);
        end
        
        // Force evictions by accessing new data that maps to same cache lines
        for (int i = 0; i < 8; i++) begin
            cache_access(32'h6000 + (i * 64), 1'b0, 32'h0);
        end
        
        // Wait for write-backs to complete
        repeat(64) @(posedge clk);
        
        $display("  Write-back Results:");
        $display("    Total Writes: %d", perf_total_writes);
        $display("    Total Writebacks: %d", perf_total_writebacks);
        $display("    Hit Rate: %.2f%%", perf_hit_rate_percent / 100.0);
        
        if (perf_total_writes > 0) begin
            test_passed++;
            $display("  ✅ PASS: Write-back monitoring working");
        end else begin
            $display("  ❌ FAIL: Write-back monitoring failed");
        end
    endtask
    
    task test_cache_efficiency_calculation();
        test_count++;
        $display("Test %d: Cache Efficiency Calculation", test_count);
        
        // Reset
        perf_reset = 1'b1;
        cache_flush = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        cache_flush = 1'b0;
        @(posedge clk);
        
        // Create predictable pattern for efficiency test
        $display("  Creating high-locality access pattern...");
        
        // Access same small set of addresses multiple times (high hit rate)
        for (int round = 0; round < 5; round++) begin
            for (int i = 0; i < 4; i++) begin
                cache_access(32'h3000 + (i * 32), 1'b0, 32'h0);
            end
        end
        
        // Wait for efficiency calculation
        repeat(64) @(posedge clk);
        
        $display("  Efficiency Results:");
        $display("    Hit Rate: %.2f%%", perf_hit_rate_percent / 100.0);
        $display("    Efficiency: %d%%", perf_efficiency_metric);
        $display("    Total Accesses: %d", perf_total_accesses);
        
        // Should have high hit rate due to locality
        if (perf_hit_rate_percent > 5000) begin // > 50%
            test_passed++;
            $display("  ✅ PASS: High hit rate achieved with locality");
        end else begin
            $display("  ❌ FAIL: Hit rate lower than expected");
        end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("cache_simple_perf_test_tb.vcd");
        $dumpvars(0, cache_simple_perf_test_tb);
        
        // Initialize
        cpu_addr = 32'h0;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_size = 2'b10;
        cpu_wdata = 32'h0;
        cpu_byte_en = 4'b1111;
        cache_enable = 1'b1;
        cache_flush = 1'b0;
        
        perf_reset = 1'b0;
        perf_enable = 1'b1;
        perf_sample_period = 4'h4; // 16 cycle sample period
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        $display("=== ARM7TDMI Simple Cache Performance Test ===");
        $display("Cache Configuration:");
        $display("  Size: %d bytes", CACHE_SIZE_BYTES);
        $display("  Line Size: %d bytes", CACHE_LINE_SIZE);
        $display("  Lines: %d", CACHE_SIZE_BYTES / CACHE_LINE_SIZE);
        $display("  Direct-mapped cache");
        
        // Run tests
        test_basic_cache_performance();
        test_write_back_monitoring();
        test_cache_efficiency_calculation();
        
        // Final results
        $display("\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL SIMPLE CACHE PERFORMANCE TESTS PASSED!");
        end else begin
            $display("\n❌ SOME SIMPLE CACHE PERFORMANCE TESTS FAILED");
        end
        
        $display("\nFinal System Status:");
        $display("  Cache Busy: %b", cache_busy);
        $display("  Monitor Active: %b", monitor_active);
        $display("  Counters Overflow: %b", counters_overflow);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule