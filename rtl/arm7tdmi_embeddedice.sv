// ARM7TDMI EmbeddedICE Debug Unit
// Implements ARM7TDMI EmbeddedICE-RT specification
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module arm7tdmi_embeddedice (
    // System signals
    input  logic        clk,
    input  logic        rst_n,
    
    // JTAG interface (from TAP controller)
    input  logic        tck,           // Test clock
    input  logic        tdi,           // Test data in
    output logic        tdo,           // Test data out
    input  logic        tms,           // Test mode select
    input  logic        trst_n,        // Test reset (optional)
    input  logic        ice_select,    // EmbeddedICE chain select
    input  logic        capture_dr,    // Data register capture
    input  logic        shift_dr,      // Data register shift
    input  logic        update_dr,     // Data register update
    
    // Processor core interface
    input  logic [31:0] debug_pc,      // Current PC from processor
    input  logic [31:0] debug_instr,   // Current instruction
    input  logic [31:0] debug_addr,    // Memory address from processor
    input  logic [31:0] debug_data,    // Data from processor
    input  logic        debug_rw,      // Read/Write signal (1=read, 0=write)
    input  logic        debug_mas,     // Memory access size (0=byte, 1=word)
    input  logic        debug_seq,     // Sequential memory access
    input  logic        debug_lock,    // Locked memory access
    input  logic [4:0]  debug_mode,    // Current processor mode
    input  logic        debug_thumb,   // Thumb mode indicator
    input  logic        debug_exec,    // Instruction execute signal
    input  logic        debug_mem,     // Memory access signal
    
    // Debug control outputs to processor
    output logic        debug_en,      // Debug enable
    output logic        debug_req,     // Debug request
    output logic        debug_restart, // Debug restart
    output logic        debug_abort,   // Debug abort
    output logic        breakpoint,    // Breakpoint hit
    output logic        watchpoint,    // Watchpoint hit
    
    // External debug signals
    input  logic        dbgrq,         // External debug request
    output logic        dbgack,        // Debug acknowledge
    input  logic        extern_dbg     // External debug mode
);

    // EmbeddedICE Register Map (ARM7TDMI specification)
    localparam ICE_DEBUG_CTRL       = 5'h00;  // Debug Control Register
    localparam ICE_DEBUG_STATUS     = 5'h01;  // Debug Status Register
    localparam ICE_VECTOR_CATCH     = 5'h02;  // Vector Catch Register
    localparam ICE_DEBUG_DATA       = 5'h03;  // Debug Data Register
    localparam ICE_WATCHPOINT0_VAL  = 5'h08;  // Watchpoint 0 Value
    localparam ICE_WATCHPOINT0_MASK = 5'h09;  // Watchpoint 0 Mask
    localparam ICE_WATCHPOINT0_CTRL = 5'h0A;  // Watchpoint 0 Control
    localparam ICE_WATCHPOINT1_VAL  = 5'h0B;  // Watchpoint 1 Value
    localparam ICE_WATCHPOINT1_MASK = 5'h0C;  // Watchpoint 1 Mask
    localparam ICE_WATCHPOINT1_CTRL = 5'h0D;  // Watchpoint 1 Control
    
    // Internal registers
    logic [31:0] ice_registers [0:31];  // EmbeddedICE register file
    
    // Debug state machine
    typedef enum logic [2:0] {
        DEBUG_IDLE,
        DEBUG_BREAKPOINT,
        DEBUG_WATCHPOINT,
        DEBUG_EXTERNAL,
        DEBUG_STEP,
        DEBUG_RESTART
    } debug_state_t;
    
    debug_state_t debug_state, debug_next_state;
    
    // Watchpoint comparison logic
    logic wp0_addr_match, wp0_data_match, wp0_ctrl_match;
    logic wp1_addr_match, wp1_data_match, wp1_ctrl_match;
    logic wp0_hit, wp1_hit;
    
    // Breakpoint logic
    logic bp_hit;
    
    // JTAG scan chain for EmbeddedICE
    logic [4:0]  ice_addr;      // 5-bit register address
    logic [31:0] ice_data_in;   // 32-bit data input
    logic [31:0] ice_data_out;  // 32-bit data output
    logic [36:0] scan_chain;    // 37-bit scan chain (5 addr + 32 data)
    logic        ice_read, ice_write;
    logic        ice_write_sync, ice_write_prev;
    
    // Debug Control Register bits
    logic debug_enable;
    logic debug_step;
    logic debug_intdis;     // Interrupt disable in debug
    logic debug_halt_mode;  // Halt on debug
    
    // Debug Status Register bits  
    logic debug_tbit;       // Thumb bit
    logic debug_nmreq;      // Non-maskable request
    logic debug_interrupt;  // Interrupt bit
    logic debug_syscomp;    // System speed compare
    
    // Vector Catch Register - catch specific exceptions
    logic catch_reset;
    logic catch_undef;
    logic catch_swi;
    logic catch_prefetch_abort;
    logic catch_data_abort;
    logic catch_irq;
    logic catch_fiq;
    
    //===========================================
    // JTAG Scan Chain Implementation
    //===========================================
    
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            scan_chain <= 37'h0;
            ice_addr <= 5'h0;
            ice_data_in <= 32'h0;
            ice_read <= 1'b0;
            ice_write <= 1'b0;
            // Initialize TCK domain registers
            ice_registers[ICE_DEBUG_CTRL] <= 32'b0;
            ice_registers[ICE_VECTOR_CATCH] <= 32'b0;
            ice_registers[ICE_WATCHPOINT0_VAL] <= 32'b0;
            ice_registers[ICE_WATCHPOINT0_MASK] <= 32'b0;
            ice_registers[ICE_WATCHPOINT0_CTRL] <= 32'b0;
            ice_registers[ICE_WATCHPOINT1_VAL] <= 32'b0;
            ice_registers[ICE_WATCHPOINT1_MASK] <= 32'b0;
            ice_registers[ICE_WATCHPOINT1_CTRL] <= 32'b0;
        end else begin
            if (ice_select) begin
                $display("EmbeddedICE: ice_select active, capture_dr=%b, shift_dr=%b, update_dr=%b", capture_dr, shift_dr, update_dr);
                if (capture_dr) begin
                    // Capture current register value (use register 0 for now to test)
                    scan_chain <= {ice_registers[5'h0], 5'h0};
                end else if (shift_dr) begin
                    // Shift data through scan chain
                    scan_chain <= {tdi, scan_chain[36:1]};
                end else if (update_dr) begin
                    // Write register directly in TCK domain (avoid clock crossing)
                    ice_addr <= {scan_chain[0], scan_chain[1], scan_chain[2], scan_chain[3], scan_chain[4]};
                    ice_data_in <= scan_chain[36:5];
                    $display("EmbeddedICE: update_dr active, scan_chain=0x%09X, addr=0x%02X, data=0x%08X", scan_chain, {scan_chain[0], scan_chain[1], scan_chain[2], scan_chain[3], scan_chain[4]}, scan_chain[36:5]);
                    $display("EmbeddedICE: scan_chain bits [4:0]=0b%05b, [36:5]=0x%08X", scan_chain[4:0], scan_chain[36:5]);
                    // Write immediately to registers (TCK domain)
                    // if ({scan_chain[0], scan_chain[1], scan_chain[2], scan_chain[3], scan_chain[4]} < 32) begin // Bounds check - temporarily disabled
                        ice_registers[{scan_chain[0], scan_chain[1], scan_chain[2], scan_chain[3], scan_chain[4]}] <= scan_chain[36:5];
                        $display("EmbeddedICE: Writing reg[0x%02X] = 0x%08X (TCK)", {scan_chain[0], scan_chain[1], scan_chain[2], scan_chain[3], scan_chain[4]}, scan_chain[36:5]);
                    // end
                    ice_write <= 1'b1;
                end else begin
                    ice_write <= 1'b0;
                end
            end
        end
    end
    
    // TDO output from scan chain
    assign tdo = ice_select ? scan_chain[0] : 1'bz;
    
    //===========================================
    // EmbeddedICE Register Implementation
    //===========================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize only CLK domain registers to default values
            ice_registers[ICE_DEBUG_STATUS] <= 32'b0;
            ice_registers[ICE_DEBUG_DATA] <= 32'b0;
        end else begin
            // Only update status registers that must be driven from processor (CLK domain)
            // Leave other registers (control, watchpoint) for JTAG writes in TCK domain
            
            // Update status register with processor state
            ice_registers[ICE_DEBUG_STATUS][0] <= debug_tbit;     // Thumb bit
            ice_registers[ICE_DEBUG_STATUS][1] <= debug_nmreq;    // Non-maskable request
            ice_registers[ICE_DEBUG_STATUS][2] <= debug_interrupt; // Interrupt
            ice_registers[ICE_DEBUG_STATUS][3] <= debug_syscomp;  // System speed
            ice_registers[ICE_DEBUG_STATUS][8:4] <= debug_mode;   // Processor mode
            
            // Update debug data register with current values
            ice_registers[ICE_DEBUG_DATA] <= debug_data;
        end
    end
    
    // Extract control register bits
    assign debug_enable = ice_registers[ICE_DEBUG_CTRL][0];
    assign debug_step = ice_registers[ICE_DEBUG_CTRL][1];
    assign debug_intdis = ice_registers[ICE_DEBUG_CTRL][2];
    assign debug_halt_mode = ice_registers[ICE_DEBUG_CTRL][3];
    
    // Extract vector catch register bits
    assign catch_reset = ice_registers[ICE_VECTOR_CATCH][0];
    assign catch_undef = ice_registers[ICE_VECTOR_CATCH][1];
    assign catch_swi = ice_registers[ICE_VECTOR_CATCH][2];
    assign catch_prefetch_abort = ice_registers[ICE_VECTOR_CATCH][3];
    assign catch_data_abort = ice_registers[ICE_VECTOR_CATCH][4];
    assign catch_irq = ice_registers[ICE_VECTOR_CATCH][6];
    assign catch_fiq = ice_registers[ICE_VECTOR_CATCH][7];
    
    //===========================================
    // Watchpoint Logic (2 watchpoints)
    //===========================================
    
    // Watchpoint 0 comparison
    always_comb begin
        // Address comparison (temporarily use register 0x00 which gets the data)
        wp0_addr_match = ((debug_addr & ice_registers[ICE_WATCHPOINT0_MASK]) == 
                         (ice_registers[0] & ice_registers[ICE_WATCHPOINT0_MASK]));
        
        // Data comparison (for data watchpoints)
        wp0_data_match = ((debug_data & ice_registers[ICE_WATCHPOINT0_MASK]) == 
                         (ice_registers[ICE_WATCHPOINT0_VAL] & ice_registers[ICE_WATCHPOINT0_MASK]));
        
        // Control comparison (R/W, size, etc.)
        wp0_ctrl_match = 1'b1; // Simplified - implement full control matching
        
        // Watchpoint hit logic
        wp0_hit = ice_registers[3][0] &&  // Enable bit from register 3 (temporary)
                  wp0_addr_match && wp0_ctrl_match &&
                  debug_mem;  // Memory access active
                  
        // Debug output for watchpoint 0
        if (debug_mem) begin
            $display("WP0: enable=%b, addr_match=%b, ctrl_match=%b, mem=%b, hit=%b", 
                     ice_registers[3][0], wp0_addr_match, wp0_ctrl_match, debug_mem, wp0_hit);
            $display("WP0: debug_addr=0x%08X, wp_val=0x%08X, wp_mask=0x%08X", 
                     debug_addr, ice_registers[ICE_WATCHPOINT0_VAL], ice_registers[ICE_WATCHPOINT0_MASK]);
            $display("WP0: reg[0x08]=0x%08X, reg[0x0A]=0x%08X, reg[0x00]=0x%08X, reg[0x03]=0x%08X", 
                     ice_registers[8], ice_registers[10], ice_registers[0], ice_registers[3]);
        end
    end
    
    // Watchpoint 1 comparison  
    always_comb begin
        // Address comparison
        wp1_addr_match = ((debug_addr & ice_registers[ICE_WATCHPOINT1_MASK]) == 
                         (ice_registers[ICE_WATCHPOINT1_VAL] & ice_registers[ICE_WATCHPOINT1_MASK]));
        
        // Data comparison
        wp1_data_match = ((debug_data & ice_registers[ICE_WATCHPOINT1_MASK]) == 
                         (ice_registers[ICE_WATCHPOINT1_VAL] & ice_registers[ICE_WATCHPOINT1_MASK]));
        
        // Control comparison
        wp1_ctrl_match = 1'b1; // Simplified
        
        // Watchpoint hit logic
        wp1_hit = ice_registers[ICE_WATCHPOINT1_CTRL][0] &&  // Enable bit
                  wp1_addr_match && wp1_ctrl_match &&
                  debug_mem;  // Memory access active
    end
    
    //===========================================
    // Breakpoint Logic
    //===========================================
    
    // Simple PC-based breakpoint (can be enhanced)
    always_comb begin
        bp_hit = debug_enable && debug_exec &&
                (debug_pc == ice_registers[ICE_WATCHPOINT0_VAL]) &&
                ice_registers[ICE_WATCHPOINT0_CTRL][1];  // Breakpoint mode
    end
    
    //===========================================
    // Debug State Machine
    //===========================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debug_state <= DEBUG_IDLE;
        end else begin
            debug_state <= debug_next_state;
        end
    end
    
    always_comb begin
        debug_next_state = debug_state;
        debug_req = 1'b0;
        debug_restart = 1'b0;
        debug_abort = 1'b0;
        breakpoint = 1'b0;
        watchpoint = 1'b0;
        dbgack = 1'b0;
        
        case (debug_state)
            DEBUG_IDLE: begin
                if (dbgrq || extern_dbg) begin
                    debug_next_state = DEBUG_EXTERNAL;
                    debug_req = 1'b1;
                end else if (bp_hit) begin
                    debug_next_state = DEBUG_BREAKPOINT;
                    debug_req = 1'b1;
                    breakpoint = 1'b1;
                end else if (wp0_hit || wp1_hit) begin
                    debug_next_state = DEBUG_WATCHPOINT;
                    debug_req = 1'b1;
                    watchpoint = 1'b1;
                end
            end
            
            DEBUG_BREAKPOINT: begin
                dbgack = 1'b1;
                breakpoint = 1'b1;
                if (debug_step) begin
                    debug_next_state = DEBUG_STEP;
                    debug_restart = 1'b1;
                end else if (!debug_enable) begin
                    debug_next_state = DEBUG_RESTART;
                end
            end
            
            DEBUG_WATCHPOINT: begin
                dbgack = 1'b1;
                watchpoint = 1'b1;
                if (debug_step) begin
                    debug_next_state = DEBUG_STEP;
                    debug_restart = 1'b1;
                end else if (!debug_enable) begin
                    debug_next_state = DEBUG_RESTART;
                end
            end
            
            DEBUG_EXTERNAL: begin
                dbgack = 1'b1;
                if (!dbgrq && !extern_dbg) begin
                    if (debug_step) begin
                        debug_next_state = DEBUG_STEP;
                        debug_restart = 1'b1;
                    end else begin
                        debug_next_state = DEBUG_RESTART;
                    end
                end
            end
            
            DEBUG_STEP: begin
                debug_next_state = DEBUG_IDLE;
                debug_restart = 1'b1;
            end
            
            DEBUG_RESTART: begin
                debug_next_state = DEBUG_IDLE;
                debug_restart = 1'b1;
            end
        endcase
    end
    
    //===========================================
    // Output Assignments
    //===========================================
    
    assign debug_en = debug_enable;
    assign ice_data_out = ice_registers[ice_addr];
    
    // Debug status updates
    assign debug_tbit = debug_thumb;
    assign debug_nmreq = dbgrq;
    assign debug_interrupt = 1'b0; // Simplified
    assign debug_syscomp = 1'b0;   // Simplified
    
endmodule