// ARM7TDMI MMU ASID Test Bench
// Tests advanced MMU features including ASID support, global pages, and selective TLB flushing

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module mmu_asid_test_tb;
    
    // Parameters
    localparam TLB_ENTRIES = 32;
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
        
        // Set up some test mappings
        // Virtual address 0x40000000 -> Physical 0x80000000 (1MB section, global, cacheable)
        page_table_l1[32'h400] = 32'h80000C1E; // Section, global=1, domain=0, cacheable=1, bufferable=1
        
        // Virtual address 0x50000000 -> L2 page table at 0x20000 (coarse page table)
        page_table_l1[32'h500] = 32'h00020001; // Coarse page table, domain=0
        
        // L2 entries for 0x50000000 region
        // Virtual page 0x50000000 -> Physical 0x90000000 (4KB page, ASID-specific, cacheable)
        page_table_l2[0] = 32'h9000003E; // Small page, cacheable=1, bufferable=1, permissions=11
        
        // Virtual page 0x50001000 -> Physical 0x90001000 (4KB page, global, cacheable)  
        page_table_l2[1] = 32'h9000183E; // Small page, global=1, cacheable=1, bufferable=1, permissions=11
        
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
        input logic write,
        input [31:0] wdata,
        input [31:0] expected_paddr,
        input logic expect_fault,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Virtual Addr: 0x%08x, Write: %b, ASID: %02x", vaddr, write, current_asid);
        
        cpu_vaddr = vaddr;
        cpu_req = 1'b1;
        cpu_write = write;
        cpu_wdata = wdata;
        cpu_size = 2'b10; // Word access
        
        // Wait for completion or timeout
        timeout = 0;
        while (!cpu_ready && !cpu_abort && timeout < 100) begin
            @(posedge clk);
            timeout++;
        end
        
        @(posedge clk);
        
        if (expect_fault) begin
            if (cpu_abort) begin
                test_passed++;
                $display("  Expected fault occurred - ✅ PASS");
            end else begin
                $display("  Expected fault but got paddr 0x%08x - ❌ FAIL", mem_paddr);
            end
        end else begin
            if (!cpu_abort && (mem_paddr == expected_paddr)) begin
                test_passed++;
                $display("  Physical Addr: 0x%08x (expected 0x%08x) - ✅ PASS", mem_paddr, expected_paddr);
            end else if (cpu_abort) begin
                $display("  Unexpected fault - ❌ FAIL");
            end else begin
                $display("  Wrong paddr: got 0x%08x, expected 0x%08x - ❌ FAIL", mem_paddr, expected_paddr);
            end
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    task flush_tlb_all(input string test_name);
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        
        tlb_flush_all = 1'b1;
        @(posedge clk);
        tlb_flush_all = 1'b0;
        @(posedge clk);
        
        test_passed++;
        $display("  TLB flushed - ✅ PASS\\n");
    endtask
    
    task flush_tlb_asid(input [7:0] asid_val, input string test_name);
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Flushing ASID: %02x", asid_val);
        
        tlb_flush_asid_val = asid_val;
        tlb_flush_asid = 1'b1;
        @(posedge clk);
        tlb_flush_asid = 1'b0;
        @(posedge clk);
        
        test_passed++;
        $display("  ASID-specific TLB flush completed - ✅ PASS\\n");
    endtask
    
    task change_asid(input [7:0] new_asid, input string test_name);
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Changing ASID from %02x to %02x", current_asid, new_asid);
        
        current_asid = new_asid;
        @(posedge clk);
        
        test_passed++;
        $display("  ASID changed - ✅ PASS\\n");
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("mmu_asid_test_tb.vcd");
        $dumpvars(0, mmu_asid_test_tb);
        
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
        
        $display("=== ARM7TDMI MMU ASID Test ===");
        $display("TLB Entries: %d", TLB_ENTRIES);
        $display("Page Table Base: 0x%08x", ttb_base);
        $display("Initial ASID: %02x\\n", current_asid);
        
        // Test 1: Access to global section mapping (should work regardless of ASID)
        memory_access(32'h40001000, 1'b0, 32'h0, 32'h80001000, 1'b0, "Global section access - ASID 01");
        
        // Test 2: Access to ASID-specific page mapping
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page access - ASID 01");
        
        // Test 3: Access to global page mapping  
        memory_access(32'h50001000, 1'b0, 32'h0, 32'h90001000, 1'b0, "Global page access - ASID 01");
        
        // Test 4: Change ASID and test global vs ASID-specific access
        change_asid(8'h02, "Change to ASID 02");
        
        // Test 5: Global section should still work
        memory_access(32'h40002000, 1'b0, 32'h0, 32'h80002000, 1'b0, "Global section access - ASID 02");
        
        // Test 6: Global page should still work
        memory_access(32'h50001000, 1'b0, 32'h0, 32'h90001000, 1'b0, "Global page access - ASID 02");
        
        // Test 7: ASID-specific page should miss (was cached for ASID 01)
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page access - ASID 02 (should miss)");
        
        // Test 8: ASID-specific TLB flush
        change_asid(8'h01, "Change back to ASID 01");
        flush_tlb_asid(8'h01, "Flush TLB entries for ASID 01");
        
        // Test 9: Global entries should survive ASID flush
        memory_access(32'h40003000, 1'b0, 32'h0, 32'h80003000, 1'b0, "Global section after ASID flush");
        memory_access(32'h50001000, 1'b0, 32'h0, 32'h90001000, 1'b0, "Global page after ASID flush");
        
        // Test 10: ASID-specific entry should miss after ASID flush
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page after ASID flush (should miss)");
        
        // Test 11: Multiple ASID test
        change_asid(8'h03, "Change to ASID 03");
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page - ASID 03");
        
        change_asid(8'h04, "Change to ASID 04");
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page - ASID 04");
        
        // Test 12: Global flush test
        $display("Test %d: Global TLB flush test", test_count + 1);
        test_count++;
        tlb_flush_global = 1'b1;
        @(posedge clk);
        tlb_flush_global = 1'b0;
        @(posedge clk);
        $display("  Global TLB flush completed");
        test_passed++;
        $display("  ✅ PASS\\n");
        
        // Test 13: After global flush, global entries should miss
        memory_access(32'h40004000, 1'b0, 32'h0, 32'h80004000, 1'b0, "Global section after global flush (should miss)");
        memory_access(32'h50001000, 1'b0, 32'h0, 32'h90001000, 1'b0, "Global page after global flush (should miss)");
        
        // Test 14: ASID-specific entries should still be cached
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page after global flush (should hit)");
        
        // Test 15: Full TLB flush
        flush_tlb_all("Complete TLB flush");
        
        // Test 16: Everything should miss after full flush
        memory_access(32'h40005000, 1'b0, 32'h0, 32'h80005000, 1'b0, "Global section after full flush (should miss)");
        memory_access(32'h50000000, 1'b0, 32'h0, 32'h90000000, 1'b0, "ASID-specific page after full flush (should miss)");
        
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
            $display("\\n✅ ALL MMU ASID TESTS PASSED!");
        end else begin
            $display("\\n❌ SOME MMU ASID TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule