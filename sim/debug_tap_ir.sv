// Debug TAP IR loading issue
`timescale 1ns/1ps

module debug_tap_ir;

    logic tck = 0;
    logic tms = 0; 
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;
    logic [3:0] current_ir;

    always #10 tck = ~tck;

    arm7tdmi_jtag_tap u_tap (
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .trst_n(trst_n),
        .test_logic_reset(),
        .run_test_idle(),
        .select_dr_scan(),
        .capture_dr(),
        .shift_dr(),
        .exit1_dr(),
        .pause_dr(),
        .exit2_dr(),
        .update_dr(),
        .select_ir_scan(),
        .capture_ir(),
        .shift_ir(),
        .exit1_ir(),
        .pause_ir(),
        .exit2_ir(),
        .update_ir(),
        .bypass_select(),
        .idcode_select(),
        .ice_select(),
        .scan_n_select(),
        .ice_tdo(1'b0),
        .scan_n_tdo(1'b0),
        .current_ir(current_ir)
    );

    initial begin
        $dumpfile("debug_tap_ir.vcd");
        $dumpvars(0, debug_tap_ir);
        
        // Reset
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(2) @(posedge tck);
        
        $display("=== Debug TAP IR Loading ==.");
        
        // Reset TAP 
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
        
        $display("After reset: current_ir=0x%1X", current_ir);
        $display("Internal state: instruction_reg=0x%1X, ir_shift_reg=0x%1X", 
                 u_tap.instruction_reg, u_tap.ir_shift_reg);
        
        // Load INTEST instruction (0xC = 1100 binary)
        $display("\nLoading INTEST instruction (0xC = 1100)...");
        
        // Go to Select-IR-Scan
        $display("RUN_TEST_IDLE -> SELECT_DR_SCAN");
        tms = 1; @(posedge tck);
        $display("SELECT_DR_SCAN -> SELECT_IR_SCAN");
        tms = 1; @(posedge tck);
        
        // Capture-IR
        $display("SELECT_IR_SCAN -> CAPTURE_IR");
        tms = 0; @(posedge tck);
        #1; // Small delay to let signals settle
        $display("After CAPTURE_IR: ir_shift_reg=0x%1X", u_tap.ir_shift_reg);
        
        // Shift-IR - shift in 0xC (LSB first: 0,0,1,1)
        $display("CAPTURE_IR -> SHIFT_IR");
        tdi = 0; tms = 0; @(posedge tck); // Bit 0
        $display("After bit 0=0: ir_shift_reg=0x%1X", u_tap.ir_shift_reg);
        
        tdi = 0; tms = 0; @(posedge tck); // Bit 1
        $display("After bit 1=0: ir_shift_reg=0x%1X", u_tap.ir_shift_reg);
        
        tdi = 1; tms = 0; @(posedge tck); // Bit 2  
        $display("After bit 2=1: ir_shift_reg=0x%1X", u_tap.ir_shift_reg);
        
        tdi = 1; tms = 1; @(posedge tck); // Bit 3, exit
        $display("After bit 3=1 (exit): ir_shift_reg=0x%1X", u_tap.ir_shift_reg);
        
        // Exit1-IR -> Update-IR
        $display("EXIT1_IR -> UPDATE_IR");
        tms = 1; @(posedge tck);
        $display("After UPDATE_IR: instruction_reg=0x%1X, ir_shift_reg=0x%1X", 
                 u_tap.instruction_reg, u_tap.ir_shift_reg);
        
        // Update-IR -> Run-Test/Idle
        $display("UPDATE_IR -> RUN_TEST_IDLE");
        tms = 0; @(posedge tck);
        
        $display("\nFinal state: current_ir=0x%1X", current_ir);
        $display("Expected: 0xC, Got: 0x%1X", current_ir);
        
        if (current_ir == 4'hC) begin
            $display("✅ INTEST instruction loaded correctly!");
        end else begin
            $display("❌ INTEST instruction failed!");
        end
        
        $finish;
    end

endmodule