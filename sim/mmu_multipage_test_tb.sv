// ARM7TDMI MMU Multiple Page Size Test Bench
// Tests multiple page size support (1MB sections, 64KB large pages, 4KB small pages, 1KB tiny pages)

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module mmu_multipage_test_tb;
    
    // Parameters
    localparam TLB_ENTRIES = 16;  // Moderate size for testing
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
    int timeout = 0;
    
    // Memory and page table model
    logic [31:0] memory [0:65535]; // 256KB memory model
    logic [31:0] page_table_l1 [0:4095]; // L1 page table (16KB)
    logic [31:0] page_table_l2 [0:1023]; // L2 page table (4KB)
    
    // Initialize memory and page tables
    initial begin
        // Clear memory
        for (int i = 0; i < 65536; i++) begin
            memory[i] = 32'hDEAD0000 + i;
        end
        
        // Set up L1 page table at address 0x10000
        ttb_base = 32'h00010000;
        
        // Clear page tables
        for (int i = 0; i < 4096; i++) begin
            page_table_l1[i] = 32'h00000000; // Fault entries
        end
        for (int i = 0; i < 1024; i++) begin
            page_table_l2[i] = 32'h00000000; // Fault entries
        end
        
        // Set up test mappings for different page sizes
        
        // 1MB Section: Virtual 0x40000000 -> Physical 0x80000000
        page_table_l1[32'h400] = 32'h80000C1E; // Section, global=1, domain=0, cacheable=1, bufferable=1
        
        // L2 page table at 0x20000 for virtual 0x50000000 region
        page_table_l1[32'h500] = 32'h00020001; // Coarse page table, domain=0
        
        // 64KB Large page: Virtual 0x50000000 -> Physical 0x90000000
        for (int i = 0; i < 16; i++) begin // 16 consecutive entries for 64KB page
            page_table_l2[i] = 32'h90000801; // Large page, permissions=00, cacheable=1, bufferable=1
        end
        
        // 4KB Small page: Virtual 0x50010000 -> Physical 0x90010000
        page_table_l2[16] = 32'h9001003E; // Small page, permissions=11, cacheable=1, bufferable=1
        
        // 1KB Tiny page: Virtual 0x50011000 -> Physical 0x90011000
        page_table_l2[17] = 32'h90011043; // Tiny page, permissions=00, cacheable=1, bufferable=1
        
        // Copy page tables to memory
        for (int i = 0; i < 4096; i++) begin
            memory[(32'h10000 >> 2) + i] = page_table_l1[i];
        end
        for (int i = 0; i < 1024; i++) begin
            memory[(32'h20000 >> 2) + i] = page_table_l2[i];
        end
    end
    
    // Memory model behavior
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_rdata <= 32'h0;
            mem_abort <= 1'b0;
        end else begin
            mem_ready <= 1'b1;
            mem_abort <= 1'b0;
            
            if (mem_req) begin
                if (mem_write) begin
                    memory[mem_paddr >> 2] <= mem_wdata;
                end else begin
                    mem_rdata <= memory[mem_paddr >> 2];
                end
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
    
    // Test tasks
    task memory_access(
        input [31:0] vaddr,
        input [31:0] expected_paddr,
        input string page_type,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Virtual: 0x%08x -> Expected Physical: 0x%08x (%s)", 
                 vaddr, expected_paddr, page_type);
        
        cpu_vaddr = vaddr;
        cpu_req = 1'b1;
        cpu_write = 1'b0;
        cpu_size = 2'b10; // Word access
        
        // Wait for completion or timeout
        timeout = 0;
        while (!cpu_ready && !cpu_abort && timeout < 100) begin
            @(posedge clk);
            timeout++;
        end
        
        @(posedge clk);
        
        if (!cpu_abort && (mem_paddr == expected_paddr)) begin
            test_passed++;
            $display("  ✅ PASS: Got physical address 0x%08x", mem_paddr);
        end else if (cpu_abort) begin
            $display("  ❌ FAIL: Memory abort occurred");
        end else begin
            $display("  ❌ FAIL: Got 0x%08x, expected 0x%08x", mem_paddr, expected_paddr);
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("mmu_multipage_test_tb.vcd");
        $dumpvars(0, mmu_multipage_test_tb);
        
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
        mmu_enable = 1'b1;
        cache_enable = 1'b1;
        domain_access = 4'b0001; // Client access
        current_asid = 8'h01;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI MMU Multiple Page Size Test ===");
        $display("TLB Entries: %d", TLB_ENTRIES);
        $display("Page Table Base: 0x%08x", ttb_base);
        $display("Current ASID: %02x\\n", current_asid);
        
        // Test 1: 1MB Section mapping
        memory_access(32'h40001000, 32'h80001000, "1MB Section", 
                     "1MB section translation");
        
        memory_access(32'h40080000, 32'h80080000, "1MB Section", 
                     "1MB section - different offset");
        
        // Test 2: 64KB Large page mapping  
        memory_access(32'h50000000, 32'h90000000, "64KB Large Page", 
                     "64KB large page translation - base");
        
        memory_access(32'h50008000, 32'h90008000, "64KB Large Page", 
                     "64KB large page - mid offset");
        
        memory_access(32'h5000F000, 32'h9000F000, "64KB Large Page", 
                     "64KB large page - end offset");
        
        // Test 3: 4KB Small page mapping
        memory_access(32'h50010000, 32'h90010000, "4KB Small Page", 
                     "4KB small page translation - base");
        
        memory_access(32'h50010800, 32'h90010800, "4KB Small Page", 
                     "4KB small page - mid offset");
        
        memory_access(32'h50010FFF, 32'h90010FFF, "4KB Small Page", 
                     "4KB small page - end offset");
        
        // Test 4: 1KB Tiny page mapping
        memory_access(32'h50011000, 32'h90011000, "1KB Tiny Page", 
                     "1KB tiny page translation - base");
        
        memory_access(32'h50011200, 32'h90011200, "1KB Tiny Page", 
                     "1KB tiny page - mid offset");
        
        memory_access(32'h500113FF, 32'h900113FF, "1KB Tiny Page", 
                     "1KB tiny page - end offset");
        
        // Test 5: TLB hits after initial misses
        $display("=== TLB Hit Tests ===");
        
        memory_access(32'h40002000, 32'h80002000, "1MB Section", 
                     "1MB section - should hit in TLB");
        
        memory_access(32'h50001000, 32'h90001000, "64KB Large Page", 
                     "64KB large page - should hit in TLB");
        
        memory_access(32'h50010100, 32'h90010100, "4KB Small Page", 
                     "4KB small page - should hit in TLB");
        
        memory_access(32'h50011100, 32'h90011100, "1KB Tiny Page", 
                     "1KB tiny page - should hit in TLB");
        
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
        
        if (tlb_hits + tlb_misses > 0) begin
            $display("TLB Hit Rate: %.1f%%", (tlb_hits * 100.0) / (tlb_hits + tlb_misses));
        end
        
        if (test_passed == test_count) begin
            $display("\\n✅ ALL MMU MULTIPLE PAGE SIZE TESTS PASSED!");
        end else begin
            $display("\\n❌ SOME MMU MULTIPLE PAGE SIZE TESTS FAILED");
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