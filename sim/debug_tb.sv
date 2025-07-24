import arm7tdmi_pkg::*;

module debug_tb;

    logic clk = 0;
    logic rst_n;
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic mem_we, mem_re, mem_ready;
    logic [3:0] mem_be;
    logic debug_en = 1;
    logic [31:0] debug_pc, debug_instr;
    logic irq = 0, fiq = 0, halt = 0, running;
    
    // Clock
    always #5 clk = ~clk;
    
    // Simple memory - just return MOV R0,R0 (NOP)
    assign mem_ready = 1'b1;
    assign mem_rdata = 32'hE1A00000;  // MOV R0, R0
    
    // DUT
    arm7tdmi_top dut (.*);
    
    initial begin
        $dumpfile("debug_tb.vcd");
        $dumpvars(0, debug_tb);
        
        rst_n = 0;
        #50;
        rst_n = 1;
        $display("Reset released");
        
        // Monitor key signals for a few cycles
        repeat(15) begin
            @(posedge clk);
            $display("T:%0t S:%d fetch_en:%b fetch_valid:%b PC_reg:0x%08h fetch_PC:0x%08h", 
                     $time, dut.current_state, dut.fetch_en, dut.fetch_instr_valid, 
                     dut.reg_pc_out, dut.fetch_pc);
        end
        
        $finish;
    end

endmodule