import arm7tdmi_pkg::*;

module arm7tdmi_decode (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from fetch stage
    input  logic [31:0] instruction,
    input  logic [31:0] pc_in,
    input  logic        instr_valid,
    input  logic        thumb_mode,
    
    // Decoded instruction outputs
    output condition_t  condition,
    output instr_type_t instr_type,
    output alu_op_t     alu_op,
    output logic [3:0]  rd,      // Destination register
    output logic [3:0]  rn,      // First operand register
    output logic [3:0]  rm,      // Second operand register (if register)
    output logic [11:0] immediate, // Immediate value
    output logic        imm_en,   // Use immediate instead of register
    output logic        set_flags, // Update condition flags
    output shift_type_t shift_type,
    output logic [4:0]  shift_amount,
    
    // Branch instruction outputs
    output logic        is_branch,
    output logic [23:0] branch_offset,
    output logic        branch_link,
    
    // Memory instruction outputs
    output logic        is_memory,
    output logic        mem_load,   // 1 for load, 0 for store
    output logic        mem_byte,   // 1 for byte, 0 for word
    output logic        mem_pre,    // Pre-index
    output logic        mem_up,     // Add offset
    output logic        mem_writeback,
    
    // Output to execute stage
    output logic [31:0] pc_out,
    output logic        decode_valid,
    
    // Pipeline control
    input  logic        stall,
    input  logic        flush
);

    // Instruction fields (ARM format)
    logic [3:0]  cond_field;
    logic [1:0]  op_class;
    logic [5:0]  op_code;
    logic [3:0]  rd_field, rn_field, rm_field;
    logic [11:0] imm_field;
    logic        i_bit, s_bit;
    logic [1:0]  shift_type_field;
    logic [4:0]  shift_amt_field;
    
    // Branch instruction fields
    logic [23:0] branch_offset_field;
    logic        l_bit;
    
    // Memory instruction fields
    logic        p_bit, u_bit, b_bit, w_bit, l_bit_mem;
    
    // Decode registers
    logic [31:0] pc_reg;
    logic        valid_reg;
    
    // Extract instruction fields
    assign cond_field = instruction[31:28];
    assign op_class = instruction[27:26];
    assign i_bit = instruction[25];
    assign op_code = instruction[24:19];  // For data processing
    assign s_bit = instruction[20];
    assign rn_field = instruction[19:16];
    assign rd_field = instruction[15:12];
    assign rm_field = instruction[3:0];
    assign imm_field = instruction[11:0];
    assign shift_type_field = instruction[6:5];
    assign shift_amt_field = instruction[11:7];
    
    // Branch fields
    assign l_bit = instruction[24];
    assign branch_offset_field = instruction[23:0];
    
    // Memory fields
    assign p_bit = instruction[24];      // Pre/post index
    assign u_bit = instruction[23];      // Up/down
    assign b_bit = instruction[22];      // Byte/word
    assign w_bit = instruction[21];      // Write-back
    assign l_bit_mem = instruction[20];  // Load/store
    
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
            valid_reg <= instr_valid;
        end
    end
    
    // Instruction type decode
    always_comb begin
        instr_type = INSTR_UNDEFINED;
        
        if (!thumb_mode) begin  // ARM mode
            casez (instruction[27:25])
                3'b000: begin
                    if (instruction[7:4] == 4'b1001) begin
                        if (instruction[24:21] == 4'b0000) begin
                            instr_type = INSTR_MUL;
                        end else begin
                            instr_type = INSTR_MUL_LONG;
                        end
                    end else if (instruction[24:21] == 4'b1000 && instruction[7:4] == 4'b0000) begin
                        instr_type = INSTR_SINGLE_SWAP;
                    end else begin
                        instr_type = INSTR_DATA_PROC;
                    end
                end
                3'b001: instr_type = INSTR_DATA_PROC;
                3'b010: instr_type = INSTR_SINGLE_DT;
                3'b011: instr_type = INSTR_SINGLE_DT;
                3'b100: instr_type = INSTR_BLOCK_DT;
                3'b101: instr_type = INSTR_BRANCH;
                3'b110: instr_type = INSTR_COPROCESSOR;
                3'b111: begin
                    if (instruction[24]) begin
                        instr_type = INSTR_SWI;
                    end else begin
                        instr_type = INSTR_COPROCESSOR;
                    end
                end
            endcase
        end else begin
            // TODO: Implement Thumb instruction decode
            instr_type = INSTR_UNDEFINED;
        end
    end
    
    // Condition decode
    assign condition = cond_field;
    
    // ALU operation decode (for data processing instructions)
    assign alu_op = instruction[24:21];
    
    // Register assignments
    assign rd = rd_field;
    assign rn = rn_field;
    assign rm = rm_field;
    assign immediate = imm_field;
    assign imm_en = i_bit && (instr_type == INSTR_DATA_PROC);
    assign set_flags = s_bit && (instr_type == INSTR_DATA_PROC);
    
    // Shift decode
    assign shift_type = shift_type_field;
    assign shift_amount = shift_amt_field;
    
    // Branch decode
    assign is_branch = (instr_type == INSTR_BRANCH);
    assign branch_offset = branch_offset_field;
    assign branch_link = l_bit && is_branch;
    
    // Memory decode
    assign is_memory = (instr_type == INSTR_SINGLE_DT) || (instr_type == INSTR_BLOCK_DT);
    assign mem_load = l_bit_mem;
    assign mem_byte = b_bit;
    assign mem_pre = p_bit;
    assign mem_up = u_bit;
    assign mem_writeback = w_bit;
    
    // Outputs
    assign pc_out = pc_reg;
    assign decode_valid = valid_reg;
    
endmodule