// ARM7TDMI Cache Performance Monitor
// Comprehensive statistics collection and performance analysis for cache subsystem

import arm7tdmi_pkg::*;

module arm7tdmi_cache_perf_monitor #(
    parameter ADDR_WIDTH = 32,
    parameter NUM_COUNTERS = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Cache events from instruction cache
    input  logic                    icache_access,
    input  logic                    icache_hit,
    input  logic                    icache_miss,
    input  logic                    icache_eviction,
    input  logic                    icache_fill,
    input  logic [ADDR_WIDTH-1:0]  icache_addr,
    
    // Cache events from data cache
    input  logic                    dcache_access,
    input  logic                    dcache_hit,
    input  logic                    dcache_miss,
    input  logic                    dcache_eviction,
    input  logic                    dcache_fill,
    input  logic                    dcache_write,
    input  logic                    dcache_writeback,
    input  logic [ADDR_WIDTH-1:0]  dcache_addr,
    
    // Coherency events
    input  logic                    coherency_invalidation,
    input  logic                    coherency_conflict,
    input  logic [ADDR_WIDTH-1:0]  coherency_addr,
    
    // MMU events
    input  logic                    mmu_tlb_access,
    input  logic                    mmu_tlb_hit,
    input  logic                    mmu_tlb_miss,
    input  logic                    mmu_page_fault,
    input  logic                    mmu_asid_switch,
    
    // Performance counters output
    output logic [31:0]             icache_total_accesses,
    output logic [31:0]             icache_total_hits,
    output logic [31:0]             icache_total_misses,
    output logic [31:0]             icache_total_evictions,
    
    output logic [31:0]             dcache_total_accesses,
    output logic [31:0]             dcache_total_hits,
    output logic [31:0]             dcache_total_misses,
    output logic [31:0]             dcache_total_evictions,
    output logic [31:0]             dcache_total_writes,
    output logic [31:0]             dcache_total_writebacks,
    
    output logic [31:0]             coherency_total_invalidations,
    output logic [31:0]             coherency_total_conflicts,
    
    output logic [31:0]             mmu_total_accesses,
    output logic [31:0]             mmu_total_hits,
    output logic [31:0]             mmu_total_misses,
    output logic [31:0]             mmu_total_page_faults,
    output logic [31:0]             mmu_total_asid_switches,
    
    // Calculated metrics
    output logic [15:0]             icache_hit_rate_percent,    // Hit rate as percentage (0-10000 = 0.00%-100.00%)
    output logic [15:0]             dcache_hit_rate_percent,
    output logic [15:0]             mmu_hit_rate_percent,
    
    // Performance analysis
    output logic [31:0]             total_memory_accesses,
    output logic [31:0]             cache_efficiency_metric,    // Combined cache efficiency score
    
    // Control interface
    input  logic                    perf_reset,                 // Reset all counters
    input  logic                    perf_enable,                // Enable performance monitoring
    input  logic [3:0]              perf_sample_period,         // Sample period for calculated metrics (2^N cycles)
    
    // Debug and status
    output logic                    monitor_active,
    output logic                    counters_overflow           // Any counter has overflowed
);

    // Internal performance counters
    logic [31:0] icache_accesses;
    logic [31:0] icache_hits;
    logic [31:0] icache_misses;
    logic [31:0] icache_evictions;
    
    logic [31:0] dcache_accesses;
    logic [31:0] dcache_hits;
    logic [31:0] dcache_misses;
    logic [31:0] dcache_evictions;
    logic [31:0] dcache_writes;
    logic [31:0] dcache_writebacks;
    
    logic [31:0] coherency_invalidations;
    logic [31:0] coherency_conflicts;
    
    logic [31:0] mmu_accesses;
    logic [31:0] mmu_hits;
    logic [31:0] mmu_misses;
    logic [31:0] mmu_page_faults;
    logic [31:0] mmu_asid_switches;
    
    // Sample period counter
    logic [31:0] sample_counter;
    logic sample_tick;
    
    // Overflow detection
    logic icache_overflow;
    logic dcache_overflow;
    logic coherency_overflow;
    logic mmu_overflow;
    
    // Sample period generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= '0;
            sample_tick <= 1'b0;
        end else if (perf_enable) begin
            if (sample_counter >= (32'h1 << perf_sample_period) - 1) begin
                sample_counter <= '0;
                sample_tick <= 1'b1;
            end else begin
                sample_counter <= sample_counter + 1;
                sample_tick <= 1'b0;
            end
        end else begin
            sample_tick <= 1'b0;
        end
    end
    
    // Edge detection for event counting
    logic icache_access_prev, icache_hit_prev, icache_miss_prev, icache_eviction_prev;
    logic dcache_access_prev, dcache_hit_prev, dcache_miss_prev, dcache_eviction_prev;
    logic dcache_write_prev, dcache_writeback_prev;
    logic coherency_invalidation_prev, coherency_conflict_prev;
    logic mmu_tlb_access_prev, mmu_tlb_hit_prev, mmu_tlb_miss_prev;
    logic mmu_page_fault_prev, mmu_asid_switch_prev;
    
    // Store previous values for edge detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            icache_access_prev <= 1'b0;
            icache_hit_prev <= 1'b0;
            icache_miss_prev <= 1'b0;
            icache_eviction_prev <= 1'b0;
            dcache_access_prev <= 1'b0;
            dcache_hit_prev <= 1'b0;
            dcache_miss_prev <= 1'b0;
            dcache_eviction_prev <= 1'b0;
            dcache_write_prev <= 1'b0;
            dcache_writeback_prev <= 1'b0;
            coherency_invalidation_prev <= 1'b0;
            coherency_conflict_prev <= 1'b0;
            mmu_tlb_access_prev <= 1'b0;
            mmu_tlb_hit_prev <= 1'b0;
            mmu_tlb_miss_prev <= 1'b0;
            mmu_page_fault_prev <= 1'b0;
            mmu_asid_switch_prev <= 1'b0;
        end else begin
            icache_access_prev <= icache_access;
            icache_hit_prev <= icache_hit;
            icache_miss_prev <= icache_miss;
            icache_eviction_prev <= icache_eviction;
            dcache_access_prev <= dcache_access;
            dcache_hit_prev <= dcache_hit;
            dcache_miss_prev <= dcache_miss;
            dcache_eviction_prev <= dcache_eviction;
            dcache_write_prev <= dcache_write;
            dcache_writeback_prev <= dcache_writeback;
            coherency_invalidation_prev <= coherency_invalidation;
            coherency_conflict_prev <= coherency_conflict;
            mmu_tlb_access_prev <= mmu_tlb_access;
            mmu_tlb_hit_prev <= mmu_tlb_hit;
            mmu_tlb_miss_prev <= mmu_tlb_miss;
            mmu_page_fault_prev <= mmu_page_fault;
            mmu_asid_switch_prev <= mmu_asid_switch;
        end
    end
    
    // Instruction cache performance counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            icache_accesses <= '0;
            icache_hits <= '0;
            icache_misses <= '0;
            icache_evictions <= '0;
        end else if (perf_enable) begin
            if (icache_access && !icache_access_prev && !icache_overflow) begin
                icache_accesses <= icache_accesses + 1;
            end
            if (icache_hit && !icache_hit_prev && !icache_overflow) begin
                icache_hits <= icache_hits + 1;
            end
            if (icache_miss && !icache_miss_prev && !icache_overflow) begin
                icache_misses <= icache_misses + 1;
            end
            if (icache_eviction && !icache_eviction_prev && !icache_overflow) begin
                icache_evictions <= icache_evictions + 1;
            end
        end
    end
    
    // Data cache performance counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            dcache_accesses <= '0;
            dcache_hits <= '0;
            dcache_misses <= '0;
            dcache_evictions <= '0;
            dcache_writes <= '0;
            dcache_writebacks <= '0;
        end else if (perf_enable) begin
            if (dcache_access && !dcache_access_prev && !dcache_overflow) begin
                dcache_accesses <= dcache_accesses + 1;
            end
            if (dcache_hit && !dcache_hit_prev && !dcache_overflow) begin
                dcache_hits <= dcache_hits + 1;
            end
            if (dcache_miss && !dcache_miss_prev && !dcache_overflow) begin
                dcache_misses <= dcache_misses + 1;
            end
            if (dcache_eviction && !dcache_eviction_prev && !dcache_overflow) begin
                dcache_evictions <= dcache_evictions + 1;
            end
            if (dcache_write && !dcache_write_prev && !dcache_overflow) begin
                dcache_writes <= dcache_writes + 1;
            end
            if (dcache_writeback && !dcache_writeback_prev && !dcache_overflow) begin
                dcache_writebacks <= dcache_writebacks + 1;
            end
        end
    end
    
    // Coherency performance counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            coherency_invalidations <= '0;
            coherency_conflicts <= '0;
        end else if (perf_enable) begin
            if (coherency_invalidation && !coherency_invalidation_prev && !coherency_overflow) begin
                coherency_invalidations <= coherency_invalidations + 1;
            end
            if (coherency_conflict && !coherency_conflict_prev && !coherency_overflow) begin
                coherency_conflicts <= coherency_conflicts + 1;
            end
        end
    end
    
    // MMU performance counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            mmu_accesses <= '0;
            mmu_hits <= '0;
            mmu_misses <= '0;
            mmu_page_faults <= '0;
            mmu_asid_switches <= '0;
        end else if (perf_enable) begin
            if (mmu_tlb_access && !mmu_tlb_access_prev && !mmu_overflow) begin
                mmu_accesses <= mmu_accesses + 1;
            end
            if (mmu_tlb_hit && !mmu_tlb_hit_prev && !mmu_overflow) begin
                mmu_hits <= mmu_hits + 1;
            end
            if (mmu_tlb_miss && !mmu_tlb_miss_prev && !mmu_overflow) begin
                mmu_misses <= mmu_misses + 1;
            end
            if (mmu_page_fault && !mmu_page_fault_prev && !mmu_overflow) begin
                mmu_page_faults <= mmu_page_faults + 1;
            end
            if (mmu_asid_switch && !mmu_asid_switch_prev && !mmu_overflow) begin
                mmu_asid_switches <= mmu_asid_switches + 1;
            end
        end
    end
    
    // Overflow detection
    assign icache_overflow = (icache_accesses == 32'hFFFFFFFF) ||
                            (icache_hits == 32'hFFFFFFFF) ||
                            (icache_misses == 32'hFFFFFFFF) ||
                            (icache_evictions == 32'hFFFFFFFF);
    
    assign dcache_overflow = (dcache_accesses == 32'hFFFFFFFF) ||
                            (dcache_hits == 32'hFFFFFFFF) ||
                            (dcache_misses == 32'hFFFFFFFF) ||
                            (dcache_evictions == 32'hFFFFFFFF) ||
                            (dcache_writes == 32'hFFFFFFFF) ||
                            (dcache_writebacks == 32'hFFFFFFFF);
    
    assign coherency_overflow = (coherency_invalidations == 32'hFFFFFFFF) ||
                               (coherency_conflicts == 32'hFFFFFFFF);
    
    assign mmu_overflow = (mmu_accesses == 32'hFFFFFFFF) ||
                         (mmu_hits == 32'hFFFFFFFF) ||
                         (mmu_misses == 32'hFFFFFFFF) ||
                         (mmu_page_faults == 32'hFFFFFFFF) ||
                         (mmu_asid_switches == 32'hFFFFFFFF);
    
    assign counters_overflow = icache_overflow || dcache_overflow || 
                              coherency_overflow || mmu_overflow;
    
    // Hit rate calculation (updated on sample tick)
    logic [31:0] icache_hit_rate_calc;
    logic [31:0] dcache_hit_rate_calc;
    logic [31:0] mmu_hit_rate_calc;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            icache_hit_rate_percent <= '0;
            dcache_hit_rate_percent <= '0;
            mmu_hit_rate_percent <= '0;
        end else if (sample_tick && perf_enable) begin
            // Calculate hit rates as percentages (0-10000 = 0.00%-100.00%)
            if (icache_accesses > 0) begin
                icache_hit_rate_calc = (icache_hits * 10000) / icache_accesses;
                icache_hit_rate_percent <= icache_hit_rate_calc[15:0];
            end else begin
                icache_hit_rate_percent <= 16'h0;
            end
            
            if (dcache_accesses > 0) begin
                dcache_hit_rate_calc = (dcache_hits * 10000) / dcache_accesses;
                dcache_hit_rate_percent <= dcache_hit_rate_calc[15:0];
            end else begin
                dcache_hit_rate_percent <= 16'h0;
            end
            
            if (mmu_accesses > 0) begin
                mmu_hit_rate_calc = (mmu_hits * 10000) / mmu_accesses;
                mmu_hit_rate_percent <= mmu_hit_rate_calc[15:0];
            end else begin
                mmu_hit_rate_percent <= 16'h0;
            end
        end
    end
    
    // Combined performance metrics
    assign total_memory_accesses = icache_accesses + dcache_accesses;
    
    // Cache efficiency metric (weighted combination of hit rates)
    // Formula: (ICache_hits * 40% + DCache_hits * 60%) / Total_accesses * 100
    logic [31:0] weighted_hits;
    assign weighted_hits = (icache_hits * 40 + dcache_hits * 60) / 100;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || perf_reset) begin
            cache_efficiency_metric <= '0;
        end else if (sample_tick && perf_enable) begin
            if (total_memory_accesses > 0) begin
                cache_efficiency_metric <= (weighted_hits * 100) / total_memory_accesses;
            end else begin
                cache_efficiency_metric <= '0;
            end
        end
    end
    
    // Output assignments
    assign icache_total_accesses = icache_accesses;
    assign icache_total_hits = icache_hits;
    assign icache_total_misses = icache_misses;
    assign icache_total_evictions = icache_evictions;
    
    assign dcache_total_accesses = dcache_accesses;
    assign dcache_total_hits = dcache_hits;
    assign dcache_total_misses = dcache_misses;
    assign dcache_total_evictions = dcache_evictions;
    assign dcache_total_writes = dcache_writes;
    assign dcache_total_writebacks = dcache_writebacks;
    
    assign coherency_total_invalidations = coherency_invalidations;
    assign coherency_total_conflicts = coherency_conflicts;
    
    assign mmu_total_accesses = mmu_accesses;
    assign mmu_total_hits = mmu_hits;
    assign mmu_total_misses = mmu_misses;
    assign mmu_total_page_faults = mmu_page_faults;
    assign mmu_total_asid_switches = mmu_asid_switches;
    
    // Status outputs
    assign monitor_active = perf_enable;

endmodule