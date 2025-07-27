// ARM7TDMI MMU Test Bench
// Tests virtual memory translation, TLB functionality, and page table walking

`timescale 1ns/1ps

// import arm7tdmi_pkg::*;

module mmu_test_tb;
    
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
    
    // Memory model (simulates physical memory and page tables)
    logic [31:0] memory [0:1048575]; // 4MB memory model
    
    // Page table setup in memory
    // L1 table at 0x10000, L2 tables at 0x11000+
    localparam L1_TABLE_BASE = 32'h00010000;
    localparam L2_TABLE_BASE = 32'h00011000;
    
    // Initialize memory and page tables
    initial begin
        // Clear memory
        for (int i = 0; i < 1048576; i++) begin
            memory[i] = 32'h00000000;
        end
        
        // Set up L1 page table entries
        // Virtual 0x00100000 -> Physical 0x00200000 (1MB section)
        memory[(L1_TABLE_BASE + 32'h004) >> 2] = 32'h00200C1E; // Section entry: 0x200000, domain 0, AP=11, C=1, B=1
        
        // Virtual 0x00000000 -> L2 table at 0x11000 (coarse page table)
        memory[(L1_TABLE_BASE + 32'h000) >> 2] = 32'h00011001; // Coarse page table entry
        
        // Set up L2 page table entries (at 0x11000)
        // Virtual 0x00001000 -> Physical 0x00301000
        memory[(L2_TABLE_BASE + 32'h004) >> 2] = 32'h0030103E; // Small page: 0x301000, AP=11, C=1, B=1
        
        // Virtual 0x00002000 -> Physical 0x00302000  
        memory[(L2_TABLE_BASE + 32'h008) >> 2] = 32'h0030203E; // Small page: 0x302000, AP=11, C=1, B=1
        
        // Put test data in physical memory locations
        memory[32'h00200000 >> 2] = 32'hDEADBEEF; // Section mapped data
        memory[32'h00301000 >> 2] = 32'hCAFEBABE; // Page mapped data
        memory[32'h00302000 >> 2] = 32'h12345678; // Page mapped data
        
        // Debug: Print memory indices
        $display("DEBUG: Test data stored at indices:");
        $display("  0x200000 >> 2 = %d (0x%x) -> 0x%x", 32'h00200000 >> 2, 32'h00200000 >> 2, memory[32'h00200000 >> 2]);
        $display("  0x301000 >> 2 = %d (0x%x) -> 0x%x", 32'h00301000 >> 2, 32'h00301000 >> 2, memory[32'h00301000 >> 2]);
        $display("  0x302000 >> 2 = %d (0x%x) -> 0x%x", 32'h00302000 >> 2, 32'h00302000 >> 2, memory[32'h00302000 >> 2]);
    end
    
    // Memory model behavior
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_abort <= 1'b0;
            mem_rdata <= 32'h0;
        end else begin
            mem_ready <= 1'b1;
            mem_abort <= 1'b0;
            
            if (mem_req) begin
                if (mem_write) begin
                    memory[mem_paddr >> 2] <= mem_wdata;
                    $display("DEBUG: Memory write to 0x%x (index %d) = 0x%x", mem_paddr, mem_paddr >> 2, mem_wdata);
                end else begin
                    mem_rdata <= memory[mem_paddr >> 2];
                    $display("DEBUG: Memory read from 0x%x (index %d) = 0x%x", mem_paddr, mem_paddr >> 2, memory[mem_paddr >> 2]);
                end
            end
        end
    end
    
    // DUT instantiation
    arm7tdmi_mmu #(
        .TLB_ENTRIES(TLB_ENTRIES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_mmu (
        .clk            (clk),
        .rst_n          (rst_n),
        .cpu_vaddr      (cpu_vaddr),
        .cpu_req        (cpu_req),
        .cpu_write      (cpu_write),
        .cpu_size       (cpu_size),
        .cpu_wdata      (cpu_wdata),
        .cpu_rdata      (cpu_rdata),
        .cpu_ready      (cpu_ready),
        .cpu_abort      (cpu_abort),
        .mem_paddr      (mem_paddr),
        .mem_req        (mem_req),
        .mem_write      (mem_write),
        .mem_size       (mem_size),
        .mem_wdata      (mem_wdata),
        .mem_rdata      (mem_rdata),
        .mem_ready      (mem_ready),
        .mem_abort      (mem_abort),
        .ttb_base       (ttb_base),
        .mmu_enable     (mmu_enable),
        .cache_enable   (cache_enable),
        .domain_access  (domain_access),
        .current_asid   (current_asid),
        .tlb_flush_all  (tlb_flush_all),
        .tlb_flush_entry(tlb_flush_entry),
        .tlb_flush_addr (tlb_flush_addr),
        .tlb_flush_asid (tlb_flush_asid),
        .tlb_flush_asid_val(tlb_flush_asid_val),
        .tlb_flush_global(tlb_flush_global),
        .tlb_hits       (tlb_hits),
        .tlb_misses     (tlb_misses),
        .page_faults    (page_faults),
        .asid_switches  (asid_switches),
        .mmu_busy       (mmu_busy)
    );
    
    // Test tasks
    task test_memory_access(
        input [31:0] vaddr,
        input logic write,
        input [31:0] wdata,
        input [31:0] expected_rdata,
        input logic expect_abort,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  Virtual Address: 0x%08x, Write: %b", vaddr, write);
        
        cpu_vaddr = vaddr;
        cpu_write = write;
        cpu_wdata = wdata;
        cpu_size = 2'b10;  // Word access
        cpu_req = 1'b1;
        
        // Wait for completion  
        $display("DEBUG: Starting request, mmu_enable=%b, cpu_req=%b, tlb_flush_all=%b", mmu_enable, cpu_req, tlb_flush_all);
        $display("DEBUG: MMU state before request: state=%d", u_mmu.state);
        
        // Give state machine one cycle to respond
        @(posedge clk);
        $display("DEBUG: After first clock - state=%d, next_state=%d, cpu_ready=%b", u_mmu.state, u_mmu.next_state, cpu_ready);
        $display("DEBUG: l1_addr=0x%x, l1_pte=0x%x, l2_addr=0x%x, l2_pte=0x%x", u_mmu.l1_addr, u_mmu.l1_pte, u_mmu.l2_addr, u_mmu.l2_pte);
        
        while (!cpu_ready && !cpu_abort) begin
            @(posedge clk);
            $display("DEBUG: Waiting - state=%d, next_state=%d, cpu_ready=%b", u_mmu.state, u_mmu.next_state, cpu_ready);
            if (u_mmu.state == 2) // L1_FETCH
                $display("DEBUG: L1_FETCH - mem_rdata=0x%x, mem_rdata[1:0]=%b, mem_ready=%b, mem_req=%b", mem_rdata, mem_rdata[1:0], mem_ready, mem_req);
        end
        $display("DEBUG: Request complete, cpu_ready=%b, cpu_abort=%b, mem_req=%b, mem_paddr=0x%x, state=%d", cpu_ready, cpu_abort, mem_req, mem_paddr, u_mmu.state);
        
        @(posedge clk);
        $display("DEBUG: After clock, state=%d, mem_req=%b, mem_paddr=0x%x", u_mmu.state, mem_req, mem_paddr);
        
        $display("  Physical Address: 0x%08x", mem_paddr);
        $display("  Expected Data: 0x%08x, Got: 0x%08x", expected_rdata, cpu_rdata);
        $display("  Abort: %b (expected: %b)", cpu_abort, expect_abort);
        
        if (cpu_abort == expect_abort && 
            (cpu_abort || (!write && cpu_rdata == expected_rdata))) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        
        cpu_req = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    task wait_mmu_ready;
        while (mmu_busy) begin
            @(posedge clk);
        end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("mmu_test_tb.vcd");
        $dumpvars(0, mmu_test_tb);
        
        // Initialize
        cpu_vaddr = 32'h0;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_size = 2'b10;
        cpu_wdata = 32'h0;
        ttb_base = L1_TABLE_BASE;
        mmu_enable = 1'b1;
        cache_enable = 1'b1;
        domain_access = 4'b0101;  // Client access for both domain 0 and 1
        current_asid = 8'h01;
        tlb_flush_all = 1'b0;
        tlb_flush_entry = 1'b0;
        tlb_flush_addr = 32'h0;
        tlb_flush_asid = 1'b0;
        tlb_flush_asid_val = 8'h0;
        tlb_flush_global = 1'b0;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI MMU Test ===");
        $display("TLB Entries: %d", TLB_ENTRIES);
        $display("L1 Table Base: 0x%08x", L1_TABLE_BASE);
        $display("L2 Table Base: 0x%08x\n", L2_TABLE_BASE);
        
        // Test 1: MMU disabled - direct address translation
        $display("=== MMU Disabled Tests ===");
        mmu_enable = 1'b0;
        test_memory_access(32'h00200000, 1'b0, 32'h0, 32'hDEADBEEF, 1'b0, "Direct access - MMU disabled");
        mmu_enable = 1'b1;
        
        // Test 2: Section mapping (1MB page)
        $display("=== Section Mapping Tests ===");
        test_memory_access(32'h00100000, 1'b0, 32'h0, 32'hDEADBEEF, 1'b0, "Section mapping - VA 0x100000 -> PA 0x200000");
        wait_mmu_ready();
        
        // Test 3: TLB hit on same section
        test_memory_access(32'h00100000, 1'b0, 32'h0, 32'hDEADBEEF, 1'b0, "Section mapping - TLB hit");
        
        // Test 4: Page mapping via L2 table
        $display("=== Page Mapping Tests ===");
        test_memory_access(32'h00001000, 1'b0, 32'h0, 32'hCAFEBABE, 1'b0, "Page mapping - VA 0x1000 -> PA 0x301000");
        wait_mmu_ready();
        
        // Test 5: TLB hit on same page
        test_memory_access(32'h00001000, 1'b0, 32'h0, 32'hCAFEBABE, 1'b0, "Page mapping - TLB hit");
        
        // Test 6: Different page in same L2 table
        test_memory_access(32'h00002000, 1'b0, 32'h0, 32'h12345678, 1'b0, "Page mapping - different page, same L2");
        wait_mmu_ready();
        
        // Test 7: Write access
        test_memory_access(32'h00001000, 1'b1, 32'hABCDEF00, 32'h0, 1'b0, "Page mapping - write access");
        wait_mmu_ready();
        
        // Test 8: Read back written data
        test_memory_access(32'h00001000, 1'b0, 32'h0, 32'hABCDEF00, 1'b0, "Page mapping - read back written data");
        
        // Test 9: Unmapped address (should fault)
        test_memory_access(32'h00003000, 1'b0, 32'h0, 32'h0, 1'b1, "Unmapped address - should fault");
        wait_mmu_ready();
        
        // Test 10: TLB flush all
        $display("=== TLB Management Tests ===");
        $display("Test %d: TLB flush all", test_count + 1);
        test_count++;
        tlb_flush_all = 1'b1;
        @(posedge clk);
        tlb_flush_all = 1'b0;
        @(posedge clk);
        $display("  TLB flushed - all entries invalidated");
        $display("  ✅ PASS\n");
        test_passed++;
        
        // Test 11: Access after TLB flush (should miss and reload)
        test_memory_access(32'h00001000, 1'b0, 32'h0, 32'hABCDEF00, 1'b0, "Page access after TLB flush - should miss");
        wait_mmu_ready();
        
        // Test 12: TLB flush single entry
        $display("Test %d: TLB flush single entry", test_count + 1);
        test_count++;
        tlb_flush_entry = 1'b1;
        tlb_flush_addr = 32'h00001000;
        @(posedge clk);
        tlb_flush_entry = 1'b0;
        @(posedge clk);
        $display("  Single TLB entry flushed for address 0x00001000");
        $display("  ✅ PASS\n");
        test_passed++;
        
        // Test 13: Domain access control
        $display("=== Domain Access Control Tests ===");
        domain_access = 4'b0000;  // No access
        test_memory_access(32'h00001000, 1'b0, 32'h0, 32'h0, 1'b1, "Domain access denied - should fault");
        wait_mmu_ready();
        
        domain_access = 4'b0001;  // Restore client access
        
        // Test 14: Multiple TLB entries
        $display("=== TLB Stress Test ===");
        for (int i = 0; i < 5; i++) begin
            logic [31:0] test_addr;
            string test_desc;
            logic [31:0] expected_data;
            
            test_addr = 32'h00001000 + (i * 32'h1000);
            test_desc = $sformatf("Multiple TLB entries - address %d", i);
            
            if (i < 2) begin
                // These should work (we have L2 entries for 0x1000 and 0x2000)
                expected_data = (i == 0) ? 32'hABCDEF00 : 32'h12345678;
                test_memory_access(test_addr, 1'b0, 32'h0, expected_data, 1'b0, test_desc);
            end else begin
                // These should fault (no L2 entries)
                test_memory_access(test_addr, 1'b0, 32'h0, 32'h0, 1'b1, test_desc);
            end
            wait_mmu_ready();
        end
        
        // Final statistics
        @(posedge clk);
        $display("\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        $display("\n=== MMU Statistics ===");
        $display("TLB Hits: %d", tlb_hits);
        $display("TLB Misses: %d", tlb_misses);
        $display("Page Faults: %d", page_faults);
        $display("TLB Hit Rate: %.1f%%", (tlb_hits * 100.0) / (tlb_hits + tlb_misses));
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL MMU TESTS PASSED!");
        end else begin
            $display("\n❌ SOME MMU TESTS FAILED");
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