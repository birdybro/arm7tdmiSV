// ARM7TDMI JTAG TAP Controller
// Implements IEEE 1149.1 JTAG Test Access Port
`timescale 1ns/1ps

module arm7tdmi_jtag_tap (
    // JTAG pins
    input  logic        tck,        // Test clock
    input  logic        tms,        // Test mode select  
    input  logic        tdi,        // Test data in
    output logic        tdo,        // Test data out
    input  logic        trst_n,     // Test reset (optional)
    
    // TAP controller state outputs
    output logic        test_logic_reset,
    output logic        run_test_idle,
    output logic        select_dr_scan,
    output logic        capture_dr,
    output logic        shift_dr,
    output logic        exit1_dr,
    output logic        pause_dr,
    output logic        exit2_dr,
    output logic        update_dr,
    output logic        select_ir_scan,
    output logic        capture_ir,
    output logic        shift_ir,
    output logic        exit1_ir,
    output logic        pause_ir,
    output logic        exit2_ir,
    output logic        update_ir,
    
    // Chain selection outputs
    output logic        bypass_select,
    output logic        idcode_select,
    output logic        ice_select,
    output logic        scan_n_select,
    
    // Data from external scan chains only
    input  logic        ice_tdo,
    input  logic        scan_n_tdo,
    
    // Current instruction register value
    output logic [3:0]  current_ir
);

    // JTAG TAP Controller State Machine (IEEE 1149.1)
    // Using localparam instead of enum for Icarus Verilog compatibility
    localparam TEST_LOGIC_RESET = 4'h0;
    localparam RUN_TEST_IDLE    = 4'h1;
    localparam SELECT_DR_SCAN   = 4'h2;
    localparam CAPTURE_DR       = 4'h3;
    localparam SHIFT_DR         = 4'h4;
    localparam EXIT1_DR         = 4'h5;
    localparam PAUSE_DR         = 4'h6;
    localparam EXIT2_DR         = 4'h7;
    localparam UPDATE_DR        = 4'h8;
    localparam SELECT_IR_SCAN   = 4'h9;
    localparam CAPTURE_IR       = 4'hA;
    localparam SHIFT_IR         = 4'hB;
    localparam EXIT1_IR         = 4'hC;
    localparam PAUSE_IR         = 4'hD;
    localparam EXIT2_IR         = 4'hE;
    localparam UPDATE_IR        = 4'hF;
    
    logic [3:0] tap_state, tap_next_state;
    
    // ARM7TDMI JTAG Instructions (4-bit)
    localparam EXTEST    = 4'b0000;  // External test
    localparam SCAN_N    = 4'b0010;  // Scan chain select
    localparam SAMPLE    = 4'b0011;  // Sample/preload
    localparam RESTART   = 4'b0100;  // Restart
    localparam CLAMP     = 4'b0101;  // Clamp
    localparam HIGHZ     = 4'b0111;  // High impedance
    localparam CLAMPZ    = 4'b1001;  // Clamp with high-Z
    localparam INTEST    = 4'b1100;  // Internal test
    localparam IDCODE    = 4'b1110;  // ID code
    localparam BYPASS    = 4'b1111;  // Bypass
    
    // Instruction register and data register
    logic [3:0] instruction_reg;
    logic [3:0] ir_shift_reg;
    logic       bypass_reg;
    
    // ARM7TDMI ID Code (32-bit)
    // Format: Version[31:28] | PartNumber[27:12] | ManufacturerID[11:1] | 1'b1
    localparam ARM7TDMI_IDCODE = 32'h07926041; // Example ARM7TDMI ID
    logic [31:0] idcode_shift_reg;
    
    //===========================================
    // TAP Controller State Machine
    //===========================================
    
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tap_state <= TEST_LOGIC_RESET;
        end else begin
            if (tap_state != tap_next_state) begin
                $display("TAP: State %1X -> %1X", tap_state, tap_next_state);
            end
            tap_state <= tap_next_state;
        end
    end
    
    // TAP state machine next state logic
    always_comb begin
        case (tap_state)
            TEST_LOGIC_RESET: begin
                tap_next_state = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            end
            
            RUN_TEST_IDLE: begin
                tap_next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            end
            
            SELECT_DR_SCAN: begin
                tap_next_state = tms ? SELECT_IR_SCAN : CAPTURE_DR;
            end
            
            CAPTURE_DR: begin
                tap_next_state = tms ? EXIT1_DR : SHIFT_DR;
            end
            
            SHIFT_DR: begin
                tap_next_state = tms ? EXIT1_DR : SHIFT_DR;
            end
            
            EXIT1_DR: begin
                tap_next_state = tms ? UPDATE_DR : PAUSE_DR;
            end
            
            PAUSE_DR: begin
                tap_next_state = tms ? EXIT2_DR : PAUSE_DR;
            end
            
            EXIT2_DR: begin
                tap_next_state = tms ? UPDATE_DR : SHIFT_DR;
            end
            
            UPDATE_DR: begin
                tap_next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            end
            
            SELECT_IR_SCAN: begin
                tap_next_state = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
            end
            
            CAPTURE_IR: begin
                tap_next_state = tms ? EXIT1_IR : SHIFT_IR;
            end
            
            SHIFT_IR: begin
                tap_next_state = tms ? EXIT1_IR : SHIFT_IR;
            end
            
            EXIT1_IR: begin
                tap_next_state = tms ? UPDATE_IR : PAUSE_IR;
            end
            
            PAUSE_IR: begin
                tap_next_state = tms ? EXIT2_IR : PAUSE_IR;
            end
            
            EXIT2_IR: begin
                tap_next_state = tms ? UPDATE_IR : SHIFT_IR;
            end
            
            UPDATE_IR: begin
                tap_next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            end
            
            default: begin
                tap_next_state = TEST_LOGIC_RESET;
            end
        endcase
    end
    
    //===========================================
    // State Output Assignments
    //===========================================
    
    assign test_logic_reset = (tap_next_state == TEST_LOGIC_RESET);
    assign run_test_idle    = (tap_next_state == RUN_TEST_IDLE);
    assign select_dr_scan   = (tap_next_state == SELECT_DR_SCAN);
    assign capture_dr       = (tap_next_state == CAPTURE_DR);
    assign shift_dr         = (tap_next_state == SHIFT_DR);
    assign exit1_dr         = (tap_next_state == EXIT1_DR);
    assign pause_dr         = (tap_next_state == PAUSE_DR);
    assign exit2_dr         = (tap_next_state == EXIT2_DR);
    assign update_dr        = (tap_next_state == UPDATE_DR);
    assign select_ir_scan   = (tap_next_state == SELECT_IR_SCAN);
    assign capture_ir       = (tap_next_state == CAPTURE_IR);
    assign shift_ir         = (tap_next_state == SHIFT_IR);
    assign exit1_ir         = (tap_next_state == EXIT1_IR);
    assign pause_ir         = (tap_next_state == PAUSE_IR);
    assign exit2_ir         = (tap_next_state == EXIT2_IR);
    assign update_ir        = (tap_next_state == UPDATE_IR);
    
    //===========================================
    // Instruction Register
    //===========================================
    
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            instruction_reg <= IDCODE;  // Default to IDCODE on reset
            ir_shift_reg <= 4'b0;
        end else begin
            if (update_ir) begin
                // Update instruction register
                instruction_reg <= ir_shift_reg;
                $display("TAP: Updating IR to 0x%1X (state=%1X)", ir_shift_reg, tap_state);
            end else if (capture_ir) begin
                // Capture pattern: 4'b0001 (ARM specification)
                ir_shift_reg <= 4'b0001;
                $display("TAP: Capturing IR pattern 0x1");
            end else if (shift_ir) begin
                // Shift instruction register
                ir_shift_reg <= {tdi, ir_shift_reg[3:1]};
                $display("TAP: Shifting IR: TDI=%b, ir_shift_reg=0x%1X -> 0x%1X (state=%1X)", tdi, ir_shift_reg, {tdi, ir_shift_reg[3:1]}, tap_state);
            end
        end
    end
    
    assign current_ir = instruction_reg;
    
    //===========================================
    // Chain Selection Logic
    //===========================================
    
    always_comb begin
        // Default all chains deselected
        bypass_select = 1'b0;
        idcode_select = 1'b0;
        ice_select = 1'b0;
        scan_n_select = 1'b0;
        
        // Select chain based on current instruction
        case (instruction_reg)
            BYPASS: bypass_select = 1'b1;
            IDCODE: idcode_select = 1'b1;
            INTEST: begin
                ice_select = 1'b1;      // EmbeddedICE chain
                $display("TAP: INTEST instruction active, ice_select=1");
            end
            SCAN_N: scan_n_select = 1'b1;
            default: bypass_select = 1'b1;  // Default to bypass
        endcase
    end
    
    //===========================================
    // Data Registers
    //===========================================
    
    // Bypass register (1-bit) - simple delay register
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            bypass_reg <= 1'b0;
        end else if (shift_dr && bypass_select) begin
            bypass_reg <= tdi;
        end else if (capture_dr && bypass_select) begin
            bypass_reg <= 1'b0;  // Capture fixed value
        end
    end
    
    // IDCODE register (32-bit)
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            idcode_shift_reg <= ARM7TDMI_IDCODE;
        end else if (capture_dr && idcode_select) begin
            idcode_shift_reg <= ARM7TDMI_IDCODE;
        end else if (shift_dr && idcode_select) begin
            idcode_shift_reg <= {tdi, idcode_shift_reg[31:1]};
        end
    end
    
    //===========================================
    // TDO Output Multiplexer
    //===========================================
    
    always_comb begin
        if (shift_ir) begin
            // Shifting instruction register
            tdo = ir_shift_reg[0];
        end else if (shift_dr) begin
            // Shifting data register - select based on active chain
            if (bypass_select) begin
                tdo = bypass_reg;
            end else if (idcode_select) begin
                tdo = idcode_shift_reg[0];
            end else if (ice_select) begin
                tdo = ice_tdo;
            end else if (scan_n_select) begin
                tdo = scan_n_tdo;
            end else begin
                tdo = bypass_reg;  // Default to bypass
            end
        end else begin
            tdo = 1'b0;
        end
    end
    
endmodule