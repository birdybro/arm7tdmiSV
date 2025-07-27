// Debug TAP controller data path test
`timescale 1ns/1ps

module debug_tap_test;

    logic tck = 0;
    logic tms = 0; 
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;

    always #10 tck = ~tck;

    // Instantiate just the TAP controller
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
        $dumpfile("debug_tap_test.vcd");
        $dumpvars(0, debug_tap_test);
        
        // Reset
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(2) @(posedge tck);
        
        $display("=== Testing Basic TAP Navigation ===");
        
        // Reset TAP
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
        $display("TAP Reset complete");
        
        // Load IDCODE instruction
        tms = 1; @(posedge tck); // Select-IR-Scan
        tms = 0; @(posedge tck); // Capture-IR
        
        // Shift IR
        for (int i = 0; i < 4; i++) begin
            tdi = (4'b1110 >> i) & 1'b1; // IDCODE = 1110
            tms = (i == 3) ? 1'b1 : 1'b0;
            @(posedge tck);
            $display("IR Shift %d: TDI=%b, TDO=%b", i, tdi, tdo);
        end
        
        tms = 0; @(posedge tck); // Update-IR
        tms = 0; @(posedge tck); // Run-Test/Idle
        
        $display("IDCODE instruction loaded");
        
        // Now shift IDCODE DR
        tms = 1; @(posedge tck); // Select-DR-Scan  
        tms = 0; @(posedge tck); // Capture-DR
        
        // Shift 32 bits
        for (int i = 0; i < 32; i++) begin
            tdi = 1'b0; // Shift in zeros
            tms = (i == 31) ? 1'b1 : 1'b0;
            @(posedge tck);
            $display("DR Shift %d: TDI=%b, TDO=%b", i, tdi, tdo);
        end
        
        tms = 0; @(posedge tck); // Update-DR
        
        $display("=== Testing BYPASS ===");
        
        // Load BYPASS instruction  
        tms = 1; @(posedge tck); // Select-IR-Scan
        tms = 0; @(posedge tck); // Capture-IR
        
        for (int i = 0; i < 4; i++) begin
            tdi = (4'b1111 >> i) & 1'b1; // BYPASS = 1111
            tms = (i == 3) ? 1'b1 : 1'b0;
            @(posedge tck);
        end
        
        tms = 0; @(posedge tck); // Update-IR
        tms = 0; @(posedge tck); // Run-Test/Idle
        
        // Shift bypass register
        tms = 1; @(posedge tck); // Select-DR-Scan
        tms = 0; @(posedge tck); // Capture-DR
        
        for (int i = 0; i < 5; i++) begin // Only need few bits for bypass
            tdi = (i % 2); // Alternate pattern
            tms = (i == 4) ? 1'b1 : 1'b0;
            @(posedge tck);
            $display("BYPASS Shift %d: TDI=%b, TDO=%b", i, tdi, tdo);
        end
        
        tms = 0; @(posedge tck); // Update-DR
        
        repeat(10) @(posedge tck);
        $finish;
    end

endmodule