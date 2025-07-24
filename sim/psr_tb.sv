// PSR Transfer Instructions Testbench
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module psr_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Memory model
    logic [31:0] memory [0:1023];
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic        mem_we, mem_re;
    logic [3:0]  mem_be;
    logic        mem_ready;
    
    // Simple memory model
    always_ff @(posedge clk) begin
        if (mem_we && mem_ready) begin
            memory[mem_addr[31:2]] <= mem_wdata;
        end
        if (mem_re) begin
            mem_rdata <= memory[mem_addr[31:2]];
        end
    end
    
    assign mem_ready = 1'b1;  // Always ready
    
    // Top-level signals
    logic        debug_en = 0;
    logic [31:0] debug_pc, debug_instr;
    logic        irq = 0, fiq = 0;
    logic        halt = 0, running;
    
    // DUT instantiation
    arm7tdmi_top u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_rdata  (mem_rdata),
        .mem_we     (mem_we),
        .mem_re     (mem_re),
        .mem_be     (mem_be),
        .mem_ready  (mem_ready),
        .debug_en   (debug_en),
        .debug_pc   (debug_pc),
        .debug_instr(debug_instr),
        .irq        (irq),
        .fiq        (fiq),
        .halt       (halt),
        .running    (running)
    );
    
    // Test program memory initialization
    initial begin
        $dumpfile("psr_tb.vcd");
        $dumpvars(0, psr_tb);
        
        // Initialize memory with PSR transfer test program
        // Test 1: MRS R0, CPSR - Move CPSR to R0
        memory[0] = 32'h E10F0000;  // MRS R0, CPSR
        
        // Test 2: MSR CPSR, R1 - Move R1 to CPSR (set R1 first)
        memory[1] = 32'h E3A01020;  // MOV R1, #0x20 (set some flags)
        memory[2] = 32'h E121F001;  // MSR CPSR, R1
        
        // Test 3: MRS R2, SPSR - Move SPSR to R2 (need to be in exception mode)
        // First cause an exception to set SPSR
        memory[3] = 32'h EF000000;  // SWI #0 (Software Interrupt)
        
        // Exception handler (will be at address 0x8)
        memory[2] = 32'h E10F2000;  // MRS R2, SPSR (in exception mode)
        memory[3] = 32'h E1A0F00E;  // MOV PC, LR (return from exception)
        
        // Test 4: MSR CPSR_flg, #0xF0000000 - Set flags using immediate
        memory[4] = 32'h E32FF00F;  // MSR CPSR_flg, #0xF0000000
        
        // Test 5: Verify flag setting worked by testing conditional execution
        memory[5] = 32'h 13A03001;  // MOVNE R3, #1 (should execute if Z=0)
        memory[6] = 32'h 03A03002;  // MOVEQ R3, #2 (should execute if Z=1)
        
        // Infinite loop to end test
        memory[7] = 32'h EAFFFFFE;  // B . (infinite loop)
        
        // Reset the processor
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("=== PSR Transfer Instructions Test ===");
        
        // Run for enough cycles to execute the test program
        repeat(200) @(posedge clk);
        
        $display("=== Test Complete ===");
        $finish;
    end
    
    // Monitor key signals
    always @(posedge clk) begin
        if (running && u_dut.current_state == EXECUTE) begin
            case (u_dut.debug_instr)
                32'hE10F0000: $display("Time %0t: Executing MRS R0, CPSR", $time);
                32'hE121F001: $display("Time %0t: Executing MSR CPSR, R1", $time);
                32'hE10F2000: $display("Time %0t: Executing MRS R2, SPSR", $time);
                32'hE32FF00F: $display("Time %0t: Executing MSR CPSR_flg, #0xF0000000", $time);
            endcase
        end
        
        // Monitor register values after key instructions
        if (running && u_dut.current_state == WRITEBACK) begin
            if (u_dut.decode_instr_type == INSTR_PSR_TRANSFER) begin
                $display("Time %0t: PSR Transfer - CPSR=0x%08h, R0=0x%08h, R1=0x%08h, R2=0x%08h", 
                         $time, u_dut.reg_cpsr_out, 
                         u_dut.u_regfile.regs_user[0],
                         u_dut.u_regfile.regs_user[1], 
                         u_dut.u_regfile.regs_user[2]);
            end
        end
    end
    
endmodule