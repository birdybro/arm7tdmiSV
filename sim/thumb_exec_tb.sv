// Thumb Execution Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module thumb_exec_tb;
    
    // Clock and reset
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;  // 100MHz clock
    
    // Top-level signals
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic        mem_we, mem_re;
    logic [3:0]  mem_be;
    logic        mem_ready;
    logic        debug_en = 0;
    logic [31:0] debug_pc, debug_instr;
    logic        irq = 0, fiq = 0;
    logic        halt = 0, running;
    
    // Memory model (16-bit aligned for Thumb)
    logic [31:0] memory [0:1023];
    
    always_ff @(posedge clk) begin
        if (mem_we && mem_ready) begin
            memory[mem_addr[31:2]] <= mem_wdata;
        end
        if (mem_re) begin
            mem_rdata <= memory[mem_addr[31:2]];
        end
    end
    
    assign mem_ready = 1'b1;
    
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
    
    initial begin
        $dumpfile("thumb_exec_tb.vcd");
        $dumpvars(0, thumb_exec_tb);
        
        // Initialize memory with Thumb test program
        // Note: ARM7TDMI starts in ARM mode, so we need a BX to switch to Thumb
        
        // ARM mode startup
        memory[0] = 32'hE3A00001;  // MOV R0, #1 (ARM)
        memory[1] = 32'hE12FFF10;  // BX R0 (Switch to Thumb mode, PC = 0x8)
        
        // Thumb mode program (starting at word address 2 = byte address 8)
        memory[2] = {16'h3205, 16'h0000};  // MOV R2, #5 (Thumb), padding
        memory[3] = {16'h3364, 16'h0000};  // ADD R3, #100 (Thumb), padding  
        memory[4] = {16'h181A, 16'h0000};  // ADD R2, R2, R3 (Thumb), padding
        memory[5] = {16'h0148, 16'h0000};  // LSL R0, R1, #5 (Thumb), padding
        memory[6] = {16'hE7FE, 16'h0000};  // B . (infinite loop), padding
        
        // Initialize some registers with test values
        // Note: This would normally be done through proper initialization
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("=== Thumb Execution Test ===");
        
        // Run simulation for enough cycles to execute several instructions
        repeat(100) @(posedge clk);
        
        // Check results  
        $display("Final Register Values:");
        $display("R0 = 0x%08h", u_dut.u_regfile.regs_user[0]);
        $display("R1 = 0x%08h", u_dut.u_regfile.regs_user[1]);
        $display("R2 = 0x%08h (expect 105 if Thumb MOV+ADD worked)", u_dut.u_regfile.regs_user[2]);
        $display("R3 = 0x%08h (expect 100 if Thumb ADD worked)", u_dut.u_regfile.regs_user[3]);
        $display("PC = 0x%08h", u_dut.reg_pc_out);
        $display("CPSR = 0x%08h (T bit should be set)", u_dut.reg_cpsr_out);
        
        $display("=== Test Complete ===");
        $finish;
    end
    
    // Monitor Thumb operations
    always @(posedge clk) begin
        if (running && u_dut.thumb_mode && u_dut.current_state == EXECUTE) begin
            $display("Time %0t: Thumb execution", $time);
            $display("  PC: 0x%08h, Instruction: 0x%04h", u_dut.reg_pc_out, u_dut.fetch_instruction[15:0]);
            $display("  Type: %d, ALU A: 0x%08h, ALU B: 0x%08h", 
                     u_dut.decode_thumb_instr_type, u_dut.alu_operand_a, u_dut.alu_operand_b);
            $display("  ALU Result: 0x%08h", u_dut.alu_result);
        end
        
        if (running && u_dut.current_state == EXECUTE && 
            u_dut.decode_instr_type == INSTR_BRANCH_EX) begin
            $display("Time %0t: BX instruction detected - mode switch", $time);
        end
    end
    
endmodule