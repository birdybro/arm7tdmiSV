import arm7tdmi_pkg::*;

module arm7tdmi_tb;

    // Clock and reset
    logic clk;
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
    logic        debug_en;
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    
    // Interrupt interface
    logic        irq;
    logic        fiq;
    
    // Control signals
    logic        halt;
    logic        running;
    
    // Test memory
    logic [31:0] test_memory [0:1023];  // 4KB test memory
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Memory model - ready immediately for simulation
    assign mem_ready = mem_re || mem_we;
    
    // Memory read logic
    always_comb begin
        if (mem_re) begin
            mem_rdata = test_memory[mem_addr[11:2]];  // Word-aligned access
        end else begin
            mem_rdata = 32'b0;
        end
    end
    
    // Memory write logic
    always_ff @(posedge clk) begin
        if (mem_we) begin
            if (mem_be[3]) test_memory[mem_addr[11:2]][31:24] = mem_wdata[31:24];
            if (mem_be[2]) test_memory[mem_addr[11:2]][23:16] = mem_wdata[23:16];
            if (mem_be[1]) test_memory[mem_addr[11:2]][15:8]  = mem_wdata[15:8];
            if (mem_be[0]) test_memory[mem_addr[11:2]][7:0]   = mem_wdata[7:0];
        end
    end
    
    // Initialize test memory with simple program
    initial begin
        // Initialize all memory to 0
        for (int i = 0; i < 1024; i++) begin
            test_memory[i] = 32'b0;
        end
        
        // Simple test program
        // MOV R1, #0x10        - E3A01010
        test_memory[0] = 32'hE3A01010;
        
        // MOV R2, #0x20        - E3A02020  
        test_memory[1] = 32'hE3A02020;
        
        // ADD R3, R1, R2       - E0813002
        test_memory[2] = 32'hE0813002;
        
        // MOV R4, R3           - E1A04003
        test_memory[3] = 32'hE1A04003;
        
        // Branch to self (infinite loop) - EAFFFFFE
        test_memory[4] = 32'hEAFFFFFE;
    end
    
    // DUT instantiation
    arm7tdmi_top dut (
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
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        debug_en = 1'b1;
        irq = 1'b0;
        fiq = 1'b0;
        halt = 1'b0;
        
        // Wait for a few clock cycles
        repeat(5) @(posedge clk);
        
        // Release reset
        rst_n = 1'b1;
        $display("Reset released at time %0t", $time);
        
        // Run simulation for some cycles
        repeat(10) @(posedge clk);
        
        $display("Simulation completed at time %0t", $time);
        $finish;
    end
    
    // Monitor signals with more detail
    always @(posedge clk) begin
        if (rst_n) begin
            $display("Time: %0t, State: %d, PC: 0x%08h, Instr: 0x%08h, Running: %b, fetch_valid: %b, decode_valid: %b", 
                     $time, dut.current_state, debug_pc, debug_instr, running, 
                     dut.fetch_instr_valid, dut.decode_valid);
        end
    end
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("arm7tdmi_tb.vcd");
        $dumpvars(0, arm7tdmi_tb);
    end

endmodule