import arm7tdmi_pkg::*;

module simple_tb;

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
    
    // Other signals
    logic        debug_en = 1;
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic        irq = 0;
    logic        fiq = 0;
    logic        halt = 0;
    logic        running;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Simple memory - always ready, returns NOP instruction
    assign mem_ready = 1'b1;
    assign mem_rdata = 32'hE1A00000;  // MOV R0, R0 (NOP)
    
    // DUT
    arm7tdmi_top dut (.*);
    
    // Test
    initial begin
        $dumpfile("simple_tb.vcd");
        $dumpvars(0, simple_tb);
        
        rst_n = 0;
        #50;
        rst_n = 1;
        $display("Reset released");
        
        // Run for just a few cycles
        repeat(5) begin
            @(posedge clk);
            $display("Time: %0t, State: %d, PC: 0x%08h, Running: %b", 
                     $time, dut.current_state, debug_pc, running);
        end
        
        $display("Test completed");
        $finish;
    end

endmodule