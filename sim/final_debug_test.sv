// Final debug test - very simple approach
`timescale 1ns/1ps

module final_debug_test;

    logic tck = 0;
    logic tms = 0; 
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;

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
        .current_ir()
    );

    initial begin
        $dumpfile("final_debug_test.vcd");
        $dumpvars(0, final_debug_test);
        
        $display("=== Final Debug Test ===");
        $display("Testing with ARM7TDMI IDCODE: 0x07926041");
        $display("Binary: 00000111100100100110000001000001");
        $display("LSB first should be: 1,0,0,0,0,0,1,0,...");
        
        // Reset everything
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(5) @(posedge tck);
        
        // Reset TAP to Test-Logic-Reset, then to Run-Test/Idle 
        // This should set default instruction to IDCODE
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
        
        $display("TAP reset complete, default instruction should be IDCODE");
        
        // Move to Select-DR-Scan
        tms = 1;
        @(posedge tck);
        $display("In Select-DR-Scan");
        
        // Move to Capture-DR
        tms = 0;
        @(posedge tck);
        $display("In Capture-DR - IDCODE register should be loaded");
        
        // Move to Shift-DR and capture first few bits
        tms = 0;
        @(posedge tck);
        $display("In Shift-DR - TDO should show IDCODE LSB");
        
        // Now in Shift-DR state, TDO should be valid
        // Let's capture the bits one by one
        $display("\\nShifting IDCODE bits (LSB first):");
        
        tdi = 0; // Always shift in 0
        repeat(1) #1; // Let signals settle
        $display("Bit 0: TDO=%b (expected: 1)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 1: TDO=%b (expected: 0)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 2: TDO=%b (expected: 0)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 3: TDO=%b (expected: 0)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 4: TDO=%b (expected: 0)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 5: TDO=%b (expected: 0)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 6: TDO=%b (expected: 1)", tdo);
        @(posedge tck);
        
        repeat(1) #1;
        $display("Bit 7: TDO=%b (expected: 0)", tdo);
        @(posedge tck);
        
        $display("\\nIf the above matches expected pattern, IDCODE is working correctly");
        
        repeat(10) @(posedge tck);
        $finish;
    end

endmodule