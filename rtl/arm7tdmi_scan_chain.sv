// ARM7TDMI Scan Chain Selector
// Handles multiple scan chains for boundary scan and internal testing
`timescale 1ns/1ps

module arm7tdmi_scan_chain (
    // JTAG interface
    input  logic        tck,
    input  logic        tdi,
    output logic        tdo,
    input  logic        scan_n_select,
    input  logic        capture_dr,
    input  logic        shift_dr,
    input  logic        update_dr,
    input  logic        trst_n,
    
    // Scan chain selection (SCAN_N instruction data)
    input  logic [3:0]  scan_chain_id,  // 4-bit scan chain identifier
    
    // Processor core scan chains
    input  logic        core_scan_tdo,   // Core logic scan chain
    input  logic        bscan_tdo,       // Boundary scan chain
    input  logic        debug_tdo,       // Debug scan chain
    
    // Scan chain control outputs
    output logic        core_scan_select,
    output logic        bscan_select, 
    output logic        debug_select,
    output logic        scan_enable,
    
    // Test control signals
    output logic        test_mode,
    output logic        scan_mode
);

    // ARM7TDMI Scan Chain IDs
    localparam SCAN_CHAIN_0 = 4'h0;  // Boundary scan
    localparam SCAN_CHAIN_1 = 4'h1;  // Debug scan chain
    localparam SCAN_CHAIN_2 = 4'h2;  // EmbeddedICE  
    localparam SCAN_CHAIN_3 = 4'h3;  // Reserved
    
    // Internal registers
    logic [3:0] chain_select_reg;
    logic       scan_active;
    
    //===========================================
    // Scan Chain Selection Register
    //===========================================
    
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            chain_select_reg <= SCAN_CHAIN_0;  // Default to boundary scan
        end else if (scan_n_select && update_dr) begin
            chain_select_reg <= scan_chain_id;
        end
    end
    
    //===========================================
    // Chain Selection Logic
    //===========================================
    
    always_comb begin
        // Default all chains deselected
        core_scan_select = 1'b0;
        bscan_select = 1'b0;
        debug_select = 1'b0;
        
        // Select active scan chain based on register
        case (chain_select_reg)
            SCAN_CHAIN_0: bscan_select = 1'b1;      // Boundary scan
            SCAN_CHAIN_1: debug_select = 1'b1;      // Debug scan
            SCAN_CHAIN_2: debug_select = 1'b1;      // EmbeddedICE (same as debug)
            SCAN_CHAIN_3: core_scan_select = 1'b1;  // Core logic scan
            default:      bscan_select = 1'b1;      // Default to boundary scan
        endcase
    end
    
    //===========================================
    // Test Mode Control
    //===========================================
    
    assign scan_active = scan_n_select && (capture_dr || shift_dr);
    assign scan_enable = scan_active || (chain_select_reg != SCAN_CHAIN_0);
    assign test_mode = scan_enable;
    assign scan_mode = shift_dr && scan_n_select;
    
    //===========================================
    // TDO Output Selection
    //===========================================
    
    always_comb begin
        if (scan_n_select && shift_dr) begin
            case (chain_select_reg)
                SCAN_CHAIN_0: tdo = bscan_tdo;
                SCAN_CHAIN_1: tdo = debug_tdo;
                SCAN_CHAIN_2: tdo = debug_tdo;   // EmbeddedICE
                SCAN_CHAIN_3: tdo = core_scan_tdo;
                default:      tdo = bscan_tdo;
            endcase
        end else begin
            tdo = 1'b0;
        end
    end
    
endmodule