// ARM7TDMI Debug Wrapper
// Integrates JTAG TAP, EmbeddedICE, and boundary scan components
`timescale 1ns/1ps

import arm7tdmi_pkg::*;

module arm7tdmi_debug_wrapper (
    // System signals
    input  logic        clk,
    input  logic        rst_n,
    
    // JTAG pins
    input  logic        tck,
    input  logic        tms,
    input  logic        tdi,
    output logic        tdo,
    input  logic        trst_n,
    
    // External debug signals
    input  logic        dbgrq,         // Debug request
    output logic        dbgack,        // Debug acknowledge
    input  logic        extern_dbg,    // External debug mode
    
    // Processor core debug interface
    input  logic [31:0] debug_pc,
    input  logic [31:0] debug_instr,
    input  logic [31:0] debug_addr,
    input  logic [31:0] debug_data,
    input  logic        debug_rw,
    input  logic        debug_mas,
    input  logic        debug_seq,
    input  logic        debug_lock,
    input  logic [4:0]  debug_mode,
    input  logic        debug_thumb,
    input  logic        debug_exec,
    input  logic        debug_mem,
    
    // Debug control outputs to processor
    output logic        debug_en,
    output logic        debug_req,
    output logic        debug_restart,
    output logic        debug_abort,
    output logic        breakpoint,
    output logic        watchpoint,
    
    // Boundary scan interface (simplified)
    input  logic [31:0] addr_core_out,
    output logic [31:0] addr_pin_out,
    input  logic [31:0] addr_pin_in,
    input  logic [31:0] data_core_out,
    output logic [31:0] data_pin_out,
    input  logic [31:0] data_pin_in,
    output logic [31:0] data_core_in,
    input  logic        nrw_core_out,
    output logic        nrw_pin_out,
    input  logic        nrw_pin_in,
    output logic        nrw_core_in,
    input  logic        nwait_pin_in,
    output logic        nwait_core_in,
    input  logic        abort_pin_in,
    output logic        abort_core_in,
    input  logic        noe_core_out,
    output logic        noe_pin_out,
    input  logic        nwe_core_out,
    output logic        nwe_pin_out
);

    // TAP controller signals
    logic test_logic_reset, run_test_idle;
    logic select_dr_scan, capture_dr, shift_dr, exit1_dr;
    logic pause_dr, exit2_dr, update_dr;
    logic select_ir_scan, capture_ir, shift_ir, exit1_ir;
    logic pause_ir, exit2_ir, update_ir;
    
    // Chain selection signals
    logic bypass_select, idcode_select, ice_select, scan_n_select;
    logic [3:0] current_ir;
    
    // Scan chain TDO signals
    logic ice_tdo, scan_n_tdo;
    logic bscan_tdo, core_scan_tdo, debug_tdo;
    
    // Scan chain control
    logic core_scan_select, bscan_select, debug_select;
    logic scan_enable, test_mode, scan_mode;
    logic [3:0] scan_chain_id;
    
    // Test mode controls
    logic extest_mode, sample_mode;
    
    //===========================================
    // JTAG TAP Controller
    //===========================================
    
    arm7tdmi_jtag_tap u_tap_controller (
        .tck                (tck),
        .tms                (tms),
        .tdi                (tdi),
        .tdo                (tdo),
        .trst_n             (trst_n),
        
        // TAP state outputs
        .test_logic_reset   (test_logic_reset),
        .run_test_idle      (run_test_idle),
        .select_dr_scan     (select_dr_scan),
        .capture_dr         (capture_dr),
        .shift_dr           (shift_dr),
        .exit1_dr           (exit1_dr),
        .pause_dr           (pause_dr),
        .exit2_dr           (exit2_dr),
        .update_dr          (update_dr),
        .select_ir_scan     (select_ir_scan),
        .capture_ir         (capture_ir),
        .shift_ir           (shift_ir),
        .exit1_ir           (exit1_ir),
        .pause_ir           (pause_ir),
        .exit2_ir           (exit2_ir),
        .update_ir          (update_ir),
        
        // Chain selection
        .bypass_select      (bypass_select),
        .idcode_select      (idcode_select),
        .ice_select         (ice_select),
        .scan_n_select      (scan_n_select),
        
        // Chain TDO inputs
        .ice_tdo            (ice_tdo),
        .scan_n_tdo         (scan_n_tdo),
        
        .current_ir         (current_ir)
    );
    
    //===========================================
    // EmbeddedICE Debug Unit
    //===========================================
    
    arm7tdmi_embeddedice u_embeddedice (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // JTAG interface
        .tck                (tck),
        .tdi                (tdi),
        .tdo                (ice_tdo),
        .tms                (tms),
        .trst_n             (trst_n),
        .ice_select         (ice_select),
        .capture_dr         (capture_dr),
        .shift_dr           (shift_dr),
        .update_dr          (update_dr),
        
        // Processor interface
        .debug_pc           (debug_pc),
        .debug_instr        (debug_instr),
        .debug_addr         (debug_addr),
        .debug_data         (debug_data),
        .debug_rw           (debug_rw),
        .debug_mas          (debug_mas),
        .debug_seq          (debug_seq),
        .debug_lock         (debug_lock),
        .debug_mode         (debug_mode),
        .debug_thumb        (debug_thumb),
        .debug_exec         (debug_exec),
        .debug_mem          (debug_mem),
        
        // Debug control outputs
        .debug_en           (debug_en),
        .debug_req          (debug_req),
        .debug_restart      (debug_restart),
        .debug_abort        (debug_abort),
        .breakpoint         (breakpoint),
        .watchpoint         (watchpoint),
        
        // External debug
        .dbgrq              (dbgrq),
        .dbgack             (dbgack),
        .extern_dbg         (extern_dbg)
    );
    
    //===========================================
    // Scan Chain Selector
    //===========================================
    
    arm7tdmi_scan_chain u_scan_chain (
        .tck                (tck),
        .tdi                (tdi),
        .tdo                (scan_n_tdo),
        .scan_n_select      (scan_n_select),
        .capture_dr         (capture_dr),
        .shift_dr           (shift_dr),
        .update_dr          (update_dr),
        .trst_n             (trst_n),
        
        .scan_chain_id      (scan_chain_id),
        
        // Scan chain TDO inputs
        .core_scan_tdo      (core_scan_tdo),
        .bscan_tdo          (bscan_tdo),
        .debug_tdo          (debug_tdo),
        
        // Selection outputs
        .core_scan_select   (core_scan_select),
        .bscan_select       (bscan_select),
        .debug_select       (debug_select),
        .scan_enable        (scan_enable),
        .test_mode          (test_mode),
        .scan_mode          (scan_mode)
    );
    
    //===========================================
    // Boundary Scan
    //===========================================
    
    arm7tdmi_boundary_scan u_boundary_scan (
        .tck                (tck),
        .tdi                (tdi),
        .tdo                (bscan_tdo),
        .bscan_select       (bscan_select),
        .capture_dr         (capture_dr),
        .shift_dr           (shift_dr),
        .update_dr          (update_dr),
        .trst_n             (trst_n),
        
        .test_mode          (test_mode),
        .extest_mode        (extest_mode),
        .sample_mode        (sample_mode),
        
        // External pin interface
        .addr_core_out      (addr_core_out),
        .addr_pin_out       (addr_pin_out),
        .addr_pin_in        (addr_pin_in),
        .data_core_out      (data_core_out),
        .data_pin_out       (data_pin_out),
        .data_pin_in        (data_pin_in),
        .data_core_in       (data_core_in),
        .nrw_core_out       (nrw_core_out),
        .nrw_pin_out        (nrw_pin_out),
        .nrw_pin_in         (nrw_pin_in),
        .nrw_core_in        (nrw_core_in),
        .nwait_pin_in       (nwait_pin_in),
        .nwait_core_in      (nwait_core_in),
        .abort_pin_in       (abort_pin_in),
        .abort_core_in      (abort_core_in),
        .noe_core_out       (noe_core_out),
        .noe_pin_out        (noe_pin_out),
        .nwe_core_out       (nwe_core_out),
        .nwe_pin_out        (nwe_pin_out)
    );
    
    //===========================================
    // Test Mode Control Logic
    //===========================================
    
    always_comb begin
        // Determine test modes based on current JTAG instruction
        extest_mode = (current_ir == 4'b0000);  // EXTEST
        sample_mode = (current_ir == 4'b0011);  // SAMPLE
        
        // Scan chain ID for SCAN_N instruction (simplified)
        scan_chain_id = 4'h0;  // Default to boundary scan
    end
    
    //===========================================
    // Default TDO Assignments for unused chains
    //===========================================
    
    // bypass_tdo and idcode_tdo are handled internally in TAP controller
    assign core_scan_tdo = 1'b0;  // No core scan chain implemented yet
    assign debug_tdo = ice_tdo;    // Debug chain same as EmbeddedICE
    
endmodule