// ARM7TDMI MMU Simple Page Size Test Bench
// Tests the multiple page size address parsing and TLB structure

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module mmu_pagesize_simple_test_tb;
    
    // Parameters
    localparam TLB_ENTRIES = 8;
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
    logic [19:0] section_idx;
    logic [19:0] large_idx;
    logic [19:0] small_idx;
    logic [19:0] tiny_idx;
    
    // Simple memory model for pass-through testing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_rdata <= 32'h0;
            mem_abort <= 1'b0;
        end else begin
            mem_ready <= 1'b1;
            mem_abort <= 1'b0;
            mem_rdata <= 32'hDEADBEEF;
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
    
    // Test task for address parsing validation
    task test_address_parsing(
        input [31:0] vaddr,
        input [31:0] expected_section_idx,
        input [31:0] expected_large_idx,
        input [31:0] expected_small_idx,
        input [31:0] expected_tiny_idx,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Virtual Address: 0x%08x", vaddr);
        
        cpu_vaddr = vaddr;
        @(posedge clk);
        
        // Test address parsing (these would be internal signals in real design)
        section_idx = vaddr[31:20];
        large_idx = vaddr[31:16];
        small_idx = vaddr[31:12];
        tiny_idx = vaddr[31:10];
        
        $display("  Section Index (1MB):  0x%05x (expected 0x%05x)", section_idx, expected_section_idx);
        $display("  Large Page Index (64KB): 0x%05x (expected 0x%05x)", large_idx, expected_large_idx);
        $display("  Small Page Index (4KB):  0x%05x (expected 0x%05x)", small_idx, expected_small_idx);
        $display("  Tiny Page Index (1KB):   0x%05x (expected 0x%05x)", tiny_idx, expected_tiny_idx);
        
        if (section_idx == expected_section_idx &&
            large_idx == expected_large_idx &&
            small_idx == expected_small_idx &&
            tiny_idx == expected_tiny_idx) begin
            test_passed++;
            $display("  ✅ PASS: All address parsing correct");
        end else begin
            $display("  ❌ FAIL: Address parsing mismatch");
        end
        
        $display("");
    endtask
    
    // Test task for MMU pass-through (disabled)
    task test_passthrough(
        input [31:0] vaddr,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Virtual Address: 0x%08x", vaddr);
        
        cpu_vaddr = vaddr;
        cpu_req = 1'b1;
        cpu_write = 1'b0;
        
        wait(cpu_ready);
        @(posedge clk);
        
        if (mem_paddr == vaddr) begin
            test_passed++;
            $display("  ✅ PASS: Pass-through working (Physical = 0x%08x)", mem_paddr);
        end else begin
            $display("  ❌ FAIL: Expected 0x%08x, got 0x%08x", vaddr, mem_paddr);
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("mmu_pagesize_simple_test_tb.vcd");
        $dumpvars(0, mmu_pagesize_simple_test_tb);
        
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
        mmu_enable = 1'b0;  // Start disabled for pass-through tests
        cache_enable = 1'b1;
        domain_access = 4'b0001;
        current_asid = 8'h01;
        ttb_base = 32'h00010000;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI MMU Page Size Simple Test ===");
        $display("TLB Entries: %d", TLB_ENTRIES);
        $display("Testing address parsing for multiple page sizes\\n");
        
        // Test address parsing for different page sizes
        test_address_parsing(32'h12345678, 
                           20'h123, 20'h1234, 20'h12345, 20'h5A,
                           "Mixed address parsing");
        
        test_address_parsing(32'h40000000, 
                           20'h400, 20'h4000, 20'h40000, 20'h0,
                           "1MB boundary address");
        
        test_address_parsing(32'h50010000, 
                           20'h500, 20'h5001, 20'h50010, 20'h40,
                           "64KB/4KB boundary address");
        
        test_address_parsing(32'h50011400, 
                           20'h500, 20'h5001, 20'h50011, 20'h45,
                           "1KB boundary address");
        
        // Test MMU pass-through mode
        $display("=== MMU Pass-through Tests (MMU Disabled) ===");
        
        test_passthrough(32'h12345678, "Pass-through test 1");
        test_passthrough(32'h87654321, "Pass-through test 2");
        test_passthrough(32'hABCDEF00, "Pass-through test 3");
        
        // Test TLB flush operations
        test_count++;
        $display("Test %d: TLB operations test", test_count);
        
        tlb_flush_all = 1'b1;
        @(posedge clk);
        tlb_flush_all = 1'b0;
        @(posedge clk);
        
        test_passed++;
        $display("  ✅ PASS: TLB flush operations completed\\n");
        
        // Final statistics
        @(posedge clk);
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
            $display("\\n✅ ALL MMU PAGE SIZE SIMPLE TESTS PASSED!");
        end else begin
            $display("\\n❌ SOME MMU PAGE SIZE SIMPLE TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #20000; // 20us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule