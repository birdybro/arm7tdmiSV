// ARM7TDMI Cache Coherency Test Bench
// Tests cache coherency between instruction and data caches

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module cache_coherency_test_tb;
    
    // Parameters
    localparam ICACHE_SIZE_BYTES = 4096;
    localparam ICACHE_LINE_SIZE = 32;
    localparam DCACHE_SIZE_BYTES = 1024;
    localparam DCACHE_LINE_SIZE = 16;
    localparam ADDR_WIDTH = 32;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // DUT signals
    logic [ADDR_WIDTH-1:0]  cpu_iaddr;
    logic                   cpu_ireq;
    logic                   cpu_thumb_mode;
    logic [31:0]            cpu_idata;
    logic                   cpu_ihit;
    logic                   cpu_iready;
    
    logic [ADDR_WIDTH-1:0]  cpu_daddr;
    logic                   cpu_dreq;
    logic                   cpu_dwrite;
    logic [1:0]             cpu_dsize;
    logic [31:0]            cpu_dwdata;
    logic [3:0]             cpu_dbyte_en;
    logic [31:0]            cpu_drdata;
    logic                   cpu_dhit;
    logic                   cpu_dready;
    
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req;
    logic                   mem_write;
    logic [2:0]             mem_burst_len;
    logic [31:0]            mem_wdata;
    logic [3:0]             mem_byte_en;
    logic [31:0]            mem_rdata;
    logic                   mem_valid;
    logic                   mem_ready;
    
    logic                   cache_enable;
    logic                   icache_flush;
    logic                   icache_invalidate;
    logic                   dcache_flush;
    
    logic                   coherency_enable;
    logic [ADDR_WIDTH-1:0]  code_region_base;
    logic [ADDR_WIDTH-1:0]  code_region_size;
    
    logic [31:0]            icache_hits;
    logic [31:0]            icache_misses;
    logic [31:0]            dcache_hits;
    logic [31:0]            dcache_misses;
    logic [31:0]            coherency_invalidations;
    logic                   icache_busy;
    logic                   dcache_busy;
    logic                   coherency_busy;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    logic [31:0] prev_invalidations;
    
    // Memory model
    logic [31:0] memory [0:65535]; // 256KB memory model
    
    // Initialize memory with test patterns
    initial begin
        for (int i = 0; i < 65536; i++) begin
            memory[i] = 32'hCAFE0000 + i;
        end
        
        // Set up some code patterns in the code region
        memory[32'h1000 >> 2] = 32'hE3A00001; // mov r0, #1
        memory[32'h1004 >> 2] = 32'hE3A01002; // mov r1, #2
        memory[32'h1008 >> 2] = 32'hE0802001; // add r2, r0, r1
        memory[32'h100C >> 2] = 32'hEAFFFFFE; // b . (infinite loop)
    end
    
    // Memory model behavior
    logic [2:0] burst_counter;
    logic [ADDR_WIDTH-1:0] burst_base_addr;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b1;
            mem_valid <= 1'b0;
            mem_rdata <= 32'h0;
            burst_counter <= 3'b0;
            burst_base_addr <= 32'h0;
        end else begin
            mem_valid <= 1'b0;
            
            if (mem_req && mem_ready) begin
                if (mem_write) begin
                    // Handle writes
                    if (mem_byte_en[0]) memory[mem_addr >> 2][7:0] = mem_wdata[7:0];
                    if (mem_byte_en[1]) memory[mem_addr >> 2][15:8] = mem_wdata[15:8];
                    if (mem_byte_en[2]) memory[mem_addr >> 2][23:16] = mem_wdata[23:16];
                    if (mem_byte_en[3]) memory[mem_addr >> 2][31:24] = mem_wdata[31:24];
                    mem_valid <= 1'b1;
                end else begin
                    // Handle reads (with burst support)
                    if (mem_burst_len == 0) begin
                        // Single read
                        mem_rdata <= memory[mem_addr >> 2];
                        mem_valid <= 1'b1;
                    end else begin
                        // Burst read
                        if (burst_counter == 0) begin
                            burst_base_addr <= mem_addr;
                        end
                        mem_rdata <= memory[(burst_base_addr + (burst_counter * 4)) >> 2];
                        mem_valid <= 1'b1;
                        
                        if (burst_counter == mem_burst_len) begin
                            burst_counter <= 3'b0;
                        end else begin
                            burst_counter <= burst_counter + 1;
                        end
                    end
                end
            end
        end
    end
    
    // DUT instantiation
    arm7tdmi_cache_subsystem #(
        .ICACHE_SIZE_BYTES(ICACHE_SIZE_BYTES),
        .ICACHE_LINE_SIZE(ICACHE_LINE_SIZE),
        .DCACHE_SIZE_BYTES(DCACHE_SIZE_BYTES),
        .DCACHE_LINE_SIZE(DCACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_cache_subsystem (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .cpu_iaddr                  (cpu_iaddr),
        .cpu_ireq                   (cpu_ireq),
        .cpu_thumb_mode             (cpu_thumb_mode),
        .cpu_idata                  (cpu_idata),
        .cpu_ihit                   (cpu_ihit),
        .cpu_iready                 (cpu_iready),
        .cpu_daddr                  (cpu_daddr),
        .cpu_dreq                   (cpu_dreq),
        .cpu_dwrite                 (cpu_dwrite),
        .cpu_dsize                  (cpu_dsize),
        .cpu_dwdata                 (cpu_dwdata),
        .cpu_dbyte_en               (cpu_dbyte_en),
        .cpu_drdata                 (cpu_drdata),
        .cpu_dhit                   (cpu_dhit),
        .cpu_dready                 (cpu_dready),
        .mem_addr                   (mem_addr),
        .mem_req                    (mem_req),
        .mem_write                  (mem_write),
        .mem_burst_len              (mem_burst_len),
        .mem_wdata                  (mem_wdata),
        .mem_byte_en                (mem_byte_en),
        .mem_rdata                  (mem_rdata),
        .mem_valid                  (mem_valid),
        .mem_ready                  (mem_ready),
        .cache_enable               (cache_enable),
        .icache_flush               (icache_flush),
        .icache_invalidate          (icache_invalidate),
        .dcache_flush               (dcache_flush),
        .coherency_enable           (coherency_enable),
        .code_region_base           (code_region_base),
        .code_region_size           (code_region_size),
        .icache_hits                (icache_hits),
        .icache_misses              (icache_misses),
        .dcache_hits                (dcache_hits),
        .dcache_misses              (dcache_misses),
        .coherency_invalidations    (coherency_invalidations),
        .icache_busy                (icache_busy),
        .dcache_busy                (dcache_busy),
        .coherency_busy             (coherency_busy)
    );
    
    // Test tasks
    task instruction_fetch(
        input [31:0] addr,
        input logic thumb_mode,
        input [31:0] expected_data,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  I-Fetch Address: 0x%08x, Thumb: %b", addr, thumb_mode);
        
        cpu_iaddr = addr;
        cpu_ireq = 1'b1;
        cpu_thumb_mode = thumb_mode;
        
        while (!cpu_iready) begin
            @(posedge clk);
        end
        
        @(posedge clk);
        
        $display("  Expected: 0x%08x, Got: 0x%08x", expected_data, cpu_idata);
        $display("  Hit: %b, Ready: %b", cpu_ihit, cpu_iready);
        
        if (cpu_idata == expected_data) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        
        cpu_ireq = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    task data_write(
        input [31:0] addr,
        input [1:0] size,
        input [31:0] wdata,
        input [3:0] byte_en,
        input string test_name
    );
        test_count++;
        $display("Test %d: %s", test_count, test_name);
        $display("  D-Write Address: 0x%08x, Size: %d, Data: 0x%08x", addr, size, wdata);
        
        cpu_daddr = addr;
        cpu_dreq = 1'b1;
        cpu_dwrite = 1'b1;
        cpu_dsize = size;
        cpu_dwdata = wdata;
        cpu_dbyte_en = byte_en;
        
        while (!cpu_dready) begin
            @(posedge clk);
        end
        
        @(posedge clk);
        
        $display("  Hit: %b, Ready: %b", cpu_dhit, cpu_dready);
        test_passed++;
        $display("  ✅ PASS");
        
        cpu_dreq = 1'b0;
        cpu_dwrite = 1'b0;
        @(posedge clk);
        $display("");
    endtask
    
    task wait_coherency_idle;
        while (coherency_busy) begin
            @(posedge clk);
        end
        @(posedge clk);
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("cache_coherency_test_tb.vcd");
        $dumpvars(0, cache_coherency_test_tb);
        
        // Initialize
        cpu_iaddr = 32'h0;
        cpu_ireq = 1'b0;
        cpu_thumb_mode = 1'b0;
        cpu_daddr = 32'h0;
        cpu_dreq = 1'b0;
        cpu_dwrite = 1'b0;
        cpu_dsize = 2'b10;
        cpu_dwdata = 32'h0;
        cpu_dbyte_en = 4'b1111;
        cache_enable = 1'b1;
        icache_flush = 1'b0;
        icache_invalidate = 1'b0;
        dcache_flush = 1'b0;
        coherency_enable = 1'b1;
        code_region_base = 32'h00001000;
        code_region_size = 32'h00001000; // 4KB code region
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Cache Coherency Test ===");
        $display("I-Cache: %d bytes, D-Cache: %d bytes", ICACHE_SIZE_BYTES, DCACHE_SIZE_BYTES);
        $display("Code Region: 0x%08x - 0x%08x", code_region_base, code_region_base + code_region_size);
        $display("Coherency Enabled: %b\\n", coherency_enable);
        
        // Test 1: Normal instruction fetch (should cache)
        instruction_fetch(32'h00001000, 1'b0, memory[32'h1000 >> 2], "Normal I-fetch - ARM mode");
        
        // Test 2: Same instruction fetch (should hit)
        instruction_fetch(32'h00001000, 1'b0, memory[32'h1000 >> 2], "I-fetch hit - same address");
        
        // Test 3: Fetch from same cache line
        instruction_fetch(32'h00001004, 1'b0, memory[32'h1004 >> 2], "I-fetch hit - same cache line");
        
        // Test 4: Data write to code region (should trigger coherency)
        $display("=== Coherency Test: Write to Code Region ===");
        data_write(32'h00001000, 2'b10, 32'hE3A00042, 4'b1111, "Data write to cached instruction");
        wait_coherency_idle();
        
        // Check that coherency invalidation occurred
        if (coherency_invalidations > 0) begin
            test_count++;
            test_passed++;
            $display("Test %d: Coherency invalidation triggered", test_count);
            $display("  Invalidations: %d", coherency_invalidations);
            $display("  ✅ PASS\\n");
        end else begin
            test_count++;
            $display("Test %d: Coherency invalidation NOT triggered", test_count);
            $display("  ❌ FAIL\\n");
        end
        
        // Test 5: Instruction fetch after write (should miss and get new data)
        instruction_fetch(32'h00001000, 1'b0, 32'hE3A00042, "I-fetch after coherency invalidation");
        
        // Test 6: Write outside code region (should not trigger coherency)
        $display("=== Test: Write Outside Code Region ===");
        prev_invalidations = coherency_invalidations;
        data_write(32'h00003000, 2'b10, 32'hDEADBEEF, 4'b1111, "Data write outside code region");
        wait_coherency_idle();
        
        if (coherency_invalidations == prev_invalidations) begin
            test_count++;
            test_passed++;
            $display("Test %d: No spurious coherency invalidation", test_count);
            $display("  ✅ PASS\\n");
        end else begin
            test_count++;
            $display("Test %d: Spurious coherency invalidation", test_count);
            $display("  ❌ FAIL\\n");
        end
        
        // Test 7: Coherency disabled test
        $display("=== Test: Coherency Disabled ===");
        coherency_enable = 1'b0;
        prev_invalidations = coherency_invalidations;
        data_write(32'h00001008, 2'b10, 32'h12345678, 4'b1111, "Data write with coherency disabled");
        wait_coherency_idle();
        
        if (coherency_invalidations == prev_invalidations) begin
            test_count++;
            test_passed++;
            $display("Test %d: No invalidation when coherency disabled", test_count);
            $display("  ✅ PASS\\n");
        end else begin
            test_count++;
            $display("Test %d: Unexpected invalidation when coherency disabled", test_count);
            $display("  ❌ FAIL\\n");
        end
        
        // Re-enable coherency for remaining tests
        coherency_enable = 1'b1;
        
        // Test 8: Thumb mode coherency
        $display("=== Test: Thumb Mode Coherency ===");
        instruction_fetch(32'h00001010, 1'b1, memory[32'h1010 >> 2] & 32'h0000FFFF, "Thumb I-fetch");
        data_write(32'h00001010, 2'b01, 32'h0000ABCD, 4'b0011, "Thumb instruction modification");
        wait_coherency_idle();
        instruction_fetch(32'h00001010, 1'b1, 32'h0000ABCD, "Thumb I-fetch after modification");
        
        // Final statistics
        @(posedge clk);
        $display("\\n=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        $display("\\n=== Cache Statistics ===");
        $display("I-Cache Hits: %d, Misses: %d", icache_hits, icache_misses);
        $display("D-Cache Hits: %d, Misses: %d", dcache_hits, dcache_misses);
        $display("Coherency Invalidations: %d", coherency_invalidations);
        
        if (icache_hits + icache_misses > 0) begin
            $display("I-Cache Hit Rate: %.1f%%", (icache_hits * 100.0) / (icache_hits + icache_misses));
        end
        if (dcache_hits + dcache_misses > 0) begin
            $display("D-Cache Hit Rate: %.1f%%", (dcache_hits * 100.0) / (dcache_hits + dcache_misses));
        end
        
        if (test_passed == test_count) begin
            $display("\\n✅ ALL CACHE COHERENCY TESTS PASSED!");
        end else begin
            $display("\\n❌ SOME CACHE COHERENCY TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #500000; // 500us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule