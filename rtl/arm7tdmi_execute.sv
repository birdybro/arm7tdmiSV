// ARM7TDMI Execute Unit
// Integrates ALU, shifter, register file, and condition evaluation

module arm7tdmi_execute (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from decode stage
    input  logic [3:0]  condition,
    input  logic [3:0]  instr_type,
    input  logic [3:0]  alu_op,
    input  logic [3:0]  rd,
    input  logic [3:0]  rn,
    input  logic [3:0]  rm,
    input  logic [11:0] immediate,
    input  logic        imm_en,
    input  logic        set_flags,
    input  logic [1:0]  shift_type,
    input  logic [4:0]  shift_amount,
    input  logic        shift_reg,
    input  logic [3:0]  shift_rs,
    input  logic [31:0] pc_in,
    input  logic        decode_valid,
    input  logic        thumb_mode,
    
    // Branch instruction inputs
    input  logic        is_branch,
    input  logic [23:0] branch_offset,
    input  logic        branch_link,
    
    // Memory instruction inputs
    input  logic        is_memory,
    input  logic        mem_load,
    input  logic        mem_byte,
    input  logic        mem_pre,
    input  logic        mem_up,
    input  logic        mem_writeback,
    
    // PSR transfer inputs
    input  logic        psr_to_reg,
    input  logic        psr_spsr,
    input  logic        psr_immediate,
    
    // Outputs to memory/writeback stage
    output logic [31:0] result,
    output logic [31:0] memory_address,
    output logic [31:0] store_data,
    output logic        mem_req,
    output logic        mem_write,
    output logic [1:0]  mem_size,
    output logic [31:0] pc_out,
    output logic        execute_valid,
    
    // Branch control outputs
    output logic        branch_taken,
    output logic [31:0] branch_target,
    
    // Register file control
    output logic [31:0] reg_write_data,
    output logic [3:0]  reg_write_addr,
    output logic        reg_write_enable,
    
    // CPSR updates
    output logic [31:0] cpsr_out,
    output logic        cpsr_update,
    
    // Pipeline control
    input  logic        stall,
    input  logic        flush
);

    // Instruction type constants (matching arm7tdmi_defines.sv)
    localparam [3:0] INSTR_DATA_PROC   = 4'b0000;
    localparam [3:0] INSTR_MUL         = 4'b0001;
    localparam [3:0] INSTR_MUL_LONG    = 4'b0010;
    localparam [3:0] INSTR_SINGLE_SWAP = 4'b0011;
    localparam [3:0] INSTR_BRANCH_EX   = 4'b0100;
    localparam [3:0] INSTR_HALFWORD_DT = 4'b0101;
    localparam [3:0] INSTR_SINGLE_DT   = 4'b0110;
    localparam [3:0] INSTR_UNDEFINED   = 4'b0111;
    localparam [3:0] INSTR_BLOCK_DT    = 4'b1000;
    localparam [3:0] INSTR_BRANCH      = 4'b1001;
    localparam [3:0] INSTR_COPROCESSOR = 4'b1010;
    localparam [3:0] INSTR_SWI         = 4'b1011;
    localparam [3:0] INSTR_PSR_TRANSFER = 4'b1100;

    // ALU operations constants
    localparam [3:0] ALU_AND = 4'b0000;
    localparam [3:0] ALU_EOR = 4'b0001;
    localparam [3:0] ALU_SUB = 4'b0010;
    localparam [3:0] ALU_RSB = 4'b0011;
    localparam [3:0] ALU_ADD = 4'b0100;
    localparam [3:0] ALU_ADC = 4'b0101;
    localparam [3:0] ALU_SBC = 4'b0110;
    localparam [3:0] ALU_RSC = 4'b0111;
    localparam [3:0] ALU_TST = 4'b1000;
    localparam [3:0] ALU_TEQ = 4'b1001;
    localparam [3:0] ALU_CMP = 4'b1010;
    localparam [3:0] ALU_CMN = 4'b1011;
    localparam [3:0] ALU_ORR = 4'b1100;
    localparam [3:0] ALU_MOV = 4'b1101;
    localparam [3:0] ALU_BIC = 4'b1110;
    localparam [3:0] ALU_MVN = 4'b1111;

    // Condition codes constants  
    localparam [3:0] COND_EQ = 4'b0000;  // Equal
    localparam [3:0] COND_NE = 4'b0001;  // Not equal
    localparam [3:0] COND_CS = 4'b0010;  // Carry set
    localparam [3:0] COND_CC = 4'b0011;  // Carry clear
    localparam [3:0] COND_MI = 4'b0100;  // Minus
    localparam [3:0] COND_PL = 4'b0101;  // Plus
    localparam [3:0] COND_VS = 4'b0110;  // Overflow set
    localparam [3:0] COND_VC = 4'b0111;  // Overflow clear
    localparam [3:0] COND_HI = 4'b1000;  // Higher
    localparam [3:0] COND_LS = 4'b1001;  // Lower or same
    localparam [3:0] COND_GE = 4'b1010;  // Greater or equal
    localparam [3:0] COND_LT = 4'b1011;  // Less than
    localparam [3:0] COND_GT = 4'b1100;  // Greater than
    localparam [3:0] COND_LE = 4'b1101;  // Less or equal
    localparam [3:0] COND_AL = 4'b1110;  // Always
    localparam [3:0] COND_NV = 4'b1111;  // Never
    
    // Shift types constants
    localparam [1:0] SHIFT_LSL = 2'b00;  // Logical shift left
    localparam [1:0] SHIFT_LSR = 2'b01;  // Logical shift right
    localparam [1:0] SHIFT_ASR = 2'b10;  // Arithmetic shift right
    localparam [1:0] SHIFT_ROR = 2'b11;  // Rotate right

    // Processor modes constants
    localparam [4:0] MODE_USER       = 5'b10000;
    localparam [4:0] MODE_FIQ        = 5'b10001;
    localparam [4:0] MODE_IRQ        = 5'b10010;
    localparam [4:0] MODE_SUPERVISOR = 5'b10011;
    localparam [4:0] MODE_ABORT      = 5'b10111;
    localparam [4:0] MODE_UNDEFINED  = 5'b11011;
    localparam [4:0] MODE_SYSTEM     = 5'b11111;

    // CPSR bit positions
    localparam CPSR_N_BIT = 31;  // Negative flag
    localparam CPSR_Z_BIT = 30;  // Zero flag
    localparam CPSR_C_BIT = 29;  // Carry flag
    localparam CPSR_V_BIT = 28;  // Overflow flag
    localparam CPSR_I_BIT = 7;   // IRQ disable
    localparam CPSR_F_BIT = 6;   // FIQ disable
    localparam CPSR_T_BIT = 5;   // Thumb state

    // Pipeline registers
    logic [31:0] pc_reg;
    logic        valid_reg;
    
    // Register file interface
    logic [3:0]  rf_rn_addr, rf_rm_addr, rf_rd_addr;
    logic [31:0] rf_rn_data, rf_rm_data, rf_rd_data;
    logic        rf_rd_we;
    logic [31:0] rf_pc_out, rf_pc_in;
    logic        rf_pc_we;
    logic [4:0]  rf_current_mode, rf_target_mode;
    logic        rf_mode_change;
    logic [31:0] rf_cpsr_out, rf_cpsr_in;
    logic        rf_cpsr_we;
    logic [31:0] rf_spsr_out, rf_spsr_in;
    logic        rf_spsr_we;
    
    // ALU interface
    logic [3:0]  alu_operation;
    logic        alu_set_flags;
    logic [31:0] alu_operand_a, alu_operand_b;
    logic        alu_carry_in;
    logic [31:0] alu_result;
    logic        alu_carry_out, alu_overflow, alu_negative, alu_zero;
    
    // Shifter interface  
    logic [31:0] shifter_data_in;
    logic [1:0]  shifter_type;
    logic [4:0]  shifter_amount;
    logic        shifter_carry_in;
    logic [31:0] shifter_data_out;
    logic        shifter_carry_out;
    
    // Internal signals
    logic [31:0] operand_a, operand_b;
    logic [31:0] immediate_extended;
    logic        condition_satisfied;
    logic [31:0] branch_target_calc;
    logic        should_branch;
    logic [31:0] memory_addr_calc;
    logic        execute_instruction;
    
    // Current CPSR flags
    logic        cpsr_n, cpsr_z, cpsr_c, cpsr_v;
    
    // Extract current CPSR flags
    assign cpsr_n = rf_cpsr_out[CPSR_N_BIT];
    assign cpsr_z = rf_cpsr_out[CPSR_Z_BIT];
    assign cpsr_c = rf_cpsr_out[CPSR_C_BIT];
    assign cpsr_v = rf_cpsr_out[CPSR_V_BIT];
    
    // Pipeline registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'b0;
            valid_reg <= 1'b0;
        end else if (flush) begin
            pc_reg <= 32'b0;
            valid_reg <= 1'b0;
        end else if (!stall) begin
            pc_reg <= pc_in;
            valid_reg <= decode_valid;
        end
    end
    
    // Condition evaluation
    always_comb begin
        case (condition)
            COND_EQ: condition_satisfied = cpsr_z;
            COND_NE: condition_satisfied = ~cpsr_z;
            COND_CS: condition_satisfied = cpsr_c;
            COND_CC: condition_satisfied = ~cpsr_c;
            COND_MI: condition_satisfied = cpsr_n;
            COND_PL: condition_satisfied = ~cpsr_n;
            COND_VS: condition_satisfied = cpsr_v;
            COND_VC: condition_satisfied = ~cpsr_v;
            COND_HI: condition_satisfied = cpsr_c & ~cpsr_z;
            COND_LS: condition_satisfied = ~cpsr_c | cpsr_z;
            COND_GE: condition_satisfied = cpsr_n == cpsr_v;
            COND_LT: condition_satisfied = cpsr_n != cpsr_v;
            COND_GT: condition_satisfied = ~cpsr_z & (cpsr_n == cpsr_v);
            COND_LE: condition_satisfied = cpsr_z | (cpsr_n != cpsr_v);
            COND_AL: condition_satisfied = 1'b1;
            COND_NV: condition_satisfied = 1'b0;
            default: condition_satisfied = 1'b0;
        endcase
    end
    
    assign execute_instruction = valid_reg && condition_satisfied;
    
    // Immediate value extension (with rotation for ARM)
    always_comb begin
        if (imm_en) begin
            // For ARM immediate values, apply rotation
            logic [3:0] rotate_amount = immediate[11:8];
            logic [7:0] imm_value = immediate[7:0];
            immediate_extended = {24'b0, imm_value} >> (rotate_amount * 2) | 
                               {24'b0, imm_value} << (32 - rotate_amount * 2);
        end else begin
            immediate_extended = 32'b0;
        end
    end
    
    // Register file connections
    assign rf_rn_addr = rn;
    assign rf_rm_addr = rm;
    assign rf_rd_addr = rd;
    assign rf_rd_data = reg_write_data;
    assign rf_rd_we = reg_write_enable;
    assign rf_pc_in = branch_target;
    assign rf_pc_we = branch_taken && execute_instruction;
    assign rf_current_mode = rf_cpsr_out[4:0];
    assign rf_target_mode = rf_cpsr_out[4:0]; // Simplified for now
    assign rf_mode_change = 1'b0; // Simplified for now
    assign rf_cpsr_in = cpsr_out;
    assign rf_cpsr_we = cpsr_update;
    assign rf_spsr_in = 32'b0; // Simplified for now
    assign rf_spsr_we = 1'b0; // Simplified for now
    
    // Operand selection
    always_comb begin
        // Operand A is always Rn for data processing
        operand_a = rf_rn_data;
        
        // Operand B selection
        if (imm_en) begin
            operand_b = immediate_extended;
        end else begin
            operand_b = shifter_data_out;  // Shifted Rm
        end
    end
    
    // Shifter connections
    assign shifter_data_in = rf_rm_data;
    assign shifter_type = shift_type;
    assign shifter_amount = shift_reg ? rf_rn_data[7:0] : shift_amount;
    assign shifter_carry_in = cpsr_c;
    
    // ALU connections
    assign alu_operation = alu_op;
    assign alu_set_flags = set_flags && execute_instruction;
    assign alu_operand_a = operand_a;
    assign alu_operand_b = operand_b;
    assign alu_carry_in = imm_en ? cpsr_c : shifter_carry_out;
    
    // Branch target calculation
    always_comb begin
        if (thumb_mode) begin
            // Thumb branch calculation
            branch_target_calc = pc_reg + 32'd4 + {{6{branch_offset[23]}}, branch_offset[23:0], 2'b00};
        end else begin
            // ARM branch calculation  
            branch_target_calc = pc_reg + 32'd8 + {{6{branch_offset[23]}}, branch_offset[23:0], 2'b00};
        end
    end
    
    // Branch decision
    assign should_branch = is_branch && execute_instruction;
    assign branch_taken = should_branch;
    assign branch_target = branch_target_calc;
    
    // Memory address calculation
    always_comb begin
        if (is_memory) begin
            if (mem_up) begin
                memory_addr_calc = rf_rn_data + (imm_en ? immediate_extended : rf_rm_data);
            end else begin
                memory_addr_calc = rf_rn_data - (imm_en ? immediate_extended : rf_rm_data);
            end
        end else begin
            memory_addr_calc = 32'b0;
        end
    end
    
    // Result selection
    always_comb begin
        case (instr_type)
            INSTR_DATA_PROC: begin
                result = alu_result;
            end
            INSTR_SINGLE_DT, INSTR_HALFWORD_DT: begin
                result = memory_addr_calc;
            end
            INSTR_BRANCH: begin
                result = pc_reg + (thumb_mode ? 32'd2 : 32'd4); // Return address for BL
            end
            INSTR_PSR_TRANSFER: begin
                if (psr_to_reg) begin
                    result = psr_spsr ? rf_spsr_out : rf_cpsr_out;
                end else begin
                    result = 32'b0;
                end
            end
            default: begin
                result = alu_result;
            end
        endcase
    end
    
    // Register write control
    always_comb begin
        // Determine what to write to register
        reg_write_data = result;
        reg_write_addr = rd;
        
        // Determine when to write
        reg_write_enable = 1'b0;
        if (execute_instruction) begin
            case (instr_type)
                INSTR_DATA_PROC: begin
                    // Don't write for compare/test operations
                    reg_write_enable = !(alu_op == ALU_CMP || alu_op == ALU_CMN || 
                                       alu_op == ALU_TST || alu_op == ALU_TEQ);
                end
                INSTR_BRANCH: begin
                    reg_write_enable = branch_link; // Write LR for BL
                end
                INSTR_PSR_TRANSFER: begin
                    reg_write_enable = psr_to_reg; // Write for MRS
                end
                default: begin
                    reg_write_enable = 1'b0;
                end
            endcase
        end
    end
    
    // CPSR update logic
    always_comb begin
        cpsr_out = rf_cpsr_out;
        cpsr_update = 1'b0;
        
        if (execute_instruction && set_flags && instr_type == INSTR_DATA_PROC) begin
            cpsr_out[CPSR_N_BIT] = alu_negative;
            cpsr_out[CPSR_Z_BIT] = alu_zero;
            cpsr_out[CPSR_C_BIT] = alu_carry_out;
            cpsr_out[CPSR_V_BIT] = alu_overflow;
            cpsr_update = 1'b1;
        end
    end
    
    // Memory interface
    assign memory_address = memory_addr_calc;
    assign store_data = rf_rm_data; // For store operations
    assign mem_req = is_memory && execute_instruction;
    assign mem_write = is_memory && !mem_load && execute_instruction;
    assign mem_size = mem_byte ? 2'b00 : 2'b10; // Byte or word
    
    // Output assignments
    assign pc_out = pc_reg;
    assign execute_valid = valid_reg;
    
    // Component instantiations
    arm7tdmi_regfile u_regfile (
        .clk           (clk),
        .rst_n         (rst_n),
        .rn_addr       (rf_rn_addr),
        .rm_addr       (rf_rm_addr),
        .rn_data       (rf_rn_data),
        .rm_data       (rf_rm_data),
        .rd_addr       (rf_rd_addr),
        .rd_data       (rf_rd_data),
        .rd_we         (rf_rd_we),
        .pc_out        (rf_pc_out),
        .pc_in         (rf_pc_in),
        .pc_we         (rf_pc_we),
        .current_mode  (rf_current_mode),
        .target_mode   (rf_target_mode),
        .mode_change   (rf_mode_change),
        .cpsr_out      (rf_cpsr_out),
        .cpsr_in       (rf_cpsr_in),
        .cpsr_we       (rf_cpsr_we),
        .spsr_out      (rf_spsr_out),
        .spsr_in       (rf_spsr_in),
        .spsr_we       (rf_spsr_we)
    );
    
    arm7tdmi_alu u_alu (
        .clk         (clk),
        .rst_n       (rst_n),
        .alu_op      (alu_operation),
        .set_flags   (alu_set_flags),
        .operand_a   (alu_operand_a),
        .operand_b   (alu_operand_b),
        .carry_in    (alu_carry_in),
        .result      (alu_result),
        .carry_out   (alu_carry_out),
        .overflow    (alu_overflow),
        .negative    (alu_negative),
        .zero        (alu_zero)
    );
    
    arm7tdmi_shifter u_shifter (
        .data_in     (shifter_data_in),
        .shift_type  (shifter_type),
        .shift_amount(shifter_amount),
        .carry_in    (shifter_carry_in),
        .data_out    (shifter_data_out),
        .carry_out   (shifter_carry_out)
    );

endmodule