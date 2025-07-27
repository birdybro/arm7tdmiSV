// ARM7TDMI Integrated Cache Performance Test
// Tests enhanced cache with performance monitoring integration

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module cache_integrated_perf_test_tb;
    
    // Parameters
    localparam CACHE_SIZE_BYTES = 256;
    localparam CACHE_LINE_SIZE = 16;
    localparam CACHE_WAYS = 2;
    localparam ADDR_WIDTH = 32;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Enhanced cache signals
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
    logic [1:0]             replacement_select;
    
    logic [31:0]            cache_hits;
    logic [31:0]            cache_misses;
    logic [31:0]            cache_evictions;
    logic                   cache_busy;
    
    // Performance monitor signals
    logic                   perf_reset;
    logic                   perf_enable;
    logic [3:0]             perf_sample_period;
    
    logic [31:0]            perf_total_accesses;
    logic [31:0]            perf_total_hits;
    logic [31:0]            perf_total_misses;
    logic [15:0]            perf_hit_rate_percent;
    logic [31:0]            perf_efficiency_metric;
    logic                   monitor_active;
    logic                   counters_overflow;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Simple memory model
    logic [31:0] memory [0:16383]; // 64KB memory
    
    initial begin
        for (int i = 0; i < 16384; i++) begin
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
    
    // Enhanced cache instantiation
    arm7tdmi_dcache_enhanced #(
        .CACHE_SIZE_BYTES(CACHE_SIZE_BYTES),
        .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
        .CACHE_WAYS(CACHE_WAYS),
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
        .replacement_select     (replacement_select),
        .cache_hits             (cache_hits),
        .cache_misses           (cache_misses),
        .cache_evictions        (cache_evictions),
        .lru_replacements       (),
        .lfu_replacements       (),
        .random_replacements    (),
        .rr_replacements        (),
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
        .dcache_hit                 (cpu_hit),
        .dcache_miss                (cpu_req && cache_enable && !cpu_hit && cpu_ready),
        .dcache_eviction            (1'b0), // Simple for this test
        .dcache_fill                (mem_req && !mem_write),
        .dcache_write               (cpu_write && cpu_req),
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
        .dcache_total_writes        (),
        .dcache_total_writebacks    (),
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
    
    task test_cache_performance_tracking();
        test_count++;
        $display("Test %d: Cache Performance Integration", test_count);
        
        // Reset performance monitor
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        @(posedge clk);
        
        // Flush cache
        cache_flush = 1'b1;
        @(posedge clk);
        cache_flush = 1'b0;
        @(posedge clk);
        
        $display("  Testing cache miss patterns...");
        
        // Create predictable pattern: sequential accesses that will cause misses and hits
        for (int i = 0; i < 8; i++) begin
            cache_access(32'h1000 + (i * 64), 1'b0, 32'h0); // Different cache sets
        end
        
        $display("  Testing cache hit patterns...");
        
        // Repeat some accesses to create hits
        for (int i = 0; i < 4; i++) begin
            cache_access(32'h1000 + (i * 64), 1'b0, 32'h0); // Should hit
        end
        
        $display("  Testing write patterns...");
        
        // Test writes
        for (int i = 0; i < 4; i++) begin
            cache_access(32'h1000 + (i * 64), 1'b1, 32'hDEADBEEF + i);
        end
        
        // Wait for performance calculations
        repeat(32) @(posedge clk);
        
        // Check results
        $display("  Performance Results:");
        $display("    Cache Hits: %d", cache_hits);
        $display("    Cache Misses: %d", cache_misses);
        $display("    Monitor Hits: %d", perf_total_hits);
        $display("    Monitor Misses: %d", perf_total_misses);
        $display("    Hit Rate: %.2f%%", perf_hit_rate_percent / 100.0);
        $display("    Efficiency: %d%%", perf_efficiency_metric);
        
        // Basic sanity checks
        if (perf_total_accesses > 0 && perf_hit_rate_percent > 0) begin
            test_passed++;
            $display("  ✅ PASS: Performance tracking functional");
        end else begin
            $display("  ❌ FAIL: Performance tracking issues");
        end
    endtask
    
    task test_replacement_policy_performance();
        logic [15:0] lru_hit_rate, lfu_hit_rate, rr_hit_rate;
        
        test_count++;
        $display("Test %d: Replacement Policy Performance Comparison", test_count);
        
        // Test LRU policy
        $display("  Testing LRU policy...");
        replacement_select = 2'b00; // LRU
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        cache_flush = 1'b1;
        @(posedge clk);
        cache_flush = 1'b0;
        @(posedge clk);
        
        // Create working set larger than cache
        for (int i = 0; i < 32; i++) begin
            cache_access(32'h2000 + (i * 32), 1'b0, 32'h0);
        end
        
        repeat(32) @(posedge clk);
        lru_hit_rate = perf_hit_rate_percent;
        
        // Test Round-Robin policy
        $display("  Testing Round-Robin policy...");
        replacement_select = 2'b11; // Round-Robin
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        cache_flush = 1'b1;
        @(posedge clk);
        cache_flush = 1'b0;
        @(posedge clk);
        
        // Same access pattern
        for (int i = 0; i < 32; i++) begin
            cache_access(32'h2000 + (i * 32), 1'b0, 32'h0);
        end
        
        repeat(32) @(posedge clk);
        rr_hit_rate = perf_hit_rate_percent;
        
        $display("  Policy Comparison:");
        $display("    LRU Hit Rate: %.2f%%", lru_hit_rate / 100.0);
        $display("    Round-Robin Hit Rate: %.2f%%", rr_hit_rate / 100.0);
        
        if (lru_hit_rate > 0 && rr_hit_rate > 0) begin
            test_passed++;
            $display("  ✅ PASS: Policy performance comparison working");
        end else begin
            $display("  ❌ FAIL: Policy performance comparison failed");
        end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("cache_integrated_perf_test_tb.vcd");
        $dumpvars(0, cache_integrated_perf_test_tb);
        
        // Initialize
        cpu_addr = 32'h0;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_size = 2'b10;
        cpu_wdata = 32'h0;
        cpu_byte_en = 4'b1111;
        cache_enable = 1'b1;
        cache_flush = 1'b0;
        replacement_select = 2'b00; // LRU
        
        perf_reset = 1'b0;
        perf_enable = 1'b1;
        perf_sample_period = 4'h4; // 16 cycle sample period
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        $display("=== ARM7TDMI Integrated Cache Performance Test ===");
        $display("Cache Configuration:");
        $display("  Size: %d bytes", CACHE_SIZE_BYTES);
        $display("  Line Size: %d bytes", CACHE_LINE_SIZE);
        $display("  Ways: %d", CACHE_WAYS);
        $display("  Sets: %d", CACHE_SIZE_BYTES / (CACHE_LINE_SIZE * CACHE_WAYS));
        
        // Run tests
        test_cache_performance_tracking();
        test_replacement_policy_performance();
        
        // Final results
        $display("\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL INTEGRATED CACHE PERFORMANCE TESTS PASSED!");
        end else begin
            $display("\n❌ SOME INTEGRATED CACHE PERFORMANCE TESTS FAILED");
        end
        
        $display("\nFinal System Status:");
        $display("  Cache Busy: %b", cache_busy);
        $display("  Monitor Active: %b", monitor_active);
        $display("  Counters Overflow: %b", counters_overflow);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #200000; // 200us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule