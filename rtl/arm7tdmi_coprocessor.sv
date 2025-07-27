// ARM7TDMI Coprocessor Interface
// Implements CP15 system control coprocessor and generic coprocessor interface

`timescale 1ns/1ps

module arm7tdmi_coprocessor
    import arm7tdmi_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    
    // Coprocessor interface from decode stage
    input  logic        cp_en,          // Coprocessor enable
    input  cp_op_t      cp_op,          // Coprocessor operation
    input  logic [3:0]  cp_num,         // Coprocessor number (0-15)
    input  logic [3:0]  cp_crn,         // Coprocessor register N
    input  logic [3:0]  cp_crm,         // Coprocessor register M  
    input  logic [2:0]  cp_op1,         // Opcode 1
    input  logic [2:0]  cp_op2,         // Opcode 2
    input  logic [31:0] cp_data_in,     // Data from ARM register
    
    // Coprocessor response
    output logic        cp_busy,        // Coprocessor busy
    output logic        cp_absent,      // Coprocessor absent
    output logic [31:0] cp_data_out,    // Data to ARM register
    
    // System control interface
    output logic        mmu_enable,     // Enable MMU
    output logic        dcache_enable,  // Enable data cache
    output logic        icache_enable,  // Enable instruction cache
    output logic        write_buffer_en,// Enable write buffer
    output logic [31:0] ttb_base,       // Translation table base
    output logic [1:0]  ttb_ctrl,       // Translation table control
    output logic [31:0] domain_access,  // Domain access control
    output logic        high_vectors,   // High exception vectors
    output logic        rom_protection, // ROM protection
    output logic        system_protect, // System protection
    
    // Cache control
    output logic        dcache_clean,   // Clean data cache
    output logic        dcache_flush,   // Flush data cache
    output logic        icache_flush,   // Flush instruction cache
    output logic        tlb_flush,      // Flush TLB
    
    // System information
    output logic [31:0] cpu_id,         // CPU ID register
    output logic [31:0] cache_type,     // Cache type register
    
    // Debug interface
    input  logic        debug_mode,     // In debug mode
    output logic [31:0] cp15_reg_out    // CP15 register value for debug
);

    //===========================================
    // CP15 System Control Coprocessor Registers
    //===========================================
    
    // CP15 Register Map (CRn, op1, CRm, op2)
    // c0 - ID registers
    // c1 - Control register
    // c2 - Translation table base
    // c3 - Domain access control
    // c5 - Fault status
    // c6 - Fault address
    // c7 - Cache operations
    // c8 - TLB operations
    // c9 - Cache lockdown
    // c13 - Process ID
    // c15 - Test and debug
    
    // Control Register (c1) - individual bits for better compatibility
    logic ctrl_m;       // MMU enable (bit 0)
    logic ctrl_a;       // Alignment check enable (bit 1)
    logic ctrl_c;       // Data cache enable (bit 2)
    logic ctrl_s;       // System protection (bit 8)
    logic ctrl_r;       // ROM protection (bit 9)
    logic ctrl_z;       // Branch prediction enable (bit 11)
    logic ctrl_i;       // Instruction cache enable (bit 12)
    logic ctrl_v;       // High vectors (bit 13)
    
    // Other CP15 registers
    logic [31:0] translation_table_base;
    logic [31:0] domain_access_ctrl;
    logic [31:0] fault_status;
    logic [31:0] fault_address;
    logic [31:0] process_id;
    
    // Cache operation trigger signals  
    logic icache_flush_trigger;
    logic dcache_flush_trigger;
    logic dcache_clean_trigger;
    logic tlb_flush_trigger;
    
    // Delayed cache operation signals (persist for one cycle after MCR)
    logic icache_flush_delayed;
    logic dcache_flush_delayed;
    logic dcache_clean_delayed;
    logic tlb_flush_delayed;
    
    // Fixed ID registers
    assign cpu_id = 32'h41007000;      // ARM7TDMI ID
    assign cache_type = 32'h0f002002;  // 8KB I-cache, 8KB D-cache
    
    //===========================================
    // Coprocessor Absent Logic
    //===========================================
    
    // Only CP15 is present in ARM7TDMI
    assign cp_absent = cp_en && (cp_num != 4'd15);
    
    // CP15 is never busy (single-cycle operations)
    assign cp_busy = 1'b0;
    
    //===========================================
    // CP15 Register Access
    //===========================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_m <= 1'b0;
            ctrl_a <= 1'b0;
            ctrl_c <= 1'b0;
            ctrl_s <= 1'b0;
            ctrl_r <= 1'b0;
            ctrl_z <= 1'b0;
            ctrl_i <= 1'b0;
            ctrl_v <= 1'b0;
            translation_table_base <= 32'h0;
            domain_access_ctrl <= 32'h0;
            fault_status <= 32'h0;
            fault_address <= 32'h0;
            process_id <= 32'h0;
            
            // Cache operation triggers
            icache_flush_trigger <= 1'b0;
            dcache_flush_trigger <= 1'b0;
            dcache_clean_trigger <= 1'b0;
            tlb_flush_trigger <= 1'b0;
            
            // Delayed cache signals
            icache_flush_delayed <= 1'b0;
            dcache_flush_delayed <= 1'b0;
            dcache_clean_delayed <= 1'b0;
            tlb_flush_delayed <= 1'b0;
        end else begin
            // Clear trigger signals by default
            icache_flush_trigger <= 1'b0;
            dcache_flush_trigger <= 1'b0;
            dcache_clean_trigger <= 1'b0;
            tlb_flush_trigger <= 1'b0;
            
            if (cp_en && !cp_absent && !debug_mode) begin
                case (cp_op)
                    CP_CDP: begin
                        // Coprocessor data operation - not used in CP15
                    end
                    
                    CP_MRC: begin
                        // Move from coprocessor to ARM register
                        // Nothing to do here - handled in read logic below
                    end
                    
                    CP_MCR: begin
                        // Move from ARM register to coprocessor
                        case (cp_crn)
                            4'd1: begin // Control register
                                if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                                    ctrl_m <= cp_data_in[0];    // MMU enable
                                    ctrl_a <= cp_data_in[1];    // Alignment check
                                    ctrl_c <= cp_data_in[2];    // Data cache enable
                                    ctrl_s <= cp_data_in[8];    // System protection
                                    ctrl_r <= cp_data_in[9];    // ROM protection
                                    ctrl_z <= cp_data_in[11];   // Branch prediction
                                    ctrl_i <= cp_data_in[12];   // Instruction cache enable
                                    ctrl_v <= cp_data_in[13];   // High vectors
                                end
                            end
                            
                            4'd2: begin // Translation table base
                                if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                                    translation_table_base <= cp_data_in;
                                end
                            end
                            
                            4'd3: begin // Domain access control
                                if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                                    domain_access_ctrl <= cp_data_in;
                                end
                            end
                            
                            4'd5: begin // Fault status
                                if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                                    fault_status <= cp_data_in;
                                end
                            end
                            
                            4'd6: begin // Fault address
                                if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                                    fault_address <= cp_data_in;
                                end
                            end
                            
                            4'd7: begin // Cache operations
                                case ({cp_crm, cp_op2})
                                    7'b0101000: icache_flush_trigger <= 1'b1;  // Flush I-cache
                                    7'b0110000: dcache_flush_trigger <= 1'b1;  // Flush D-cache
                                    7'b1010001: dcache_clean_trigger <= 1'b1;  // Clean D-cache
                                    7'b1110001: begin                          // Clean and flush D-cache
                                        dcache_clean_trigger <= 1'b1;
                                        dcache_flush_trigger <= 1'b1;
                                    end
                                endcase
                            end
                            
                            4'd8: begin // TLB operations
                                case ({cp_crm, cp_op2})
                                    7'b0111000: tlb_flush_trigger <= 1'b1;      // Flush entire TLB
                                endcase
                            end
                            
                            4'd13: begin // Process ID
                                if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                                    process_id <= cp_data_in;
                                end
                            end
                            
                        endcase
                    end
                    
                    default: begin
                        // LDC, STC not supported by CP15
                    end
                endcase
            end
            
            // Update delayed cache signals  
            icache_flush_delayed <= icache_flush_trigger;
            dcache_flush_delayed <= dcache_flush_trigger;
            dcache_clean_delayed <= dcache_clean_trigger;
            tlb_flush_delayed <= tlb_flush_trigger;
        end
    end
    
    //===========================================
    // CP15 Register Read
    //===========================================
    
    always_comb begin
        cp_data_out = 32'h0;
        
        if (cp_en && !cp_absent && cp_op == CP_MRC) begin
            case (cp_crn)
                4'd0: begin // ID registers
                    case ({cp_op1, cp_crm, cp_op2})
                        9'b000000000: cp_data_out = cpu_id;      // Main ID
                        9'b000000001: cp_data_out = cache_type;  // Cache type
                        default: cp_data_out = 32'h0;
                    endcase
                end
                
                4'd1: begin // Control register
                    if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                        cp_data_out = {18'h0, ctrl_v, ctrl_i, ctrl_z, 1'b0, 
                                      ctrl_r, ctrl_s, 1'b0, 4'h0, ctrl_c, 
                                      ctrl_a, ctrl_m};
                    end
                end
                
                4'd2: begin // Translation table base
                    if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                        cp_data_out = translation_table_base;
                    end
                end
                
                4'd3: begin // Domain access control
                    if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                        cp_data_out = domain_access_ctrl;
                    end
                end
                
                4'd5: begin // Fault status
                    if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                        cp_data_out = fault_status;
                    end
                end
                
                4'd6: begin // Fault address
                    if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                        cp_data_out = fault_address;
                    end
                end
                
                4'd13: begin // Process ID
                    if (cp_crm == 4'd0 && cp_op1 == 3'd0 && cp_op2 == 3'd0) begin
                        cp_data_out = process_id;
                    end
                end
                
                default: cp_data_out = 32'h0;
            endcase
        end
    end
    
    //===========================================
    // System Control Outputs
    //===========================================
    
    assign mmu_enable = ctrl_m;
    assign dcache_enable = ctrl_c;
    assign icache_enable = ctrl_i;
    assign write_buffer_en = ctrl_c;  // Same as D-cache
    assign high_vectors = ctrl_v;
    assign rom_protection = ctrl_r;
    assign system_protect = ctrl_s;
    
    assign ttb_base = translation_table_base;
    assign ttb_ctrl = translation_table_base[1:0];  // N value
    assign domain_access = domain_access_ctrl;
    
    //===========================================
    // Cache Control Signal Generation
    //===========================================
    
    assign dcache_clean = dcache_clean_delayed;
    assign dcache_flush = dcache_flush_delayed;
    assign icache_flush = icache_flush_delayed;
    assign tlb_flush = tlb_flush_delayed;
    
    // Debug output
    assign cp15_reg_out = {18'h0, ctrl_v, ctrl_i, ctrl_z, 1'b0, 
                          ctrl_r, ctrl_s, 1'b0, 4'h0, ctrl_c, 
                          ctrl_a, ctrl_m};

endmodule