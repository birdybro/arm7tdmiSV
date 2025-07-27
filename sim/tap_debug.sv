// TAP Debug - just watch signals
`timescale 1ns/1ps

module tap_debug;

    logic tck = 0;
    logic tms = 0; 
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;
    
    logic idcode_select;
    logic shift_dr;

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
        .shift_dr(shift_dr),
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
        .idcode_select(idcode_select),
        .ice_select(),
        .scan_n_select(),
        .ice_tdo(1'b0),
        .scan_n_tdo(1'b0),
        .current_ir()
    );

    initial begin
        $dumpfile("tap_debug.vcd");
        $dumpvars(0, tap_debug);
        
        // Reset
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(2) @(posedge tck);
        
        $display("=== TAP Debug - Watching TDO directly ===");
        
        // Reset TAP
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
        
        // The default instruction should be IDCODE after reset
        $display("After reset, IDCODE should be selected: %b", idcode_select);
        
        // Go directly to DR shift without changing instruction
        tms = 1; @(posedge tck); // Select-DR-Scan
        tms = 0; @(posedge tck); // Capture-DR
        
        $display("Starting IDCODE shift, shift_dr=%b, idcode_select=%b", shift_dr, idcode_select);
        
        // Just watch the first 8 bits
        for (int i = 0; i < 8; i++) begin
            tdi = 1'b0;
            tms = 1'b0;
            @(posedge tck);
            $display("Bit %d: TDO=%b (shift_dr=%b, idcode_select=%b)", i, tdo, shift_dr, idcode_select);
        end
        
        repeat(10) @(posedge tck);
        $finish;
    end

endmodule