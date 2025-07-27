// ARM7TDMI Abort Detection Test
// Tests prefetch and data abort exception handling

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module abort_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Memory interface signals
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_we;
    logic        mem_re;
    logic [3:0]  mem_be;
    logic        mem_ready;
    logic        mem_abort;
    
    // Debug interface
    logic        debug_en = 0;
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    
    // Interrupt interface
    logic        irq = 0;
    logic        fiq = 0;
    
    // Control signals
    logic        halt = 0;
    logic        running;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Simple memory model with abort regions
    logic [31:0] memory [0:4095]; // 16KB memory
    logic [31:0] abort_region_start = 32'h0000_2000;
    logic [31:0] abort_region_end   = 32'h0000_2FFF;
    
    // DUT instantiation
    arm7tdmi_top u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .mem_addr     (mem_addr),
        .mem_wdata    (mem_wdata),
        .mem_rdata    (mem_rdata),
        .mem_we       (mem_we),
        .mem_re       (mem_re),
        .mem_be       (mem_be),
        .mem_ready    (mem_ready),
        .mem_abort    (mem_abort),
        .debug_en     (debug_en),
        .debug_pc     (debug_pc),
        .debug_instr  (debug_instr),
        .irq          (irq),
        .fiq          (fiq),
        .halt         (halt),
        .running      (running)
    );
    
    // Initialize memory with test program
    initial begin
        // Clear memory
        for (int i = 0; i < 4096; i++) begin
            memory[i] = 32'h0;
        end
        
        // Normal code region (0x0000 - 0x1FFF)
        memory[32'h0000 >> 2] = 32'hE3A00001; // MOV R0, #1
        memory[32'h0004 >> 2] = 32'hE3A01002; // MOV R1, #2
        memory[32'h0008 >> 2] = 32'hE0822001; // ADD R2, R2, R1
        
        // Exception vectors
        memory[32'h000C >> 2] = 32'hEAFFFFFE; // B . (prefetch abort handler)
        memory[32'h0010 >> 2] = 32'hEAFFFFFE; // B . (data abort handler)
        
        // Code that will cause data abort
        memory[32'h0100 >> 2] = 32'hE3A03000; // MOV R3, #0x2000 (abort region)
        memory[32'h0104 >> 2] = 32'hE3A04042; // MOV R4, #0x42
        memory[32'h0108 >> 2] = 32'hE5834000; // STR R4, [R3] - will cause data abort
        memory[32'h010C >> 2] = 32'hE3A05055; // MOV R5, #0x55 (should not execute)
        
        // Code that will cause prefetch abort
        memory[32'h0200 >> 2] = 32'hE3A06000; // MOV R6, #0x2000
        memory[32'h0204 >> 2] = 32'hE1A0F006; // MOV PC, R6 - branch to abort region
    end
    
    // Memory model with abort detection
    logic abort_triggered;
    logic [31:0] abort_addr;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'h0;
            mem_abort <= 1'b0;
            abort_triggered <= 1'b0;
            abort_addr <= 32'h0;
        end else begin
            // Default: ready after one cycle
            mem_ready <= (mem_re || mem_we);
            mem_abort <= 1'b0;
            abort_triggered <= 1'b0;
            
            // Check if accessing abort region
            if ((mem_re || mem_we) && !mem_ready) begin
                if (mem_addr >= abort_region_start && mem_addr <= abort_region_end) begin
                    mem_abort <= 1'b1;
                    abort_triggered <= 1'b1;
                    abort_addr <= mem_addr;
                end
            end
            
            // Handle memory operations
            if (mem_re && !mem_ready) begin
                if (mem_addr < 32'h4000) begin
                    mem_rdata <= memory[mem_addr >> 2];
                end else begin
                    mem_rdata <= 32'hDEADBEEF;
                end
            end
            
            if (mem_we && !mem_ready && mem_addr < 32'h4000) begin
                if (mem_be[0]) memory[mem_addr >> 2][7:0]   <= mem_wdata[7:0];
                if (mem_be[1]) memory[mem_addr >> 2][15:8]  <= mem_wdata[15:8];
                if (mem_be[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
                if (mem_be[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
            end
        end
    end
    
    // Display abort messages
    always @(posedge abort_triggered) begin
        $display("Time %t: Memory abort triggered at address 0x%08X", $time, abort_addr);
    end
    
    // Test tasks
    task test_data_abort();
        test_count++;
        $display("\nTest %d: Data Abort Detection", test_count);
        
        // Set PC to code that will cause data abort
        force u_dut.reg_pc_out = 32'h0100;
        @(posedge clk);
        release u_dut.reg_pc_out;
        
        // Run for several cycles
        repeat(20) @(posedge clk);
        
        // Check if data abort was detected
        if (debug_pc == 32'h0010) begin // Data abort vector
            test_passed++;
            $display("  ✅ PASS: Data abort detected and exception taken");
            $display("    Exception PC: 0x%08X", debug_pc);
        end else begin
            $display("  ❌ FAIL: Data abort not properly handled");
            $display("    Expected PC: 0x00000010, Got: 0x%08X", debug_pc);
        end
    endtask
    
    task test_prefetch_abort();
        test_count++;
        $display("\nTest %d: Prefetch Abort Detection", test_count);
        
        // Reset to clear any previous state
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Set PC to code that will branch to abort region
        force u_dut.reg_pc_out = 32'h0200;
        @(posedge clk);
        release u_dut.reg_pc_out;
        
        // Run for several cycles
        repeat(20) @(posedge clk);
        
        // Check if prefetch abort was detected
        if (debug_pc == 32'h000C) begin // Prefetch abort vector
            test_passed++;
            $display("  ✅ PASS: Prefetch abort detected and exception taken");
            $display("    Exception PC: 0x%08X", debug_pc);
        end else begin
            $display("  ❌ FAIL: Prefetch abort not properly handled");
            $display("    Expected PC: 0x0000000C, Got: 0x%08X", debug_pc);
        end
    endtask
    
    task test_abort_priority();
        test_count++;
        $display("\nTest %d: Abort Exception Priority", test_count);
        
        // Test that data abort has higher priority than IRQ
        irq = 1'b1;
        
        // Set PC to code that will cause data abort
        force u_dut.reg_pc_out = 32'h0100;
        @(posedge clk);
        release u_dut.reg_pc_out;
        
        // Run for several cycles
        repeat(20) @(posedge clk);
        
        // Should take data abort, not IRQ
        if (debug_pc == 32'h0010) begin // Data abort vector, not IRQ vector (0x18)
            test_passed++;
            $display("  ✅ PASS: Data abort priority correct");
        end else begin
            $display("  ❌ FAIL: Exception priority incorrect");
            $display("    Expected: Data abort (0x10), Got: 0x%08X", debug_pc);
        end
        
        irq = 1'b0;
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("abort_test_tb.vcd");
        $dumpvars(0, abort_test_tb);
        
        $display("=== ARM7TDMI Abort Detection Test ===");
        $display("Abort region: 0x%08X - 0x%08X", abort_region_start, abort_region_end);
        
        // Reset
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        // Run tests
        test_data_abort();
        test_prefetch_abort();
        test_abort_priority();
        
        // Summary
        repeat(10) @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL ABORT TESTS PASSED!");
        end else begin
            $display("\n❌ SOME ABORT TESTS FAILED");
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