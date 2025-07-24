// Complete Multiply Instructions Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module multiply_complete_tb;
    
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
    
    // Memory model
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
        $dumpfile("multiply_complete_tb.vcd");
        $dumpvars(0, multiply_complete_tb);
        
        // Initialize memory with multiply test program
        
        // Initialize R1=5, R2=7 for testing
        memory[0] = 32'hE3A01005;  // MOV R1, #5
        memory[1] = 32'hE3A02007;  // MOV R2, #7
        
        // Test 1: MUL R0, R1, R2 (R0 = R1 * R2 = 5 * 7 = 35)
        memory[2] = 32'hE0000291;  // MUL R0, R1, R2
        
        // Test 2: MLA R3, R1, R2, R0 (R3 = (R1 * R2) + R0 = 35 + 35 = 70)
        memory[3] = 32'hE0230091;  // MLA R3, R1, R2, R0
        
        // Setup for long multiply: R4=0xFFFF, R5=0xFFFF  
        memory[4] = 32'hE3A04A0F;  // MOV R4, #0xF000
        memory[5] = 32'hE3844FFF;  // ORR R4, R4, #0xFFF  (R4 = 0xFFFF)
        memory[6] = 32'hE1A05004;  // MOV R5, R4  (R5 = 0xFFFF)
        
        // Test 3: UMULL R6, R7, R4, R5 (R7:R6 = R4 * R5 = 0xFFFF * 0xFFFF)
        memory[7] = 32'hE0876594;  // UMULL R6, R7, R4, R5
        
        // Test 4: SMULL R8, R9, R4, R5 (R9:R8 = R4 * R5 signed)
        memory[8] = 32'hE0C98594;  // SMULL R8, R9, R4, R5
        
        // Test 5: UMLAL R6, R7, R4, R5 (R7:R6 += R4 * R5)
        memory[9] = 32'hE0A76594;  // UMLAL R6, R7, R4, R5
        
        // Test 6: SMLAL R8, R9, R4, R5 (R9:R8 += R4 * R5)
        memory[10] = 32'hE0E98594; // SMLAL R8, R9, R4, R5
        
        // Infinite loop
        memory[11] = 32'hEAFFFFFE; // B .
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("=== Complete Multiply Instructions Test ===");
        
        // Run simulation
        repeat(300) @(posedge clk);
        
        // Check final register values
        $display("Final Register Values:");
        $display("R0 (MUL result) = 0x%08h (expect 35)", u_dut.u_regfile.regs_user[0]);
        $display("R3 (MLA result) = 0x%08h (expect 70)", u_dut.u_regfile.regs_user[3]);
        $display("R6 (UMULL/UMLAL Lo) = 0x%08h", u_dut.u_regfile.regs_user[6]);
        $display("R7 (UMULL/UMLAL Hi) = 0x%08h", u_dut.u_regfile.regs_user[7]);
        $display("R8 (SMULL/SMLAL Lo) = 0x%08h", u_dut.u_regfile.regs_user[8]);
        $display("R9 (SMULL/SMLAL Hi) = 0x%08h", u_dut.u_regfile.regs_user[9]);
        
        $display("=== Test Complete ===");
        $finish;
    end
    
    // Monitor multiply operations
    always @(posedge clk) begin
        if (running && u_dut.current_state == EXECUTE && u_dut.mul_en) begin
            $display("Time %0t: Multiply operation detected", $time);
            $display("  Instruction: 0x%08h", u_dut.fetch_instruction);
            $display("  Type: %s", u_dut.decode_instr_type == INSTR_MUL ? "MUL" : "MUL_LONG");
            $display("  Operands: A=0x%08h, B=0x%08h", u_dut.reg_rn_data, u_dut.reg_rm_data);
            $display("  mul_signed=%b, mul_accumulate=%b, mul_type=%b", 
                     u_dut.mul_signed, u_dut.mul_accumulate, u_dut.mul_type);
        end
        
        if (running && u_dut.current_state == WRITEBACK && u_dut.mul_result_ready) begin
            $display("  Result: Hi=0x%08h, Lo=0x%08h", 
                     u_dut.mul_result_hi, u_dut.mul_result_lo);
        end
    end
    
endmodule