// TAP instruction loading test
`timescale 1ns/1ps

module tap_instr_test;

    logic tck = 0;
    logic tms = 0; 
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;
    logic ice_select;
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
        .ice_select(ice_select),
        .scan_n_select(),
        .ice_tdo(1'b0),
        .scan_n_tdo(1'b0),
        .current_ir(current_ir)
    );

    initial begin
        $dumpfile("tap_instr_test.vcd");
        $dumpvars(0, tap_instr_test);
        
        // Reset
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(2) @(posedge tck);
        
        $display("=== TAP Instruction Test ===");
        
        // Reset TAP 
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
        
        $display("After reset: current_ir=0x%1X, ice_select=%b", current_ir, ice_select);
        
        // Load INTEST instruction (0xC)
        $display("Loading INTEST instruction (0xC)...");
        
        // Go to Select-IR-Scan (need 2 TMS=1 transitions)
        tms = 1; @(posedge tck); // RUN_TEST_IDLE -> SELECT_DR_SCAN
        tms = 1; @(posedge tck); // SELECT_DR_SCAN -> SELECT_IR_SCAN
        $display("In Select-IR-Scan");
        
        // Capture-IR
        tms = 0; @(posedge tck);
        $display("In Capture-IR");
        
        // Shift-IR - shift in 0xC (1100 binary)
        tdi = 0; tms = 0; @(posedge tck); // Bit 0
        $display("Shifted bit 0=0");
        tdi = 0; tms = 0; @(posedge tck); // Bit 1
        $display("Shifted bit 1=0");
        tdi = 1; tms = 0; @(posedge tck); // Bit 2  
        $display("Shifted bit 2=1");
        tdi = 1; tms = 1; @(posedge tck); // Bit 3, exit
        $display("Shifted bit 3=1, exiting");
        
        // Update-IR (TMS=1 from Exit1-IR goes to Update-IR)
        tms = 1; @(posedge tck);  // Exit1-IR -> Update-IR
        $display("In Update-IR");
        tms = 0; @(posedge tck);  // Update-IR -> Run-Test/Idle
        $display("Updated IR: current_ir=0x%1X, ice_select=%b", current_ir, ice_select);
        
        // Run-Test/Idle
        tms = 0; @(posedge tck);
        $display("In Run-Test/Idle: current_ir=0x%1X, ice_select=%b", current_ir, ice_select);
        
        repeat(5) @(posedge tck);
        
        if (current_ir == 4'hC && ice_select == 1'b1) begin
            $display("✅ INTEST instruction loaded correctly!");
        end else begin
            $display("❌ INTEST instruction failed. Expected IR=0xC, ice_select=1, got IR=0x%1X, ice_select=%b", current_ir, ice_select);
        end
        
        $finish;
    end

endmodule