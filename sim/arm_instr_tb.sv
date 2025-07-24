import arm7tdmi_pkg::*;

module arm_instr_tb;

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
    
    // Test memory (4KB)
    logic [31:0] test_memory [0:1023];
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Memory model
    assign mem_ready = 1'b1;
    
    // Memory read
    assign mem_rdata = test_memory[mem_addr[11:2]];
    
    // Memory write
    always_ff @(posedge clk) begin
        if (mem_we) begin
            if (mem_be[3]) test_memory[mem_addr[11:2]][31:24] = mem_wdata[31:24];
            if (mem_be[2]) test_memory[mem_addr[11:2]][23:16] = mem_wdata[23:16];
            if (mem_be[1]) test_memory[mem_addr[11:2]][15:8]  = mem_wdata[15:8];
            if (mem_be[0]) test_memory[mem_addr[11:2]][7:0]   = mem_wdata[7:0];
        end
    end
    
    // Initialize test program
    initial begin
        // Clear memory
        for (int i = 0; i < 1024; i++) begin
            test_memory[i] = 32'b0;
        end
        
        // ARM test program
        test_memory[0] = 32'hE3A01005;  // MOV R1, #5         (R1 = 5)
        test_memory[1] = 32'hE3A02003;  // MOV R2, #3         (R2 = 3)  
        test_memory[2] = 32'hE0813002;  // ADD R3, R1, R2     (R3 = R1 + R2 = 8)
        test_memory[3] = 32'hE0524001;  // SUBS R4, R2, R1    (R4 = R2 - R1 = -2, sets flags)
        test_memory[4] = 32'hE1A05003;  // MOV R5, R3         (R5 = R3 = 8)
        test_memory[5] = 32'hE0066002;  // AND R6, R6, R2     (R6 = R6 & R2)
        test_memory[6] = 32'hE1877003;  // ORR R7, R7, R3     (R7 = R7 | R3)
        test_memory[7] = 32'hEAFFFFFE;  // B -8 (infinite loop)
        
        $display("Test program loaded:");
        $display("0x00: MOV R1, #5");
        $display("0x04: MOV R2, #3");
        $display("0x08: ADD R3, R1, R2");
        $display("0x0C: SUBS R4, R2, R1");
        $display("0x10: MOV R5, R3");
        $display("0x14: AND R6, R6, R2");
        $display("0x18: ORR R7, R7, R3");
        $display("0x1C: B -8 (loop)");
    end
    
    // DUT instantiation
    arm7tdmi_top dut (.*);
    
    // Test sequence
    initial begin
        $dumpfile("arm_instr_tb.vcd");
        $dumpvars(0, arm_instr_tb);
        
        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("\n=== ARM7TDMI Instruction Test Started ===");
        $display("Reset released at time %0t", $time);
        
        // Run the program
        repeat(100) @(posedge clk);
        
        $display("\n=== Test completed at time %0t ===", $time);
        $display("Final register states (if accessible):");
        
        $finish;
    end
    
    // Monitor execution
    always @(posedge clk) begin
        if (rst_n && running) begin
            $display("T:%0t PC:0x%08h I:0x%08h S:%d", 
                     $time, debug_pc, debug_instr, dut.current_state);
        end
    end
    
    // Monitor register writes (when they occur)
    always @(posedge clk) begin
        if (rst_n && dut.reg_rd_we) begin
            $display("*** REG WRITE: R%0d <= 0x%08h", dut.decode_rd, dut.reg_rd_data);
        end
    end
    
    // Monitor ALU operations
    always @(posedge clk) begin
        if (rst_n && (dut.current_state == EXECUTE) && 
            (dut.decode_instr_type == INSTR_DATA_PROC)) begin
            $display("    ALU: 0x%08h %s 0x%08h = 0x%08h (N:%b Z:%b C:%b V:%b)", 
                     dut.alu_operand_a, 
                     get_alu_name(dut.decode_alu_op),
                     dut.alu_operand_b, 
                     dut.alu_result,
                     dut.alu_negative, dut.alu_zero, dut.alu_carry_out, dut.alu_overflow);
        end
    end
    
    // Helper function to display ALU operation names
    function string get_alu_name(input [3:0] op);
        case (op)
            4'h0: return "AND";
            4'h1: return "EOR"; 
            4'h2: return "SUB";
            4'h3: return "RSB";
            4'h4: return "ADD";
            4'h5: return "ADC";
            4'h6: return "SBC";
            4'h7: return "RSC";
            4'h8: return "TST";
            4'h9: return "TEQ";
            4'hA: return "CMP";
            4'hB: return "CMN";
            4'hC: return "ORR";
            4'hD: return "MOV";
            4'hE: return "BIC";
            4'hF: return "MVN";
            default: return "???";
        endcase
    endfunction

endmodule