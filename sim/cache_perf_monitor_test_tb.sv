// ARM7TDMI Cache Performance Monitor Test Bench
// Tests comprehensive cache performance monitoring functionality

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module cache_perf_monitor_test_tb;
    
    // Parameters
    localparam ADDR_WIDTH = 32;
    localparam NUM_COUNTERS = 16;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // DUT signals
    logic                    icache_access;
    logic                    icache_hit;
    logic                    icache_miss;
    logic                    icache_eviction;
    logic                    icache_fill;
    logic [ADDR_WIDTH-1:0]  icache_addr;
    
    logic                    dcache_access;
    logic                    dcache_hit;
    logic                    dcache_miss;
    logic                    dcache_eviction;
    logic                    dcache_fill;
    logic                    dcache_write;
    logic                    dcache_writeback;
    logic [ADDR_WIDTH-1:0]  dcache_addr;
    
    logic                    coherency_invalidation;
    logic                    coherency_conflict;
    logic [ADDR_WIDTH-1:0]  coherency_addr;
    
    logic                    mmu_tlb_access;
    logic                    mmu_tlb_hit;
    logic                    mmu_tlb_miss;
    logic                    mmu_page_fault;
    logic                    mmu_asid_switch;
    
    logic [31:0]             icache_total_accesses;
    logic [31:0]             icache_total_hits;
    logic [31:0]             icache_total_misses;
    logic [31:0]             icache_total_evictions;
    
    logic [31:0]             dcache_total_accesses;
    logic [31:0]             dcache_total_hits;
    logic [31:0]             dcache_total_misses;
    logic [31:0]             dcache_total_evictions;
    logic [31:0]             dcache_total_writes;
    logic [31:0]             dcache_total_writebacks;
    
    logic [31:0]             coherency_total_invalidations;
    logic [31:0]             coherency_total_conflicts;
    
    logic [31:0]             mmu_total_accesses;
    logic [31:0]             mmu_total_hits;
    logic [31:0]             mmu_total_misses;
    logic [31:0]             mmu_total_page_faults;
    logic [31:0]             mmu_total_asid_switches;
    
    logic [15:0]             icache_hit_rate_percent;
    logic [15:0]             dcache_hit_rate_percent;
    logic [15:0]             mmu_hit_rate_percent;
    
    logic [31:0]             total_memory_accesses;
    logic [31:0]             cache_efficiency_metric;
    
    logic                    perf_reset;
    logic                    perf_enable;
    logic [3:0]              perf_sample_period;
    
    logic                    monitor_active;
    logic                    counters_overflow;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // DUT instantiation
    arm7tdmi_cache_perf_monitor #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_COUNTERS(NUM_COUNTERS)
    ) u_perf_monitor (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .icache_access              (icache_access),
        .icache_hit                 (icache_hit),
        .icache_miss                (icache_miss),
        .icache_eviction            (icache_eviction),
        .icache_fill                (icache_fill),
        .icache_addr                (icache_addr),
        .dcache_access              (dcache_access),
        .dcache_hit                 (dcache_hit),
        .dcache_miss                (dcache_miss),
        .dcache_eviction            (dcache_eviction),
        .dcache_fill                (dcache_fill),
        .dcache_write               (dcache_write),
        .dcache_writeback           (dcache_writeback),
        .dcache_addr                (dcache_addr),
        .coherency_invalidation     (coherency_invalidation),
        .coherency_conflict         (coherency_conflict),
        .coherency_addr             (coherency_addr),
        .mmu_tlb_access             (mmu_tlb_access),
        .mmu_tlb_hit                (mmu_tlb_hit),
        .mmu_tlb_miss               (mmu_tlb_miss),
        .mmu_page_fault             (mmu_page_fault),
        .mmu_asid_switch            (mmu_asid_switch),
        .icache_total_accesses      (icache_total_accesses),
        .icache_total_hits          (icache_total_hits),
        .icache_total_misses        (icache_total_misses),
        .icache_total_evictions     (icache_total_evictions),
        .dcache_total_accesses      (dcache_total_accesses),
        .dcache_total_hits          (dcache_total_hits),
        .dcache_total_misses        (dcache_total_misses),
        .dcache_total_evictions     (dcache_total_evictions),
        .dcache_total_writes        (dcache_total_writes),
        .dcache_total_writebacks    (dcache_total_writebacks),
        .coherency_total_invalidations(coherency_total_invalidations),
        .coherency_total_conflicts  (coherency_total_conflicts),
        .mmu_total_accesses         (mmu_total_accesses),
        .mmu_total_hits             (mmu_total_hits),
        .mmu_total_misses           (mmu_total_misses),
        .mmu_total_page_faults      (mmu_total_page_faults),
        .mmu_total_asid_switches    (mmu_total_asid_switches),
        .icache_hit_rate_percent    (icache_hit_rate_percent),
        .dcache_hit_rate_percent    (dcache_hit_rate_percent),
        .mmu_hit_rate_percent       (mmu_hit_rate_percent),
        .total_memory_accesses      (total_memory_accesses),
        .cache_efficiency_metric    (cache_efficiency_metric),
        .perf_reset                 (perf_reset),
        .perf_enable                (perf_enable),
        .perf_sample_period         (perf_sample_period),
        .monitor_active             (monitor_active),
        .counters_overflow          (counters_overflow)
    );
    
    // Task to simulate cache events
    task simulate_icache_access(input logic hit);
        icache_access = 1'b1;
        icache_addr = $random;
        @(posedge clk);
        
        if (hit) begin
            icache_hit = 1'b1;
        end else begin
            icache_miss = 1'b1;
            @(posedge clk);
            icache_fill = 1'b1;
        end
        @(posedge clk);
        
        // Clear signals
        icache_access = 1'b0;
        icache_hit = 1'b0;
        icache_miss = 1'b0;
        icache_fill = 1'b0;
        @(posedge clk);
    endtask
    
    task simulate_dcache_access(input logic hit, input logic write_op);
        dcache_access = 1'b1;
        dcache_write = write_op;
        dcache_addr = $random;
        @(posedge clk);
        
        if (hit) begin
            dcache_hit = 1'b1;
        end else begin
            dcache_miss = 1'b1;
            @(posedge clk);
            dcache_fill = 1'b1;
            if (write_op) begin
                dcache_writeback = 1'b1;
            end
        end
        @(posedge clk);
        
        // Clear signals
        dcache_access = 1'b0;
        dcache_hit = 1'b0;
        dcache_miss = 1'b0;
        dcache_fill = 1'b0;
        dcache_write = 1'b0;
        dcache_writeback = 1'b0;
        @(posedge clk);
    endtask
    
    task simulate_mmu_access(input logic hit);
        mmu_tlb_access = 1'b1;
        @(posedge clk);
        
        if (hit) begin
            mmu_tlb_hit = 1'b1;
        end else begin
            mmu_tlb_miss = 1'b1;
        end
        @(posedge clk);
        
        // Clear signals
        mmu_tlb_access = 1'b0;
        mmu_tlb_hit = 1'b0;
        mmu_tlb_miss = 1'b0;
        @(posedge clk);
    endtask
    
    task test_basic_counting();
        test_count++;
        $display("Test %d: Basic Counter Functionality", test_count);
        
        // Reset counters
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        @(posedge clk);
        
        // Simulate some cache accesses
        simulate_icache_access(1'b1); // Hit
        simulate_icache_access(1'b0); // Miss
        simulate_icache_access(1'b1); // Hit
        
        simulate_dcache_access(1'b1, 1'b0); // Read hit
        simulate_dcache_access(1'b0, 1'b1); // Write miss
        simulate_dcache_access(1'b1, 1'b1); // Write hit
        
        simulate_mmu_access(1'b1); // Hit
        simulate_mmu_access(1'b0); // Miss
        
        // Check counters
        if (icache_total_accesses == 3 && icache_total_hits == 2 && icache_total_misses == 1 &&
            dcache_total_accesses == 3 && dcache_total_hits == 2 && dcache_total_misses == 1 &&
            dcache_total_writes == 2 && mmu_total_accesses == 2 && mmu_total_hits == 1) begin
            test_passed++;
            $display("  ✅ PASS: Basic counters working correctly");
        end else begin
            $display("  ❌ FAIL: Counter mismatch");
            $display("    ICache: acc=%d, hit=%d, miss=%d", icache_total_accesses, icache_total_hits, icache_total_misses);
            $display("    DCache: acc=%d, hit=%d, miss=%d, wr=%d", dcache_total_accesses, dcache_total_hits, dcache_total_misses, dcache_total_writes);
            $display("    MMU: acc=%d, hit=%d", mmu_total_accesses, mmu_total_hits);
        end
    endtask
    
    task test_hit_rate_calculation();
        test_count++;
        $display("Test %d: Hit Rate Calculation", test_count);
        
        // Reset counters
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        @(posedge clk);
        
        // Create pattern with known hit rate: 8 hits out of 10 accesses = 80%
        for (int i = 0; i < 8; i++) begin
            simulate_icache_access(1'b1); // Hit
        end
        for (int i = 0; i < 2; i++) begin
            simulate_icache_access(1'b0); // Miss
        end
        
        // Wait for sample period
        repeat(32) @(posedge clk);
        
        // Check if hit rate is approximately 80% (8000 in 0.01% units)
        if (icache_hit_rate_percent >= 7900 && icache_hit_rate_percent <= 8100) begin
            test_passed++;
            $display("  ✅ PASS: Hit rate calculation working (%.2f%%)", icache_hit_rate_percent / 100.0);
        end else begin
            $display("  ❌ FAIL: Hit rate incorrect: %d (expected ~8000)", icache_hit_rate_percent);
        end
    endtask
    
    task test_performance_disable();
        logic [31:0] initial_accesses;
        
        test_count++;
        $display("Test %d: Performance Monitor Disable", test_count);
        
        // Reset and get initial counter values
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        @(posedge clk);
        
        initial_accesses = icache_total_accesses;
        
        // Disable monitoring
        perf_enable = 1'b0;
        @(posedge clk);
        
        // Simulate accesses (should not be counted)
        simulate_icache_access(1'b1);
        simulate_icache_access(1'b1);
        
        // Check that counters didn't change
        if (icache_total_accesses == initial_accesses) begin
            test_passed++;
            $display("  ✅ PASS: Counters stopped when disabled");
        end else begin
            $display("  ❌ FAIL: Counters still active when disabled");
        end
        
        // Re-enable for remaining tests
        perf_enable = 1'b1;
        @(posedge clk);
    endtask
    
    task test_coherency_monitoring();
        test_count++;
        $display("Test %d: Coherency Event Monitoring", test_count);
        
        // Reset counters
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        @(posedge clk);
        
        // Simulate coherency events
        coherency_invalidation = 1'b1;
        coherency_addr = 32'h1000;
        @(posedge clk);
        coherency_invalidation = 1'b0;
        
        coherency_conflict = 1'b1;
        coherency_addr = 32'h2000;
        @(posedge clk);
        coherency_conflict = 1'b0;
        
        coherency_invalidation = 1'b1;
        coherency_addr = 32'h3000;
        @(posedge clk);
        coherency_invalidation = 1'b0;
        
        @(posedge clk);
        
        // Check coherency counters
        if (coherency_total_invalidations == 2 && coherency_total_conflicts == 1) begin
            test_passed++;
            $display("  ✅ PASS: Coherency events counted correctly");
        end else begin
            $display("  ❌ FAIL: Coherency counter mismatch");
            $display("    Invalidations: %d (expected 2)", coherency_total_invalidations);
            $display("    Conflicts: %d (expected 1)", coherency_total_conflicts);
        end
    endtask
    
    task test_efficiency_metric();
        test_count++;
        $display("Test %d: Cache Efficiency Metric", test_count);
        
        // Reset counters
        perf_reset = 1'b1;
        @(posedge clk);
        perf_reset = 1'b0;
        @(posedge clk);
        
        // Create specific pattern for efficiency calculation
        // ICache: 4 hits out of 5 accesses (80%)
        for (int i = 0; i < 4; i++) begin
            simulate_icache_access(1'b1);
        end
        simulate_icache_access(1'b0);
        
        // DCache: 3 hits out of 5 accesses (60%)
        for (int i = 0; i < 3; i++) begin
            simulate_dcache_access(1'b1, 1'b0);
        end
        for (int i = 0; i < 2; i++) begin
            simulate_dcache_access(1'b0, 1'b0);
        end
        
        // Wait for efficiency calculation
        repeat(32) @(posedge clk);
        
        // Efficiency = (4*40 + 3*60) / 100 / 10 * 100 = (160 + 180) / 1000 = 34%
        if (cache_efficiency_metric >= 30 && cache_efficiency_metric <= 40) begin
            test_passed++;
            $display("  ✅ PASS: Efficiency metric reasonable (%d%%)", cache_efficiency_metric);
        end else begin
            $display("  ❌ FAIL: Efficiency metric unexpected: %d%%", cache_efficiency_metric);
        end
        
        $display("  Total memory accesses: %d", total_memory_accesses);
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("cache_perf_monitor_test_tb.vcd");
        $dumpvars(0, cache_perf_monitor_test_tb);
        
        // Initialize
        icache_access = 1'b0;
        icache_hit = 1'b0;
        icache_miss = 1'b0;
        icache_eviction = 1'b0;
        icache_fill = 1'b0;
        icache_addr = 32'h0;
        
        dcache_access = 1'b0;
        dcache_hit = 1'b0;
        dcache_miss = 1'b0;
        dcache_eviction = 1'b0;
        dcache_fill = 1'b0;
        dcache_write = 1'b0;
        dcache_writeback = 1'b0;
        dcache_addr = 32'h0;
        
        coherency_invalidation = 1'b0;
        coherency_conflict = 1'b0;
        coherency_addr = 32'h0;
        
        mmu_tlb_access = 1'b0;
        mmu_tlb_hit = 1'b0;
        mmu_tlb_miss = 1'b0;
        mmu_page_fault = 1'b0;
        mmu_asid_switch = 1'b0;
        
        perf_reset = 1'b0;
        perf_enable = 1'b1;
        perf_sample_period = 4'h4; // 16 cycle sample period
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Cache Performance Monitor Test ===");
        
        // Run tests
        test_basic_counting();
        test_hit_rate_calculation();
        test_performance_disable();
        test_coherency_monitoring();
        test_efficiency_metric();
        
        // Final results
        $display("\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL CACHE PERFORMANCE MONITOR TESTS PASSED!");
        end else begin
            $display("\n❌ SOME CACHE PERFORMANCE MONITOR TESTS FAILED");
        end
        
        $display("\nFinal Performance Statistics:");
        $display("  Monitor Active: %b", monitor_active);
        $display("  Counters Overflow: %b", counters_overflow);
        $display("  ICache Hit Rate: %.2f%%", icache_hit_rate_percent / 100.0);
        $display("  DCache Hit Rate: %.2f%%", dcache_hit_rate_percent / 100.0);
        $display("  MMU Hit Rate: %.2f%%", mmu_hit_rate_percent / 100.0);
        $display("  Cache Efficiency: %d%%", cache_efficiency_metric);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule