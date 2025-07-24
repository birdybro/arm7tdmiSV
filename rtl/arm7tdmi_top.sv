import arm7tdmi_pkg::*;

module arm7tdmi_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // Memory interface
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    output logic        mem_we,
    output logic        mem_re,
    output logic [3:0]  mem_be,
    input  logic        mem_ready,
    
    // Debug interface
    input  logic        debug_en,
    output logic [31:0] debug_pc,
    output logic [31:0] debug_instr,
    
    // Interrupt interface
    input  logic        irq,
    input  logic        fiq,
    
    // Control signals
    input  logic        halt,
    output logic        running
);

    // Pipeline control signals
    logic stall, flush;
    logic fetch_en, branch_taken;
    logic [31:0] branch_target;
    logic thumb_mode;
    
    // Fetch stage signals
    logic [31:0] fetch_instruction, fetch_pc;
    logic fetch_instr_valid;
    
    // Decode stage signals
    condition_t decode_condition;
    instr_type_t decode_instr_type;
    alu_op_t decode_alu_op;
    logic [3:0] decode_rd, decode_rn, decode_rm;
    logic [11:0] decode_immediate;
    logic decode_imm_en, decode_set_flags;
    shift_type_t decode_shift_type;
    logic [4:0] decode_shift_amount;
    logic decode_is_branch, decode_branch_link;
    logic [23:0] decode_branch_offset;
    logic decode_is_memory, decode_mem_load, decode_mem_byte;
    logic decode_mem_pre, decode_mem_up, decode_mem_writeback;
    logic [31:0] decode_pc;
    logic decode_valid;
    
    // PSR transfer signals
    logic decode_psr_to_reg, decode_psr_spsr, decode_psr_immediate;
    
    // Coprocessor signals
    cp_op_t decode_cp_op;
    logic [3:0] decode_cp_num, decode_cp_rd, decode_cp_rn;
    logic [2:0] decode_cp_opcode1, decode_cp_opcode2;
    logic decode_cp_load;
    
    // Register file signals
    logic [31:0] reg_rn_data, reg_rm_data, reg_pc_out, reg_cpsr_out, reg_spsr_out;
    logic [31:0] reg_rd_data, reg_pc_in, reg_cpsr_in, reg_spsr_in;
    logic reg_rd_we, reg_pc_we, reg_cpsr_we, reg_spsr_we;
    processor_mode_t current_mode, target_mode;
    logic mode_change;
    
    // ALU signals
    logic [31:0] alu_operand_a, alu_operand_b, alu_result;
    logic alu_carry_in, alu_carry_out, alu_overflow, alu_negative, alu_zero;
    
    // Multiply unit signals
    logic        mul_en, mul_long, mul_signed, mul_accumulate, mul_set_flags;
    logic [1:0]  mul_type;
    logic [31:0] mul_result_hi, mul_result_lo;
    logic        mul_result_ready, mul_negative, mul_zero;
    
    // Block Data Transfer signals
    logic        block_en, block_load, block_pre, block_up, block_writeback;
    logic        block_user_mode, block_active, block_complete;
    logic [15:0] block_register_list;
    logic [3:0]  block_base_register;
    logic [31:0] block_base_address;
    logic [31:0] block_mem_addr, block_mem_wdata;
    logic        block_mem_we, block_mem_re;
    logic [3:0]  block_reg_addr;
    logic [31:0] block_reg_wdata, block_reg_rdata;
    logic        block_reg_we;
    logic [3:0]  block_base_reg_addr;
    logic [31:0] block_base_reg_data;
    logic        block_base_reg_we;
    
    // Exception handling signals
    logic            exception_taken;
    processor_mode_t exception_mode;
    logic [31:0]     exception_vector;
    logic [31:0]     exception_cpsr;
    logic [31:0]     exception_spsr;
    logic [2:0]      exception_type;
    logic            swi_exception;
    logic            undefined_exception;
    
    // Coprocessor interface signals
    logic            cp_present;       // Coprocessor present
    logic            cp_ready;         // Coprocessor ready
    logic [31:0]     cp_data_out;      // Data from coprocessor
    logic            cp_exception;     // Coprocessor exception
    
    // Pipeline state machine
    cpu_state_t current_state, next_state;
    
    // Current processor mode and CPSR
    assign current_mode = reg_cpsr_out[4:0];
    assign thumb_mode = reg_cpsr_out[CPSR_T_BIT];
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= FETCH;
            running <= 1'b0;
        end else if (halt) begin
            running <= 1'b0;
        end else begin
            current_state <= next_state;
            running <= 1'b1;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        stall = 1'b0;
        flush = 1'b0;
        fetch_en = 1'b0;
        
        case (current_state)
            FETCH: begin
                fetch_en = 1'b1;
                if (fetch_instr_valid) begin
                    next_state = DECODE;
                end
            end
            
            DECODE: begin
                if (decode_valid) begin
                    next_state = EXECUTE;
                end
            end
            
            EXECUTE: begin
                next_state = MEMORY;
            end
            
            MEMORY: begin
                next_state = WRITEBACK;
            end
            
            WRITEBACK: begin
                next_state = FETCH;
            end
        endcase
    end
    
    // Condition evaluation function
    function logic evaluate_condition(input [3:0] cond, input logic n, z, c, v);
        case (cond)
            COND_EQ: return z;                    // Equal
            COND_NE: return ~z;                   // Not equal
            COND_CS: return c;                    // Carry set
            COND_CC: return ~c;                   // Carry clear
            COND_MI: return n;                    // Minus
            COND_PL: return ~n;                   // Plus
            COND_VS: return v;                    // Overflow set
            COND_VC: return ~v;                   // Overflow clear
            COND_HI: return c & ~z;               // Higher
            COND_LS: return ~c | z;               // Lower or same
            COND_GE: return n == v;               // Greater or equal
            COND_LT: return n != v;               // Less than
            COND_GT: return ~z & (n == v);        // Greater than
            COND_LE: return z | (n != v);         // Less or equal
            COND_AL: return 1'b1;                 // Always
            COND_NV: return 1'b0;                 // Never
            default: return 1'b0;
        endcase
    endfunction
    
    // Branch and instruction execution logic
    logic condition_passed;
    assign condition_passed = evaluate_condition(decode_condition, 
                                                reg_cpsr_out[CPSR_N_BIT],
                                                reg_cpsr_out[CPSR_Z_BIT], 
                                                reg_cpsr_out[CPSR_C_BIT],
                                                reg_cpsr_out[CPSR_V_BIT]);
    
    // Branch logic with Link and Exchange support
    logic save_lr;
    logic branch_exchange;
    logic thumb_switch;
    
    assign branch_exchange = (decode_instr_type == INSTR_BRANCH_EX);
    
    always_comb begin
        branch_taken = 1'b0;
        branch_target = 32'b0;
        save_lr = 1'b0;
        thumb_switch = 1'b0;
        
        if (current_state == EXECUTE && condition_passed) begin
            if (decode_is_branch) begin
                // Normal branch (B/BL)
                branch_taken = 1'b1;
                branch_target = decode_pc + {{6{decode_branch_offset[23]}}, decode_branch_offset, 2'b00};
                save_lr = decode_branch_link;  // Save return address for BL
            end else if (branch_exchange) begin
                // Branch and Exchange (BX)
                branch_taken = 1'b1;
                branch_target = {reg_rm_data[31:1], 1'b0};  // Clear LSB for ARM mode
                thumb_switch = reg_rm_data[0];  // LSB determines Thumb/ARM mode
            end
        end
    end
    
    // Shifter signals
    logic [31:0] shifted_operand;
    logic        shifter_carry_out;
    
    // Immediate rotation signals
    logic [3:0] rotate_imm;
    logic [7:0] imm_value;
    logic [4:0] rot_amount;
    
    // ALU operand selection
    always_comb begin
        alu_operand_a = reg_rn_data;
        if (decode_imm_en) begin
            // Immediate value with optional rotation
            rotate_imm = decode_immediate[11:8];
            imm_value = decode_immediate[7:0];
            if (rotate_imm == 4'b0) begin
                alu_operand_b = {24'b0, imm_value};
            end else begin
                rot_amount = {rotate_imm, 1'b0};  // Rotate by 2*rotate_imm
                alu_operand_b = (imm_value >> rot_amount) | (imm_value << (32 - rot_amount));
            end
        end else begin
            alu_operand_b = shifted_operand;  // Use shifted register value
        end
        alu_carry_in = (decode_imm_en || decode_shift_amount == 5'b0) ? 
                      reg_cpsr_out[CPSR_C_BIT] : shifter_carry_out;
    end
    
    // Memory operation logic
    logic [31:0] mem_address;
    logic        mem_operation_active;
    logic [31:0] load_data;
    logic        halfword_operation;
    logic        signed_load;
    logic        swap_operation;
    logic        swap_byte;
    
    assign mem_operation_active = (current_state == MEMORY) && 
                                 (decode_is_memory || 
                                  (decode_instr_type == INSTR_HALFWORD_DT) ||
                                  (decode_instr_type == INSTR_SINGLE_SWAP)) && 
                                 decode_valid && condition_passed;
    assign halfword_operation = (decode_instr_type == INSTR_HALFWORD_DT);
    assign swap_operation = (decode_instr_type == INSTR_SINGLE_SWAP);
    assign swap_byte = swap_operation && decode_mem_byte;
    
    // Calculate memory address (base + offset)
    assign mem_address = reg_rn_data + (decode_imm_en ? {20'b0, decode_immediate} : reg_rm_data);
    
    // Load data processing for different sizes
    always_comb begin
        if (swap_operation) begin
            // SWP/SWPB - return the read data
            if (swap_byte) begin
                // SWPB - byte swap, zero extend
                if (mem_address[0]) begin
                    load_data = {24'b0, swap_read_data[15:8]};
                end else begin
                    load_data = {24'b0, swap_read_data[7:0]};
                end
            end else begin
                // SWP - word swap
                load_data = swap_read_data;
            end
        end else if (halfword_operation) begin
            if (decode_mem_byte) begin
                // LDRSB - Sign extend byte
                if (mem_address[0]) begin
                    load_data = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                end else begin
                    load_data = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                end
            end else begin
                // LDRH/LDRSH - Halfword operations
                if (mem_address[1]) begin
                    load_data = decode_mem_load ? 
                              {{16{mem_rdata[31]}}, mem_rdata[31:16]} :  // LDRSH 
                              {16'b0, mem_rdata[31:16]};                 // LDRH
                end else begin
                    load_data = decode_mem_load ? 
                              {{16{mem_rdata[15]}}, mem_rdata[15:0]} :   // LDRSH
                              {16'b0, mem_rdata[15:0]};                  // LDRH
                end
            end
        end else begin
            // Normal word/byte load
            load_data = mem_rdata;
        end
    end
    
    // Multiply control logic
    assign mul_en = (current_state == EXECUTE) && 
                   ((decode_instr_type == INSTR_MUL) || (decode_instr_type == INSTR_MUL_LONG)) &&
                   decode_valid && condition_passed;
    assign mul_long = (decode_instr_type == INSTR_MUL_LONG);
    assign mul_set_flags = decode_set_flags;  // Use decode flags
    
    // Decode multiply variants based on instruction bits
    always_comb begin
        mul_signed = 1'b0;
        mul_accumulate = 1'b0;
        mul_type = 2'b00;
        
        if (decode_instr_type == INSTR_MUL) begin
            // Single precision multiply
            if (fetch_instruction[21]) begin
                // MLA: Multiply-Accumulate
                mul_type = 2'b01;  // MLA
                mul_accumulate = 1'b1;
            end else begin
                // MUL: Basic multiply
                mul_type = 2'b00;  // MUL
            end
        end else if (decode_instr_type == INSTR_MUL_LONG) begin
            // Long multiply variants
            if (fetch_instruction[22]) begin
                // Signed multiply
                mul_signed = 1'b1;
            end
            
            if (fetch_instruction[21]) begin
                // Accumulate variants
                mul_type = 2'b11;  // UMLAL/SMLAL
                mul_accumulate = 1'b1;
            end else begin
                // Basic long multiply
                mul_type = 2'b10;  // UMULL/SMULL
            end
        end
    end
    
    // Block Data Transfer control logic
    assign block_en = (current_state == EXECUTE) && 
                     (decode_instr_type == INSTR_BLOCK_DT) &&
                     decode_valid && condition_passed;
    assign block_load = decode_mem_load;
    assign block_pre = decode_mem_pre;
    assign block_up = decode_mem_up;
    assign block_writeback = decode_mem_writeback;
    assign block_user_mode = 1'b0;  // TODO: Implement user mode access
    assign block_register_list = fetch_instruction[15:0];
    assign block_base_register = decode_rn;
    assign block_base_address = reg_rn_data;
    
    // Connect block transfer register data
    assign block_reg_rdata = reg_rm_data;  // For store operations
    
    // Coprocessor control logic
    always_comb begin
        cp_present = 1'b0;
        cp_ready = 1'b0;
        cp_data_out = 32'b0;
        cp_exception = 1'b0;
        
        if (decode_instr_type == INSTR_COPROCESSOR) begin
            // Check for supported coprocessors
            case (decode_cp_num)
                4'd15: begin
                    // CP15 (System Control Coprocessor) - basic simulation
                    cp_present = 1'b1;
                    cp_ready = 1'b1;
                    
                    if (decode_cp_op == CP_MRC) begin
                        // Move from CP15 to ARM register
                        case ({decode_cp_rn, decode_cp_opcode2})
                            7'b0000000: cp_data_out = 32'h41007700; // ID register (ARM7TDMI)
                            7'b0001000: cp_data_out = 32'h00000000; // Control register
                            default: begin
                                cp_data_out = 32'h00000000;
                                cp_exception = 1'b1; // Undefined register
                            end
                        endcase
                    end else if (decode_cp_op == CP_MCR) begin
                        // Move from ARM register to CP15 - ignore for now
                        cp_ready = 1'b1;
                    end else begin
                        // Other CP15 operations not supported
                        cp_exception = 1'b1;
                    end
                end
                default: begin
                    // Coprocessor not present
                    cp_present = 1'b0;
                    cp_exception = 1'b1;
                end
            endcase
        end
    end
    
    // Exception detection
    assign swi_exception = (current_state == EXECUTE) && 
                          (decode_instr_type == INSTR_SWI) &&
                          decode_valid && condition_passed;
    assign undefined_exception = (current_state == EXECUTE) && 
                                ((decode_instr_type == INSTR_UNDEFINED) ||
                                 (decode_instr_type == INSTR_COPROCESSOR && cp_exception)) &&
                                decode_valid;
    
    // Register file write logic with LR support and long multiply
    logic        write_lr;
    logic [31:0] lr_data;
    logic        mul_hi_write_pending;
    
    assign write_lr = save_lr && branch_taken;
    assign lr_data = decode_pc + 32'd4;  // Return address (PC + 4)
    
    // Track pending high register write for long multiply
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_hi_write_pending <= 1'b0;
        end else begin
            if ((current_state == WRITEBACK) && (decode_instr_type == INSTR_MUL_LONG) &&
                decode_valid && condition_passed) begin
                mul_hi_write_pending <= 1'b1;
            end else if (mul_hi_write_pending) begin
                mul_hi_write_pending <= 1'b0;  // Clear after one cycle
            end
        end
    end
    
    always_comb begin
        // Select data source based on instruction type
        if (write_lr) begin
            reg_rd_data = lr_data;    // Link register save
        end else if (block_reg_we) begin
            reg_rd_data = block_reg_wdata;  // Block transfer load
        end else if (block_base_reg_we) begin
            reg_rd_data = block_base_reg_data;  // Block transfer base writeback
        end else if (decode_instr_type == INSTR_SINGLE_DT && decode_mem_load) begin
            reg_rd_data = load_data;  // Load instruction
        end else if (decode_instr_type == INSTR_MUL) begin
            reg_rd_data = mul_result_lo;  // Single multiply result
        end else if (decode_instr_type == INSTR_MUL_LONG) begin
            if (mul_hi_write_pending) begin
                reg_rd_data = mul_result_hi;  // Long multiply high result (RdHi)
            end else begin
                reg_rd_data = mul_result_lo;  // Long multiply low result (RdLo)
            end
        end else if (decode_instr_type == INSTR_PSR_TRANSFER && decode_psr_to_reg) begin
            // MRS: Move PSR to register
            reg_rd_data = decode_psr_spsr ? reg_spsr_out : reg_cpsr_out;
        end else if (decode_instr_type == INSTR_COPROCESSOR && decode_cp_op == CP_MRC) begin
            // MRC: Move from coprocessor to ARM register
            reg_rd_data = cp_data_out;
        end else begin
            reg_rd_data = alu_result; // Data processing instruction
        end
        
        // Register write enable logic
        if (write_lr) begin
            // Write to LR (R14) for BL instructions
            reg_rd_we = 1'b1;
        end else if (block_reg_we || block_base_reg_we) begin
            // Block transfer register writes
            reg_rd_we = 1'b1;
        end else if (mul_hi_write_pending) begin
            // Write high result of long multiply
            reg_rd_we = 1'b1;
        end else begin
            // Normal instruction register write
            reg_rd_we = (current_state == WRITEBACK) && 
                       ((decode_instr_type == INSTR_DATA_PROC) || 
                        (decode_instr_type == INSTR_SINGLE_DT && decode_mem_load) ||
                        (decode_instr_type == INSTR_HALFWORD_DT && decode_mem_load) ||
                        (decode_instr_type == INSTR_SINGLE_SWAP) ||
                        (decode_instr_type == INSTR_MUL) ||
                        (decode_instr_type == INSTR_MUL_LONG) ||
                        (decode_instr_type == INSTR_PSR_TRANSFER && decode_psr_to_reg) ||
                        (decode_instr_type == INSTR_COPROCESSOR && decode_cp_op == CP_MRC)) &&
                       decode_valid && 
                       condition_passed &&
                       (decode_rd != 4'd15);  // Don't write to PC through normal path
        end
    end
    
    // Register address multiplexer for LR writes and block transfers
    logic [3:0] actual_rd_addr;
    logic [3:0] actual_rn_addr, actual_rm_addr;
    
    assign actual_rd_addr = write_lr ? 4'd14 : 
                           (block_reg_we || block_base_reg_we) ? 
                           (block_base_reg_we ? block_base_reg_addr : block_reg_addr) : 
                           (mul_hi_write_pending) ? decode_rn : decode_rd;  // RdHi address for long multiply
    
    assign actual_rn_addr = block_active ? block_reg_addr : decode_rn;
    assign actual_rm_addr = block_active ? block_reg_addr : decode_rm;
    
    // PC and CPSR write logic
    always_comb begin
        // PC write priority: exception > branch > normal fetch
        if (exception_taken) begin
            reg_pc_in = exception_vector;
            reg_pc_we = 1'b1;
        end else if (branch_taken) begin
            reg_pc_in = branch_target;
            reg_pc_we = 1'b1;
        end else begin
            reg_pc_in = fetch_pc;
            reg_pc_we = 1'b1;  // Always update PC from fetch
        end
        
        // CPSR update priority: exception > thumb switch > flag updates
        if (exception_taken) begin
            reg_cpsr_in = exception_cpsr;
            reg_cpsr_we = 1'b1;
        end else if (branch_exchange && branch_taken) begin
            // BX instruction - update Thumb bit
            reg_cpsr_in = reg_cpsr_out;
            reg_cpsr_in[CPSR_T_BIT] = thumb_switch;
            reg_cpsr_we = 1'b1;
        end else if ((decode_instr_type == INSTR_PSR_TRANSFER) && !decode_psr_to_reg && 
                    !decode_psr_spsr && (current_state == WRITEBACK) && 
                    decode_valid && condition_passed) begin
            // MSR: Move register/immediate to CPSR
            if (decode_psr_immediate) begin
                // MSR with immediate value
                reg_cpsr_in = {20'b0, decode_immediate[11:8], decode_immediate[7:0]};
            end else begin
                // MSR with register value
                reg_cpsr_in = reg_rm_data;
            end
            reg_cpsr_we = 1'b1;
        end else if (decode_set_flags && (current_state == WRITEBACK) && 
                    decode_valid && condition_passed) begin
            reg_cpsr_in = reg_cpsr_out;
            
            // Select flag source based on instruction type
            if ((decode_instr_type == INSTR_MUL) || (decode_instr_type == INSTR_MUL_LONG)) begin
                // Multiply instruction flags
                reg_cpsr_in[CPSR_N_BIT] = mul_negative;
                reg_cpsr_in[CPSR_Z_BIT] = mul_zero;
                // Multiply doesn't affect C and V flags
            end else begin
                // ALU instruction flags
                reg_cpsr_in[CPSR_N_BIT] = alu_negative;
                reg_cpsr_in[CPSR_Z_BIT] = alu_zero;
                reg_cpsr_in[CPSR_C_BIT] = alu_carry_out;
                reg_cpsr_in[CPSR_V_BIT] = alu_overflow;
            end
            reg_cpsr_we = 1'b1;
        end else begin
            reg_cpsr_in = reg_cpsr_out;
            reg_cpsr_we = 1'b0;
        end
        
        // SPSR write for exceptions and MSR instructions
        if (exception_taken) begin
            reg_spsr_in = exception_spsr;
            reg_spsr_we = 1'b1;
            target_mode = exception_mode;
            mode_change = 1'b1;
        end else if ((decode_instr_type == INSTR_PSR_TRANSFER) && !decode_psr_to_reg && 
                    decode_psr_spsr && (current_state == WRITEBACK) && 
                    decode_valid && condition_passed) begin
            // MSR: Move register/immediate to SPSR
            if (decode_psr_immediate) begin
                // MSR with immediate value
                reg_spsr_in = {20'b0, decode_immediate[11:8], decode_immediate[7:0]};
            end else begin
                // MSR with register value
                reg_spsr_in = reg_rm_data;
            end
            reg_spsr_we = 1'b1;
            target_mode = current_mode;
            mode_change = 1'b0;
        end else begin
            reg_spsr_in = 32'b0;
            reg_spsr_we = 1'b0;
            target_mode = current_mode;
            mode_change = 1'b0;
        end
    end
    
    // Memory interface logic
    logic [31:0] data_mem_addr;
    logic        data_mem_we, data_mem_re;
    logic [31:0] data_mem_wdata;
    logic [3:0]  data_mem_be;
    
    // Swap operation state
    typedef enum logic [1:0] {
        SWAP_IDLE,
        SWAP_READ,
        SWAP_WRITE
    } swap_state_t;
    
    swap_state_t swap_state, swap_next_state;
    logic [31:0] swap_read_data;
    
    // Swap state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            swap_state <= SWAP_IDLE;
            swap_read_data <= 32'b0;
        end else begin
            swap_state <= swap_next_state;
            if (swap_state == SWAP_READ && mem_ready) begin
                swap_read_data <= mem_rdata;
            end
        end
    end
    
    always_comb begin
        swap_next_state = swap_state;
        case (swap_state)
            SWAP_IDLE: begin
                if (swap_operation && mem_operation_active) begin
                    swap_next_state = SWAP_READ;
                end
            end
            SWAP_READ: begin
                if (mem_ready) begin
                    swap_next_state = SWAP_WRITE;
                end
            end
            SWAP_WRITE: begin
                if (mem_ready) begin
                    swap_next_state = SWAP_IDLE;
                end
            end
        endcase
    end
    
    // Data memory operations
    assign data_mem_addr = mem_address;
    
    // Memory control for swap vs normal operations
    always_comb begin
        if (swap_operation) begin
            case (swap_state)
                SWAP_READ: begin
                    data_mem_we = 1'b0;
                    data_mem_re = 1'b1;
                    data_mem_wdata = 32'b0;
                end
                SWAP_WRITE: begin
                    data_mem_we = 1'b1;
                    data_mem_re = 1'b0;
                    data_mem_wdata = reg_rm_data;
                end
                default: begin
                    data_mem_we = 1'b0;
                    data_mem_re = 1'b0;
                    data_mem_wdata = 32'b0;
                end
            endcase
        end else begin
            // Normal memory operations
            data_mem_we = mem_operation_active && !decode_mem_load;  // Store
            data_mem_re = mem_operation_active && decode_mem_load;   // Load
            data_mem_wdata = reg_rm_data;  // Store data from Rm
        end
    end
    
    // Byte enable logic for different transfer sizes
    always_comb begin
        if (swap_operation) begin
            // SWP/SWPB operations
            data_mem_be = swap_byte ? 
                         (1'b1 << mem_address[1:0]) :  // SWPB - byte access
                         4'b1111;                      // SWP - word access
        end else if (halfword_operation) begin
            if (decode_mem_byte) begin
                // Byte access (LDRSB/STRB)
                data_mem_be = 1'b1 << mem_address[1:0];
            end else begin
                // Halfword access (LDRH/LDRSH/STRH) 
                data_mem_be = mem_address[1] ? 4'b1100 : 4'b0011;
            end
        end else begin
            // Normal word/byte access
            data_mem_be = decode_mem_byte ? 
                         (1'b1 << mem_address[1:0]) :  // Byte access
                         4'b1111;                      // Word access
        end
    end
    
    // Memory interface multiplexer (priority: fetch > block > single data)
    assign mem_we = (current_state == FETCH) ? 1'b0 : 
                   block_active ? block_mem_we : data_mem_we;
    assign mem_wdata = block_active ? block_mem_wdata : data_mem_wdata;
    assign mem_be = (current_state == FETCH) ? 4'b1111 : 
                   block_active ? 4'b1111 : data_mem_be;
    
    // Debug interface
    assign debug_pc = reg_pc_out;
    assign debug_instr = fetch_instruction;
    
    // Memory address multiplexer  
    logic [31:0] fetch_mem_addr;
    logic        fetch_mem_re;
    
    // Instantiate fetch stage
    arm7tdmi_fetch u_fetch (
        .clk            (clk),
        .rst_n          (rst_n),
        .fetch_en       (fetch_en),
        .branch_taken   (branch_taken),
        .branch_target  (branch_target),
        .thumb_mode     (thumb_mode),
        .mem_addr       (fetch_mem_addr),
        .mem_re         (fetch_mem_re),
        .mem_rdata      (mem_rdata),
        .mem_ready      (mem_ready),
        .instruction    (fetch_instruction),
        .pc_out         (fetch_pc),
        .instr_valid    (fetch_instr_valid),
        .stall          (stall),
        .flush          (flush)
    );
    
    // Memory interface multiplexer (priority: fetch > block > single data)
    assign mem_addr = (current_state == FETCH) ? fetch_mem_addr : 
                     block_active ? block_mem_addr : data_mem_addr;
    assign mem_re = (current_state == FETCH) ? fetch_mem_re : 
                   block_active ? block_mem_re : data_mem_re;
    
    // Instantiate decode stage
    arm7tdmi_decode u_decode (
        .clk            (clk),
        .rst_n          (rst_n),
        .instruction    (fetch_instruction),
        .pc_in          (fetch_pc),
        .instr_valid    (fetch_instr_valid),
        .thumb_mode     (thumb_mode),
        .condition      (decode_condition),
        .instr_type     (decode_instr_type),
        .alu_op         (decode_alu_op),
        .rd             (decode_rd),
        .rn             (decode_rn),
        .rm             (decode_rm),
        .immediate      (decode_immediate),
        .imm_en         (decode_imm_en),
        .set_flags      (decode_set_flags),
        .shift_type     (decode_shift_type),
        .shift_amount   (decode_shift_amount),
        .is_branch      (decode_is_branch),
        .branch_offset  (decode_branch_offset),
        .branch_link    (decode_branch_link),
        .is_memory      (decode_is_memory),
        .mem_load       (decode_mem_load),
        .mem_byte       (decode_mem_byte),
        .mem_pre        (decode_mem_pre),
        .mem_up         (decode_mem_up),
        .mem_writeback  (decode_mem_writeback),
        .psr_to_reg     (decode_psr_to_reg),
        .psr_spsr       (decode_psr_spsr),
        .psr_immediate  (decode_psr_immediate),
        .cp_op          (decode_cp_op),
        .cp_num         (decode_cp_num),
        .cp_rd          (decode_cp_rd),
        .cp_rn          (decode_cp_rn),
        .cp_opcode1     (decode_cp_opcode1),
        .cp_opcode2     (decode_cp_opcode2),
        .cp_load        (decode_cp_load),
        .pc_out         (decode_pc),
        .decode_valid   (decode_valid),
        .stall          (stall),
        .flush          (flush)
    );
    
    // Instantiate register file
    arm7tdmi_regfile u_regfile (
        .clk            (clk),
        .rst_n          (rst_n),
        .rn_addr        (actual_rn_addr),  // Use multiplexed addresses
        .rm_addr        (actual_rm_addr),
        .rn_data        (reg_rn_data),
        .rm_data        (reg_rm_data),
        .rd_addr        (actual_rd_addr),
        .rd_data        (reg_rd_data),
        .rd_we          (reg_rd_we),
        .pc_out         (reg_pc_out),
        .pc_in          (reg_pc_in),
        .pc_we          (reg_pc_we),
        .current_mode   (current_mode),
        .target_mode    (target_mode),
        .mode_change    (mode_change),
        .cpsr_out       (reg_cpsr_out),
        .cpsr_in        (reg_cpsr_in),
        .cpsr_we        (reg_cpsr_we),
        .spsr_out       (reg_spsr_out),
        .spsr_in        (reg_spsr_in),
        .spsr_we        (reg_spsr_we)
    );
    
    // Instantiate ALU
    arm7tdmi_alu u_alu (
        .clk            (clk),
        .rst_n          (rst_n),
        .alu_op         (decode_alu_op),
        .set_flags      (decode_set_flags),
        .operand_a      (alu_operand_a),
        .operand_b      (alu_operand_b),
        .carry_in       (alu_carry_in),
        .result         (alu_result),
        .carry_out      (alu_carry_out),
        .overflow       (alu_overflow),
        .negative       (alu_negative),
        .zero           (alu_zero)
    );
    
    // Long multiply register access for accumulate operations
    // For UMLAL/SMLAL, we need current values of RdHi and RdLo for accumulation
    // This is a simplified implementation - in a real processor, we'd need extra read ports
    // or a multi-cycle approach
    logic [31:0] mul_acc_hi, mul_acc_lo;
    
    // For MLA: use Rn as accumulator (bits [15:12])
    // For UMLAL/SMLAL: use current RdHi and RdLo values
    // This is simplified - assumes accumulator values are available somehow
    always_comb begin
        if (decode_instr_type == INSTR_MUL && mul_accumulate) begin
            // MLA: accumulate with Rn register
            mul_acc_hi = 32'b0;
            mul_acc_lo = reg_rn_data;  // Rn for MLA
        end else if (decode_instr_type == INSTR_MUL_LONG && mul_accumulate) begin
            // UMLAL/SMLAL: accumulate with current RdHi:RdLo
            // This is a simplification - in practice we'd need to read these values
            // For now, assume they are zero (first implementation)
            mul_acc_hi = 32'b0;  // TODO: Read current RdHi value
            mul_acc_lo = 32'b0;  // TODO: Read current RdLo value
        end else begin
            mul_acc_hi = 32'b0;
            mul_acc_lo = 32'b0;
        end
    end
    
    // Instantiate Multiply Unit
    arm7tdmi_multiply u_multiply (
        .clk            (clk),
        .rst_n          (rst_n),
        .mul_en         (mul_en),
        .mul_long       (mul_long),
        .mul_signed     (mul_signed),
        .mul_accumulate (mul_accumulate),
        .mul_set_flags  (mul_set_flags),
        .mul_type       (mul_type),
        .operand_a      (reg_rn_data),
        .operand_b      (reg_rm_data),
        .acc_hi         (mul_acc_hi),
        .acc_lo         (mul_acc_lo),
        .result_hi      (mul_result_hi),
        .result_lo      (mul_result_lo),
        .result_ready   (mul_result_ready),
        .negative       (mul_negative),
        .zero           (mul_zero)
    );
    
    // Instantiate Shifter
    arm7tdmi_shifter u_shifter (
        .data_in        (reg_rm_data),
        .shift_type     (decode_shift_type),
        .shift_amount   (decode_shift_amount),
        .carry_in       (reg_cpsr_out[CPSR_C_BIT]),
        .data_out       (shifted_operand),
        .carry_out      (shifter_carry_out)
    );
    
    // Instantiate Block Data Transfer Unit
    arm7tdmi_block_dt u_block_dt (
        .clk                (clk),
        .rst_n              (rst_n),
        .block_en           (block_en),
        .block_load         (block_load),
        .block_pre          (block_pre),
        .block_up           (block_up),
        .block_writeback    (block_writeback),
        .block_user_mode    (block_user_mode),
        .register_list      (block_register_list),
        .base_register      (block_base_register),
        .base_address       (block_base_address),
        .mem_addr           (block_mem_addr),
        .mem_wdata          (block_mem_wdata),
        .mem_rdata          (mem_rdata),
        .mem_we             (block_mem_we),
        .mem_re             (block_mem_re),
        .mem_ready          (mem_ready),
        .reg_addr           (block_reg_addr),
        .reg_wdata          (block_reg_wdata),
        .reg_rdata          (block_reg_rdata),
        .reg_we             (block_reg_we),
        .base_reg_addr      (block_base_reg_addr),
        .base_reg_data      (block_base_reg_data),
        .base_reg_we        (block_base_reg_we),
        .block_complete     (block_complete),
        .block_active       (block_active)
    );
    
    // Instantiate Exception Handler
    arm7tdmi_exception u_exception (
        .clk                (clk),
        .rst_n              (rst_n),
        .irq                (irq),
        .fiq                (fiq),
        .swi                (swi_exception),
        .undefined_instr    (undefined_exception),
        .prefetch_abort     (1'b0),  // TODO: Implement abort detection
        .data_abort         (1'b0),  // TODO: Implement abort detection
        .current_mode       (current_mode),
        .current_cpsr       (reg_cpsr_out),
        .current_pc         (reg_pc_out),
        .exception_taken    (exception_taken),
        .exception_mode     (exception_mode),
        .exception_vector   (exception_vector),
        .exception_cpsr     (exception_cpsr),
        .exception_spsr     (exception_spsr),
        .exception_type     (exception_type)
    );
    
endmodule