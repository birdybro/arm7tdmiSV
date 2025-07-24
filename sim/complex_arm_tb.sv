import arm7tdmi_pkg::*;

module complex_arm_tb;

    // Clock and reset
    logic clk = 0;
    logic rst_n;
    
    // Memory interface
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_we;
    logic        mem_re;
    logic [3:0]  mem_be;
    logic        mem_ready;
    
    // Debug interface
    logic        debug_en = 1;
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    
    // Control signals
    logic        irq = 0;
    logic        fiq = 0;
    logic        halt = 0;
    logic        running;
    
    // Test memory (4KB for instructions, 4KB for data)
    logic [31:0] memory [0:2047];
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Memory model
    assign mem_ready = 1'b1;
    assign mem_rdata = memory[mem_addr[12:2]];
    
    // Memory write
    always_ff @(posedge clk) begin
        if (mem_we) begin
            if (mem_be[3]) memory[mem_addr[12:2]][31:24] = mem_wdata[31:24];
            if (mem_be[2]) memory[mem_addr[12:2]][23:16] = mem_wdata[23:16];
            if (mem_be[1]) memory[mem_addr[12:2]][15:8]  = mem_wdata[15:8];
            if (mem_be[0]) memory[mem_addr[12:2]][7:0]   = mem_wdata[7:0];
        end
    end
    
    // Initialize comprehensive test program
    initial begin
        // Clear memory
        for (int i = 0; i < 2048; i++) begin
            memory[i] = 32'b0;
        end
        
        // Test data at addresses 0x1000-0x1100 (word addresses 1024-1088)
        memory[1024] = 32'h12345678;  // Test data 1
        memory[1025] = 32'hABCDEF00;  // Test data 2
        memory[1026] = 32'h87654321;  // Test data 3
        memory[1027] = 32'h11111111;  // Test data 4
        
        // ARM test program - Complex instructions
        memory[0]  = 32'hE3A01005;  // MOV R1, #5          
        memory[1]  = 32'hE3A02003;  // MOV R2, #3          
        memory[2]  = 32'hE0813002;  // ADD R3, R1, R2      (R3 = 8)
        
        // Shift operations
        memory[3]  = 32'hE1A04081;  // MOV R4, R1, LSL #1  (R4 = R1 << 1 = 10)
        memory[4]  = 32'hE1A050A2;  // MOV R5, R2, LSR #1  (R5 = R2 >> 1 = 1)
        memory[5]  = 32'hE1A06FC1;  // MOV R6, R1, ASR #31 (R6 = R1 >>> 31)
        memory[6]  = 32'hE1A07061;  // MOV R7, R1, ROR #0  (R7 = RRX R1)
        
        // Shifted register operations  
        memory[7]  = 32'hE0888102;  // ADD R8, R8, R2, LSL #2  (R8 = R8 + (R2<<2))
        memory[8]  = 32'hE0499122;  // SUB R9, R9, R2, LSR #2  (R9 = R9 - (R2>>2))
        
        // Load/Store operations
        memory[9]  = 32'hE59FA020;  // LDR R10, [PC, #32]   Load from memory[1024]
        memory[10] = 32'hE59FB024;  // LDR R11, [PC, #36]   Load from memory[1025]
        memory[11] = 32'hE58A1004;  // STR R1, [R10, #4]    Store R1 to [R10+4]
        memory[12] = 32'hE5ABC008;  // STR R12, [R11, #8]   Store R12 to [R11+8]
        
        // Multiply operations
        memory[13] = 32'hE0020391;  // MUL R2, R1, R3       (R2 = R1 * R3 = 5*8 = 40)
        memory[14] = 32'hE00D0291;  // MUL R13, R1, R2      (R13 = R1 * R2)
        
        // Conditional execution
        memory[15] = 32'hE3530008;  // CMP R3, #8           Compare R3 with 8
        memory[16] = 32'h03A0E001;  // MOVEQ R14, #1        R14=1 if R3==8 (should execute)
        memory[17] = 32'h13A0E002;  // MOVNE R14, #2        R14=2 if R3!=8 (should not execute)
        
        // More conditional tests
        memory[18] = 32'hE3520005;  // CMP R2, #5           Compare R2 with 5  
        memory[19] = 32'hC3A0F003;  // MOVGT R15, #3        Branch if R2 > 5
        memory[20] = 32'hD3A0F004;  // MOVLE R15, #4        Branch if R2 <= 5
        
        // Logical operations with shifts
        memory[21] = 32'hE20AA0FF;  // AND R10, R10, #255   Mask lower 8 bits
        memory[22] = 32'hE38BB001;  // ORR R11, R11, #1     Set bit 0
        memory[23] = 32'hE22CC002;  // EOR R12, R12, #2     Toggle bit 1
        memory[24] = 32'hE3CDD004;  // BIC R13, R13, #4     Clear bit 2
        
        // Branch and Link
        memory[25] = 32'hEB000003;  // BL +12 (call subroutine at memory[29])
        memory[26] = 32'hE3A01064;  // MOV R1, #100         Should execute after return
        memory[27] = 32'hE1A0F00E;  // MOV PC, LR           Return (if BL worked)
        memory[28] = 32'hEAFFFFFE;  // B -8 (infinite loop)
        
        // Subroutine at memory[29]
        memory[29] = 32'hE3A02032;  // MOV R2, #50          Subroutine code
        memory[30] = 32'hE0810002;  // ADD R1, R1, R2       R1 = R1 + R2
        memory[31] = 32'hE1A0F00E;  // MOV PC, LR           Return
        
        // Data for loads (PC-relative)
        memory[42] = 32'h1000;      // Address for LDR R10
        memory[43] = 32'h1004;      // Address for LDR R11
        
        $display("=== Complex ARM Instruction Test Program ===");
        $display("Program includes:");
        $display("- Basic arithmetic and logic operations");
        $display("- Shift operations (LSL, LSR, ASR, ROR)");
        $display("- Shifted register operands");
        $display("- Load/Store operations");
        $display("- Multiply instructions");
        $display("- Conditional execution");
        $display("- Branch and Link operations");
        $display("- Data at 0x1000: %h", memory[1024]);
    end
    
    // DUT instantiation
    arm7tdmi_top dut (.*);
    
    // Test sequence
    initial begin
        $dumpfile("complex_arm_tb.vcd");
        $dumpvars(0, complex_arm_tb);
        
        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("\n=== Complex ARM7TDMI Test Started ===");
        $display("Reset released at time %0t", $time);
        
        // Run the program - more extensive test
        repeat(500) @(posedge clk);
        
        $display("\n=== Test completed at time %0t ===", $time);
        $display("Memory dump:");
        $display("Data[1024] = 0x%08h", memory[1024]);
        $display("Data[1025] = 0x%08h", memory[1025]);
        $display("Data[1026] = 0x%08h", memory[1026]);
        $display("Data[1027] = 0x%08h", memory[1027]);
        
        $finish;
    end
    
    // Monitor execution with detailed info
    always @(posedge clk) begin
        if (rst_n && running) begin
            $display("T:%0t PC:0x%08h I:0x%08h S:%d Type:%s", 
                     $time, debug_pc, debug_instr, dut.current_state,
                     get_instr_type_name(dut.decode_instr_type));
        end
    end
    
    // Monitor register writes
    always @(posedge clk) begin
        if (rst_n && dut.reg_rd_we) begin
            $display("*** REG WRITE: R%0d <= 0x%08h", dut.decode_rd, dut.reg_rd_data);
        end
    end
    
    // Monitor memory operations
    always @(posedge clk) begin
        if (rst_n && mem_we) begin
            $display("*** MEM WRITE: [0x%08h] <= 0x%08h", mem_addr, mem_wdata);
        end
        if (rst_n && dut.data_mem_re) begin
            $display("*** MEM READ:  [0x%08h] => 0x%08h", mem_addr, mem_rdata);
        end
    end
    
    // Monitor ALU operations with shift info
    always @(posedge clk) begin
        if (rst_n && (dut.current_state == EXECUTE) && 
            (dut.decode_instr_type == INSTR_DATA_PROC)) begin
            if (dut.decode_shift_amount != 5'b0) begin
                $display("    SHIFT: R%0d %s #%0d => 0x%08h", 
                         dut.decode_rm, get_shift_name(dut.decode_shift_type),
                         dut.decode_shift_amount, dut.shifted_operand);
            end
            $display("    ALU: 0x%08h %s 0x%08h = 0x%08h (NZCV:%b%b%b%b)", 
                     dut.alu_operand_a, get_alu_name(dut.decode_alu_op),
                     dut.alu_operand_b, dut.alu_result,
                     dut.alu_negative, dut.alu_zero, dut.alu_carry_out, dut.alu_overflow);
        end
    end
    
    // Monitor multiply operations
    always @(posedge clk) begin
        if (rst_n && dut.mul_en) begin
            $display("    MUL: 0x%08h * 0x%08h = 0x%08h%08h", 
                     dut.reg_rn_data, dut.reg_rm_data, 
                     dut.mul_result_hi, dut.mul_result_lo);
        end
    end
    
    // Helper functions
    function string get_instr_type_name(input instr_type_t itype);
        case (itype)
            INSTR_DATA_PROC:   return "DATA";
            INSTR_MUL:         return "MUL";
            INSTR_MUL_LONG:    return "MULL";
            INSTR_SINGLE_DT:   return "LDR/STR";
            INSTR_BLOCK_DT:    return "LDM/STM";
            INSTR_BRANCH:      return "BRANCH";
            INSTR_SWI:         return "SWI";
            default:           return "UND";
        endcase
    endfunction
    
    function string get_alu_name(input [3:0] op);
        case (op)
            4'h0: return "AND"; 4'h1: return "EOR"; 4'h2: return "SUB"; 4'h3: return "RSB";
            4'h4: return "ADD"; 4'h5: return "ADC"; 4'h6: return "SBC"; 4'h7: return "RSC";
            4'h8: return "TST"; 4'h9: return "TEQ"; 4'hA: return "CMP"; 4'hB: return "CMN";
            4'hC: return "ORR"; 4'hD: return "MOV"; 4'hE: return "BIC"; 4'hF: return "MVN";
            default: return "???";
        endcase
    endfunction
    
    function string get_shift_name(input [1:0] stype);
        case (stype)
            2'b00: return "LSL";
            2'b01: return "LSR"; 
            2'b10: return "ASR";
            2'b11: return "ROR";
        endcase
    endfunction

endmodule