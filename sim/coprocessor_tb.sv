// Coprocessor Instructions Test
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module coprocessor_tb;
    
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
        $dumpfile("coprocessor_tb.vcd");
        $dumpvars(0, coprocessor_tb);
        
        // Initialize memory with coprocessor test program
        
        // Test 1: MRC p15, 0, R0, c0, c0, 0 (Read CP15 ID register)
        memory[0] = 32'hEE100F10;  // MRC p15, 0, R0, c0, c0, 0
        
        // Test 2: MRC p15, 0, R1, c1, c0, 0 (Read CP15 Control register) 
        memory[1] = 32'hEE111F10;  // MRC p15, 0, R1, c1, c0, 0
        
        // Test 3: MCR p15, 0, R2, c1, c0, 0 (Write CP15 Control register)
        memory[2] = 32'hE3A02001;  // MOV R2, #1
        memory[3] = 32'hEE012F10;  // MCR p15, 0, R2, c1, c0, 0
        
        // Test 4: MRC p14, 0, R3, c0, c0, 0 (Try unsupported coprocessor - should cause undefined exception)
        memory[4] = 32'hEE103E10;  // MRC p14, 0, R3, c0, c0, 0
        
        // Test 5: CDP p10, 2, c4, c5, c6, 3 (Coprocessor data processing - should cause undefined exception)
        memory[5] = 32'hEE254A76;  // CDP p10, 2, c4, c5, c6, 3
        
        // Infinite loop
        memory[6] = 32'hEAFFFFFE; // B .
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        $display("=== Coprocessor Instructions Test ===");
        
        // Run simulation
        repeat(200) @(posedge clk);
        
        // Check results
        $display("Final Register Values:");
        $display("R0 (CP15 ID) = 0x%08h (expect 0x41007700)", u_dut.u_regfile.regs_user[0]);
        $display("R1 (CP15 Control) = 0x%08h (expect 0x00000000)", u_dut.u_regfile.regs_user[1]);
        $display("R2 (Value) = 0x%08h (expect 0x00000001)", u_dut.u_regfile.regs_user[2]);
        $display("R3 (Should be unchanged) = 0x%08h", u_dut.u_regfile.regs_user[3]);
        
        $display("=== Test Complete ===");
        $finish;
    end
    
    // Monitor coprocessor operations
    always @(posedge clk) begin
        if (running && u_dut.current_state == EXECUTE && u_dut.decode_instr_type == INSTR_COPROCESSOR) begin
            $display("Time %0t: Coprocessor operation detected", $time);
            $display("  Instruction: 0x%08h", u_dut.fetch_instruction);
            $display("  CP_OP: %b, CP_NUM: %d", u_dut.decode_cp_op, u_dut.decode_cp_num);
            $display("  CP_RD: %d, CP_RN: %d", u_dut.decode_cp_rd, u_dut.decode_cp_rn);
            $display("  CP_OPCODE1: %b, CP_OPCODE2: %b", u_dut.decode_cp_opcode1, u_dut.decode_cp_opcode2);
            $display("  CP_PRESENT: %b, CP_READY: %b, CP_EXCEPTION: %b", 
                     u_dut.cp_present, u_dut.cp_ready, u_dut.cp_exception);
        end
        
        if (running && u_dut.undefined_exception) begin
            $display("Time %0t: UNDEFINED EXCEPTION - Instruction: 0x%08h", 
                     $time, u_dut.fetch_instruction);
        end
    end
    
endmodule