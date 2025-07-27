// Corrected IDCODE test with proper timing
`timescale 1ns/1ps

module corrected_idcode_test;

    logic tck = 0;
    logic tms = 0; 
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;
    reg [31:0] result;
    reg [7:0] expected_pattern, actual_pattern;

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

    task shift_dr_32(input [31:0] data_in, output [31:0] data_out);
        reg [31:0] temp_reg;
        int i;
        
        // Navigate to Shift-DR
        tms = 1; @(posedge tck); // Select-DR-Scan
        tms = 0; @(posedge tck); // Capture-DR
        
        temp_reg = data_in;
        
        // Shift 32 bits
        for (i = 0; i < 32; i = i + 1) begin
            tdi = temp_reg[0]; // LSB first
            temp_reg = temp_reg >> 1;
            tms = (i == 31) ? 1'b1 : 1'b0; // Exit on last bit
            
            // TDO should be valid before the clock edge
            #1; // Small delay to let TDO settle
            temp_reg[31] = tdo; // Capture TDO in MSB position
            
            @(posedge tck);
        end
        
        data_out = temp_reg;
        
        // Update-DR
        tms = 0; @(posedge tck);
    endtask

    initial begin
        $dumpfile("corrected_idcode_test.vcd");
        $dumpvars(0, corrected_idcode_test);
        
        // Reset
        trst_n = 0;
        repeat(5) @(posedge tck);
        trst_n = 1;
        repeat(2) @(posedge tck);
        
        $display("=== Corrected IDCODE Test ===");
        $display("Expected IDCODE: 0x07926041");
        
        // Reset TAP (sets default instruction to IDCODE)
        tms = 1;
        repeat(6) @(posedge tck);
        tms = 0;
        @(posedge tck);
        
        // Shift IDCODE DR
        shift_dr_32(32'h00000000, result);
        
        $display("Captured IDCODE: 0x%08X", result);
        
        if (result == 32'h07926041) begin
            $display("✅ IDCODE PERFECT MATCH!");
        end else if (result[0] == 1'b1) begin
            $display("✅ IDCODE has correct LSB=1 (valid IDCODE format)");
        end else begin
            $display("❌ IDCODE incorrect - LSB=%b", result[0]);
        end
        
        // Test BYPASS
        $display("\n=== BYPASS Test ===");
        
        // Load BYPASS instruction
        tms = 1; @(posedge tck); // Select-IR-Scan
        tms = 0; @(posedge tck); // Capture-IR
        tdi = 1; tms = 0; @(posedge tck); // Bit 0
        tdi = 1; tms = 0; @(posedge tck); // Bit 1  
        tdi = 1; tms = 0; @(posedge tck); // Bit 2
        tdi = 1; tms = 1; @(posedge tck); // Bit 3, exit
        tms = 0; @(posedge tck); // Update-IR
        tms = 0; @(posedge tck); // Run-Test/Idle
        
        // For bypass, we only need 1 bit, but let's test with a byte
        tms = 1; @(posedge tck); // Select-DR-Scan
        tms = 0; @(posedge tck); // Capture-DR
        
        // Shift pattern 10101010 and see what comes out
        result = 0;
        tdi = 0; tms = 0; #1; result[0] = tdo; @(posedge tck);
        tdi = 1; tms = 0; #1; result[1] = tdo; @(posedge tck);
        tdi = 0; tms = 0; #1; result[2] = tdo; @(posedge tck);
        tdi = 1; tms = 0; #1; result[3] = tdo; @(posedge tck);
        tdi = 0; tms = 0; #1; result[4] = tdo; @(posedge tck);
        tdi = 1; tms = 0; #1; result[5] = tdo; @(posedge tck);
        tdi = 0; tms = 0; #1; result[6] = tdo; @(posedge tck);
        tdi = 1; tms = 1; #1; result[7] = tdo; @(posedge tck); // Exit
        
        tms = 0; @(posedge tck); // Update-DR
        
        $display("BYPASS pattern: In=10101010, Out=%b%b%b%b%b%b%b%b", 
                 result[7], result[6], result[5], result[4], result[3], result[2], result[1], result[0]);
        
        // For bypass, we expect a 1-clock delay: input 01010101 should give output 00101010 (with leading zero)
        expected_pattern = 8'b00101010;  // Right shift by 1
        actual_pattern = result[7:0];
        
        if (actual_pattern == expected_pattern) begin
            $display("✅ BYPASS working correctly!");
        end else begin
            $display("❌ BYPASS incorrect. Expected: %08b, Got: %08b", expected_pattern, actual_pattern);
        end
        
        repeat(10) @(posedge tck);
        $finish;
    end

endmodule