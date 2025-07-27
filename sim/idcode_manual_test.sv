// Manual IDCODE test to verify bit-by-bit operation
`timescale 1ns/1ps

module idcode_manual_test;

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

    task jtag_reset();
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
    endtask

    task shift_ir(input [3:0] instruction);
        // Select-IR-Scan
        tms = 1;
        @(posedge tck);
        
        // Capture-IR
        tms = 0;
        @(posedge tck);
        
        // Shift-IR (4 bits)
        for (int i = 0; i < 4; i++) begin
            tdi = instruction[i];
            tms = (i == 3) ? 1'b1 : 1'b0;
            @(posedge tck);
        end
        
        // Update-IR
        tms = 0;
        @(posedge tck);
    endtask

    initial begin
        $dumpfile("idcode_manual_test.vcd");
        $dumpvars(0, idcode_manual_test);
        
        logic [31:0] captured_idcode = 0;
        
        // Reset
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(2) @(posedge tck);
        
        $display("=== Manual IDCODE Test ===");
        $display("Expected IDCODE: 0x07926041");
        
        jtag_reset();
        shift_ir(4'b1110); // IDCODE
        
        // Manual DR shift for IDCODE
        tms = 1; @(posedge tck); // Select-DR-Scan
        tms = 0; @(posedge tck); // Capture-DR
        
        $display("Starting IDCODE shift (LSB first):");
        
        for (int i = 0; i < 32; i++) begin
            tdi = 1'b0; // Shift in zeros
            tms = (i == 31) ? 1'b1 : 1'b0;
            @(posedge tck);
            if (i < 32) captured_idcode[i] = tdo; // Capture bit by bit
            $display("Bit %2d: TDO=%b", i, tdo);
        end
        
        tms = 0; @(posedge tck); // Update-DR
        
        $display("Captured IDCODE: 0x%08X", captured_idcode);
        
        if (captured_idcode == 32'h07926041) begin
            $display("✅ IDCODE CORRECT!");
        end else begin
            $display("❌ IDCODE INCORRECT!");
            $display("Expected: 0x07926041");
            $display("Got:      0x%08X", captured_idcode);
        end
        
        // Test BYPASS as well
        $display("\n=== Manual BYPASS Test ===");
        
        jtag_reset();
        shift_ir(4'b1111); // BYPASS
        
        tms = 1; @(posedge tck); // Select-DR-Scan
        tms = 0; @(posedge tck); // Capture-DR
        
        // Shift a pattern into bypass
        logic [7:0] bypass_pattern = 8'b10101010;
        logic [7:0] bypass_result = 0;
        
        for (int i = 0; i < 8; i++) begin
            tdi = bypass_pattern[i];
            tms = (i == 7) ? 1'b1 : 1'b0;
            @(posedge tck);
            if (i < 8) bypass_result[i] = tdo;
            $display("BYPASS Bit %d: TDI=%b, TDO=%b", i, bypass_pattern[i], tdo);
        end
        
        tms = 0; @(posedge tck); // Update-DR
        
        $display("BYPASS Input:  0x%02X", bypass_pattern);
        $display("BYPASS Output: 0x%02X", bypass_result);
        
        // For bypass, we expect a 1-bit shift
        logic [7:0] expected_bypass;
        expected_bypass = {1'b0, bypass_pattern[7:1]};
        if (bypass_result == expected_bypass) begin
            $display("✅ BYPASS CORRECT!");
        end else begin
            $display("❌ BYPASS INCORRECT!");
            $display("Expected: 0x%02X", expected_bypass);
        end
        
        repeat(10) @(posedge tck);
        $finish;
    end

endmodule