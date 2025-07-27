// Simple ARM7TDMI Abort Detection Test
// Tests abort signal propagation through exception handler

`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module abort_simple_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Exception handler signals
    logic        irq = 0;
    logic        fiq = 0;
    logic        swi = 0;
    logic        undefined_instr = 0;
    logic        prefetch_abort = 0;
    logic        data_abort = 0;
    
    processor_mode_t current_mode;
    logic [31:0]     current_cpsr;
    logic [31:0]     current_pc;
    
    logic            exception_taken;
    processor_mode_t exception_mode;
    logic [31:0]     exception_vector;
    logic [31:0]     exception_cpsr;
    logic [31:0]     exception_spsr;
    logic [2:0]      exception_type;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // DUT instantiation
    arm7tdmi_exception u_exception (
        .clk                (clk),
        .rst_n              (rst_n),
        .irq                (irq),
        .fiq                (fiq),
        .swi                (swi),
        .undefined_instr    (undefined_instr),
        .prefetch_abort     (prefetch_abort),
        .data_abort         (data_abort),
        .current_mode       (current_mode),
        .current_cpsr       (current_cpsr),
        .current_pc         (current_pc),
        .exception_taken    (exception_taken),
        .exception_mode     (exception_mode),
        .exception_vector   (exception_vector),
        .exception_cpsr     (exception_cpsr),
        .exception_spsr     (exception_spsr),
        .exception_type     (exception_type)
    );
    
    // Test tasks
    task test_data_abort_exception();
        test_count++;
        $display("\nTest %d: Data Abort Exception", test_count);
        
        // Set current state
        current_mode = MODE_USER;
        current_cpsr = 32'h0000001F; // User mode, interrupts enabled
        current_pc = 32'h00001000;
        
        // Trigger data abort
        data_abort = 1'b1;
        @(posedge clk);
        
        // Check exception response
        if (exception_taken && 
            exception_mode == MODE_ABORT &&
            exception_vector == 32'h00000010 &&
            exception_type == 3'd4) begin // EXCEPT_DATA_ABT
            test_passed++;
            $display("  ✅ PASS: Data abort exception correctly generated");
            $display("    Mode: 0x%02X, Vector: 0x%08X", exception_mode, exception_vector);
        end else begin
            $display("  ❌ FAIL: Data abort exception incorrect");
            $display("    Expected: Mode=ABORT, Vector=0x00000010");
            $display("    Got: Mode=0x%02X, Vector=0x%08X, Taken=%b", 
                     exception_mode, exception_vector, exception_taken);
        end
        
        data_abort = 1'b0;
        @(posedge clk);
    endtask
    
    task test_prefetch_abort_exception();
        test_count++;
        $display("\nTest %d: Prefetch Abort Exception", test_count);
        
        // Set current state
        current_mode = MODE_USER;
        current_cpsr = 32'h0000001F;
        current_pc = 32'h00002000;
        
        // Trigger prefetch abort
        prefetch_abort = 1'b1;
        @(posedge clk);
        
        // Check exception response
        if (exception_taken && 
            exception_mode == MODE_ABORT &&
            exception_vector == 32'h0000000C &&
            exception_type == 3'd3) begin // EXCEPT_PREFETCH_ABT
            test_passed++;
            $display("  ✅ PASS: Prefetch abort exception correctly generated");
            $display("    Mode: 0x%02X, Vector: 0x%08X", exception_mode, exception_vector);
        end else begin
            $display("  ❌ FAIL: Prefetch abort exception incorrect");
            $display("    Expected: Mode=ABORT, Vector=0x0000000C");
            $display("    Got: Mode=0x%02X, Vector=0x%08X", exception_mode, exception_vector);
        end
        
        prefetch_abort = 1'b0;
        @(posedge clk);
    endtask
    
    task test_abort_priority();
        test_count++;
        $display("\nTest %d: Abort Exception Priority", test_count);
        
        // Data abort has higher priority than FIQ/IRQ
        current_mode = MODE_USER;
        current_cpsr = 32'h0000001F; // Interrupts enabled
        current_pc = 32'h00003000;
        
        // Trigger multiple exceptions
        data_abort = 1'b1;
        irq = 1'b1;
        fiq = 1'b1;
        @(posedge clk);
        
        // Should take data abort (highest priority)
        if (exception_taken && 
            exception_type == 3'd4 && // EXCEPT_DATA_ABT
            exception_vector == 32'h00000010) begin
            test_passed++;
            $display("  ✅ PASS: Data abort has correct priority");
        end else begin
            $display("  ❌ FAIL: Exception priority incorrect");
            $display("    Expected: Data Abort (type=4)");
            $display("    Got: type=%d", exception_type);
        end
        
        data_abort = 1'b0;
        irq = 1'b0;
        fiq = 1'b0;
        @(posedge clk);
    endtask
    
    task test_abort_cpsr_update();
        test_count++;
        $display("\nTest %d: Abort CPSR Update", test_count);
        
        // Test CPSR updates for abort
        current_mode = MODE_USER;
        current_cpsr = 32'h6000001F; // User mode, FIQ/IRQ enabled, N and Z set
        current_pc = 32'h00004000;
        
        // Trigger data abort
        data_abort = 1'b1;
        @(posedge clk);
        
        // Check CPSR updates
        if (exception_cpsr[4:0] == MODE_ABORT && // Mode changed to abort
            exception_cpsr[7] == 1'b1 &&         // IRQ disabled
            exception_cpsr[5] == 1'b0) begin     // Thumb bit cleared
            test_passed++;
            $display("  ✅ PASS: CPSR correctly updated for abort");
            $display("    New CPSR: 0x%08X", exception_cpsr);
        end else begin
            $display("  ❌ FAIL: CPSR update incorrect");
            $display("    Expected: Mode=ABORT(0x17), I=1, T=0");
            $display("    Got CPSR: 0x%08X", exception_cpsr);
        end
        
        data_abort = 1'b0;
        @(posedge clk);
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("abort_simple_test_tb.vcd");
        $dumpvars(0, abort_simple_test_tb);
        
        $display("=== ARM7TDMI Abort Exception Test ===");
        
        // Reset
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // Run tests
        test_data_abort_exception();
        test_prefetch_abort_exception();
        test_abort_priority();
        test_abort_cpsr_update();
        
        // Summary
        repeat(5) @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("\n✅ ALL ABORT EXCEPTION TESTS PASSED!");
        end else begin
            $display("\n❌ SOME ABORT EXCEPTION TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #1000; // 1us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
endmodule