// Thumb BL Instruction Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module thumb_bl_test_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test signals
    logic halt = 0;
    logic running;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata = 32'h0;
    logic mem_we;
    logic mem_re;
    logic [3:0] mem_be;
    logic mem_ready = 1;
    logic debug_en = 0;
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic irq = 0;
    logic fiq = 0;
    
    // Instruction memory - BL sequence
    logic [31:0] test_memory [0:15];
    
    initial begin
        test_memory[0] = 32'hF000F800;  // BL prefix: F000 (high part = 0)
        test_memory[1] = 32'hF801F800;  // BL suffix: F801 (low part = 1, should jump to PC+4)
        test_memory[2] = 32'h46C0;      // NOP (MOV R8, R8)
        test_memory[3] = 32'h46C0;      // NOP 
        test_memory[4] = 32'h46C0;      // Target location: NOP
        test_memory[5] = 32'h46C0;      // NOP
        for (int i = 6; i < 16; i++) test_memory[i] = 32'h0;
    end
    
    always_comb begin
        if (mem_re) begin
            if (mem_addr[31:2] < 16) begin
                mem_rdata = test_memory[mem_addr[31:2]];
            end else begin
                mem_rdata = 32'h0;
            end
        end
    end
    
    // Instantiate ARM7TDMI
    arm7tdmi_top u_cpu (
        .clk         (clk),
        .rst_n       (rst_n),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_rdata   (mem_rdata),
        .mem_we      (mem_we),
        .mem_re      (mem_re),
        .mem_be      (mem_be),
        .mem_ready   (mem_ready),
        .debug_en    (debug_en),
        .debug_pc    (debug_pc),
        .debug_instr (debug_instr),
        .irq         (irq),
        .fiq         (fiq),
        .halt        (halt),
        .running     (running)
    );
    
    initial begin
        $dumpfile("thumb_bl_test_tb.vcd");
        $dumpvars(0, thumb_bl_test_tb);
        
        // Initial setup - CPU will start in ARM mode and we'll set Thumb mode via CPSR
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("=== Thumb BL Instruction Test ===");
        $display("Testing BL instruction sequence:");
        $display("  BL prefix (F000): Sets up high part of target");
        $display("  BL suffix (F801): Completes branch to target");
        
        // Monitor key signals
        fork
            begin
                // Monitor PC changes
                reg [31:0] prev_pc;
                prev_pc = 32'h0;
                forever begin
                    @(posedge clk);
                    if (u_cpu.reg_pc_out != prev_pc) begin
                        $display("Time %0t: PC changed from 0x%08x to 0x%08x", 
                                 $time, prev_pc, u_cpu.reg_pc_out);
                        prev_pc = u_cpu.reg_pc_out;
                    end
                end
            end
            
            begin
                // Monitor BL state
                forever begin
                    @(posedge clk);
                    if (u_cpu.thumb_bl_pending) begin
                        $display("Time %0t: BL prefix executed, target=0x%08x, pending=%b", 
                                 $time, u_cpu.thumb_bl_target, u_cpu.thumb_bl_pending);
                    end
                    if (u_cpu.decode_thumb_instr_type == THUMB_BL_LOW && u_cpu.current_state == EXECUTE) begin
                        $display("Time %0t: BL suffix executing, branch_taken=%b, target=0x%08x", 
                                 $time, u_cpu.branch_taken, u_cpu.branch_target);
                    end
                end
            end
            
            begin
                // Monitor instruction decode  
                forever begin
                    @(posedge clk);
                    if (u_cpu.current_state == DECODE && u_cpu.decode_valid) begin
                        $display("Time %0t: Decoded instruction 0x%08x, type=%0d, thumb_type=%0d",
                                 $time, u_cpu.fetch_instruction, u_cpu.decode_instr_type, u_cpu.decode_thumb_instr_type);
                    end
                end
            end
        join_none
        
        // Run simulation
        repeat(50) @(posedge clk);
        
        // Check results
        $display("\\n=== Test Results ===");
        $display("Thumb mode: %b", u_cpu.thumb_mode);
        $display("BL pending: %b", u_cpu.thumb_bl_pending);
        $display("BL target: 0x%08x", u_cpu.thumb_bl_target);
        
        $display("=== Thumb BL Test Complete ===");
        $finish;
    end
    
endmodule