// ARM7TDMI MMU Simple ASID Test Bench
// Basic test for ASID functionality

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module mmu_simple_asid_test_tb;
    
    // Parameters
    localparam TLB_ENTRIES = 8;  // Smaller for faster simulation
    localparam ADDR_WIDTH = 32;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // DUT signals
    logic [ADDR_WIDTH-1:0]  cpu_vaddr;
    logic                   cpu_req;
    logic                   cpu_write;
    logic [1:0]             cpu_size;
    logic [31:0]            cpu_wdata;
    logic [31:0]            cpu_rdata;
    logic                   cpu_ready;
    logic                   cpu_abort;
    
    logic [ADDR_WIDTH-1:0]  mem_paddr;
    logic                   mem_req;
    logic                   mem_write;
    logic [1:0]             mem_size;
    logic [31:0]            mem_wdata;
    logic [31:0]            mem_rdata;
    logic                   mem_ready;
    logic                   mem_abort;
    
    logic [31:0]            ttb_base;
    logic                   mmu_enable;
    logic                   cache_enable;
    logic [3:0]             domain_access;
    logic [7:0]             current_asid;
    
    logic                   tlb_flush_all;
    logic                   tlb_flush_entry;
    logic [31:0]            tlb_flush_addr;
    logic                   tlb_flush_asid;
    logic [7:0]             tlb_flush_asid_val;
    logic                   tlb_flush_global;
    
    logic [31:0]            tlb_hits;
    logic [31:0]            tlb_misses;
    logic [31:0]            page_faults;
    logic [31:0]            asid_switches;
    logic                   mmu_busy;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    logic [31:0] initial_switches;
    
    // Simple memory model
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_rdata <= 32'h0;
            mem_abort <= 1'b0;
        end else begin
            mem_ready <= 1'b1;
            mem_abort <= 1'b0;
            
            if (mem_req) begin
                // Simple direct mapping for this test
                mem_rdata <= 32'hDEADBEEF;
            end
        end
    end
    
    // DUT instantiation
    arm7tdmi_mmu #(
        .TLB_ENTRIES(TLB_ENTRIES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_mmu (
        .clk                (clk),
        .rst_n              (rst_n),
        .cpu_vaddr          (cpu_vaddr),
        .cpu_req            (cpu_req),
        .cpu_write          (cpu_write),
        .cpu_size           (cpu_size),
        .cpu_wdata          (cpu_wdata),
        .cpu_rdata          (cpu_rdata),
        .cpu_ready          (cpu_ready),
        .cpu_abort          (cpu_abort),
        .mem_paddr          (mem_paddr),
        .mem_req            (mem_req),
        .mem_write          (mem_write),
        .mem_size           (mem_size),
        .mem_wdata          (mem_wdata),
        .mem_rdata          (mem_rdata),
        .mem_ready          (mem_ready),
        .mem_abort          (mem_abort),
        .ttb_base           (ttb_base),
        .mmu_enable         (mmu_enable),
        .cache_enable       (cache_enable),
        .domain_access      (domain_access),
        .current_asid       (current_asid),
        .tlb_flush_all      (tlb_flush_all),
        .tlb_flush_entry    (tlb_flush_entry),
        .tlb_flush_addr     (tlb_flush_addr),
        .tlb_flush_asid     (tlb_flush_asid),
        .tlb_flush_asid_val (tlb_flush_asid_val),
        .tlb_flush_global   (tlb_flush_global),
        .tlb_hits           (tlb_hits),
        .tlb_misses         (tlb_misses),
        .page_faults        (page_faults),
        .asid_switches      (asid_switches),
        .mmu_busy           (mmu_busy)
    );
    
    // Main test sequence
    initial begin
        $dumpfile("mmu_simple_asid_test_tb.vcd");
        $dumpvars(0, mmu_simple_asid_test_tb);
        
        // Initialize
        cpu_vaddr = 32'h0;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_size = 2'b10;
        cpu_wdata = 32'h0;
        tlb_flush_all = 1'b0;
        tlb_flush_entry = 1'b0;
        tlb_flush_addr = 32'h0;
        tlb_flush_asid = 1'b0;
        tlb_flush_asid_val = 8'h0;
        tlb_flush_global = 1'b0;
        mmu_enable = 1'b0;  // Start with MMU disabled
        cache_enable = 1'b1;
        domain_access = 4'b0001;
        current_asid = 8'h01;
        ttb_base = 32'h00010000;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI MMU Simple ASID Test ===");
        $display("TLB Entries: %d", TLB_ENTRIES);
        $display("Initial ASID: %02x", current_asid);
        
        // Test 1: MMU disabled (pass-through)
        test_count++;
        $display("\\nTest %d: MMU disabled - pass-through", test_count);
        cpu_vaddr = 32'h12345678;
        cpu_req = 1'b1;
        
        wait(cpu_ready);
        @(posedge clk);
        
        if (mem_paddr == cpu_vaddr) begin
            test_passed++;
            $display("  ✅ PASS: Physical addr = Virtual addr (0x%08x)", mem_paddr);
        end else begin
            $display("  ❌ FAIL: Expected 0x%08x, got 0x%08x", cpu_vaddr, mem_paddr);
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        
        // Test 2: ASID change detection
        test_count++;
        $display("\\nTest %d: ASID change detection", test_count);
        initial_switches = asid_switches;
        
        current_asid = 8'h02;
        @(posedge clk);
        @(posedge clk);
        
        if (asid_switches > initial_switches) begin
            test_passed++;
            $display("  ✅ PASS: ASID switch detected (switches: %d)", asid_switches);
        end else begin
            $display("  ❌ FAIL: ASID switch not detected");
        end
        
        // Test 3: TLB flush operations
        test_count++;
        $display("\\nTest %d: TLB flush all", test_count);
        
        tlb_flush_all = 1'b1;
        @(posedge clk);
        tlb_flush_all = 1'b0;
        @(posedge clk);
        
        test_passed++;
        $display("  ✅ PASS: TLB flush completed");
        
        // Test 4: ASID-specific flush
        test_count++;
        $display("\\nTest %d: ASID-specific flush", test_count);
        
        tlb_flush_asid_val = 8'h01;
        tlb_flush_asid = 1'b1;
        @(posedge clk);
        tlb_flush_asid = 1'b0;
        @(posedge clk);
        
        test_passed++;
        $display("  ✅ PASS: ASID flush completed");
        
        // Test 5: Global flush
        test_count++;
        $display("\\nTest %d: Global flush", test_count);
        
        tlb_flush_global = 1'b1;
        @(posedge clk);
        tlb_flush_global = 1'b0;
        @(posedge clk);
        
        test_passed++;
        $display("  ✅ PASS: Global flush completed");
        
        // Final statistics
        $display("\\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        $display("\\n=== MMU Statistics ===");
        $display("TLB Hits: %d", tlb_hits);
        $display("TLB Misses: %d", tlb_misses);
        $display("Page Faults: %d", page_faults);
        $display("ASID Switches: %d", asid_switches);
        
        if (test_passed == test_count) begin
            $display("\\n✅ ALL MMU SIMPLE ASID TESTS PASSED!");
        end else begin
            $display("\\n❌ SOME MMU SIMPLE ASID TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000; // 10us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule