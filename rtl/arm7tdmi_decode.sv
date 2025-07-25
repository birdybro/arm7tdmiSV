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
    output logic        shift_reg,    // Use register for shift amount
    output logic [3:0]  shift_rs,    // Register containing shift amount
    
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
    
    // PSR transfer instruction outputs
    output logic        psr_to_reg,    // 1 for MRS, 0 for MSR
    output logic        psr_spsr,      // 1 for SPSR, 0 for CPSR
    output logic        psr_immediate, // 1 for immediate MSR
    
    // Coprocessor instruction outputs
    output cp_op_t      cp_op,         // Coprocessor operation type
    output logic [3:0]  cp_num,        // Coprocessor number (0-15)
    output logic [3:0]  cp_rd,         // Coprocessor destination register
    output logic [3:0]  cp_rn,         // Coprocessor operand register
    output logic [2:0]  cp_opcode1,    // Coprocessor opcode 1
    output logic [2:0]  cp_opcode2,    // Coprocessor opcode 2 (for CDP)
    output logic        cp_load,       // 1 for load, 0 for store (LDC/STC)
    
    // Thumb instruction outputs
    output thumb_instr_type_t thumb_instr_type, // Thumb instruction type
    output logic [2:0]  thumb_rd,      // Thumb destination register
    output logic [2:0]  thumb_rs,      // Thumb source register
    output logic [2:0]  thumb_rn,      // Thumb operand register
    output logic [7:0]  thumb_imm8,    // Thumb 8-bit immediate
    output logic [4:0]  thumb_imm5,    // Thumb 5-bit immediate
    output logic [10:0] thumb_offset11, // Thumb 11-bit branch offset
    output logic [7:0]  thumb_offset8,  // Thumb 8-bit branch offset
    
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
                    if ((instruction[24:21] == 4'b1000 || instruction[24:21] == 4'b1010) && 
                                instruction[20] == 1'b0 && instruction[19:16] == 4'b1111 && instruction[11:0] == 12'b000000000000) begin
                        // MRS: Move PSR to register (check before SWP)
                        instr_type = INSTR_PSR_TRANSFER;
                    end else if ((instruction[24:21] == 4'b1001 || instruction[24:21] == 4'b1011) && 
                                instruction[11:4] == 8'b00000000) begin
                        // MSR: Move register to PSR
                        instr_type = INSTR_PSR_TRANSFER;
                    end else if (instruction[27:23] == 5'b00010 && instruction[21:20] == 2'b00 && instruction[11:4] == 8'b00001001) begin
                        // SWP and SWPB - bits[27:23]=00010, bits[21:20]=00, bits[11:4]=00001001
                        instr_type = INSTR_SINGLE_SWAP;
                    end else if (instruction[7:4] == 4'b1001) begin
                        if (instruction[24:21] == 4'b0000 || instruction[24:21] == 4'b0001) begin
                            // MUL (0000) and MLA (0001) are single multiply instructions
                            instr_type = INSTR_MUL;
                        end else begin
                            // UMULL, UMLAL, SMULL, SMLAL are long multiply instructions
                            instr_type = INSTR_MUL_LONG;
                        end
                    end else if ((instruction[7:4] == 4'b1011) || (instruction[7:4] == 4'b1101) || (instruction[7:4] == 4'b1111)) begin
                        // Halfword data transfer: LDRH (1011), LDRSB (1101), LDRSH (1111)
                        instr_type = INSTR_HALFWORD_DT;
                    end else if (instruction[27:4] == 24'b000100101111111111110001) begin
                        // BX: Branch and Exchange - specific pattern match
                        instr_type = INSTR_BRANCH_EX;
                    end else begin
                        instr_type = INSTR_DATA_PROC;
                    end
                end
                3'b001: begin
                    if (instruction[27:23] == 5'b00110 && instruction[21:20] == 2'b10) begin
                        // MSR: Move immediate to PSR
                        instr_type = INSTR_PSR_TRANSFER;
                    end else begin
                        instr_type = INSTR_DATA_PROC;
                    end
                end
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
            // Thumb instruction decode (16-bit instructions)
            case (instruction[15:13])
                3'b000: begin
                    if (instruction[12:11] == 2'b11) begin
                        // ADD/SUB immediate
                        instr_type = INSTR_DATA_PROC;
                    end else begin
                        // Shift by immediate
                        instr_type = INSTR_DATA_PROC;
                    end
                end
                3'b001: begin
                    // Move/Compare/Add/Subtract immediate
                    instr_type = INSTR_DATA_PROC;
                end
                3'b010: begin
                    if (instruction[12:10] == 3'b000) begin
                        // ALU operations
                        instr_type = INSTR_DATA_PROC;
                    end else if (instruction[12:10] == 3'b001) begin
                        // Hi register operations/Branch exchange
                        if (instruction[9:8] == 2'b11 && instruction[7] == 1'b1) begin
                            instr_type = INSTR_BRANCH_EX;  // BX instruction
                        end else begin
                            instr_type = INSTR_DATA_PROC;
                        end
                    end else begin
                        // PC-relative load
                        instr_type = INSTR_SINGLE_DT;
                    end
                end
                3'b011: begin
                    // Load/Store register offset
                    instr_type = INSTR_SINGLE_DT;
                end
                3'b100: begin
                    if (instruction[12]) begin
                        // Load/Store halfword
                        instr_type = INSTR_HALFWORD_DT;
                    end else begin
                        // Load/Store immediate offset
                        instr_type = INSTR_SINGLE_DT;
                    end
                end
                3'b101: begin
                    if (instruction[12]) begin
                        // SP-relative load/store
                        instr_type = INSTR_SINGLE_DT;
                    end else begin
                        // Get relative address (ADD to PC/SP)
                        instr_type = INSTR_DATA_PROC;
                    end
                end
                3'b110: begin
                    if (instruction[12]) begin
                        if (instruction[11:8] == 4'b0100) begin
                            // Push/Pop
                            instr_type = INSTR_BLOCK_DT;
                        end else begin
                            // Miscellaneous instructions
                            instr_type = INSTR_DATA_PROC;
                        end
                    end else begin
                        // Add/Subtract to SP
                        instr_type = INSTR_DATA_PROC;
                    end
                end
                3'b111: begin
                    if (instruction[12]) begin
                        if (instruction[11:8] == 4'b1111) begin
                            // Software interrupt
                            instr_type = INSTR_SWI;
                        end else begin
                            // Conditional branch
                            instr_type = INSTR_BRANCH;
                        end
                    end else begin
                        if (instruction[11]) begin
                            // Unconditional branch
                            instr_type = INSTR_BRANCH;
                        end else begin
                            // Load/Store multiple
                            instr_type = INSTR_BLOCK_DT;
                        end
                    end
                end
            endcase
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
    assign imm_en = (i_bit && (instr_type == INSTR_DATA_PROC)) || (!i_bit && (instr_type == INSTR_SINGLE_DT)) || (instruction[22] && (instr_type == INSTR_HALFWORD_DT));
    assign set_flags = s_bit && (instr_type == INSTR_DATA_PROC);
    
    // Shift decode - ARM data processing instructions
    assign shift_type = shift_type_field;
    assign shift_reg = !imm_en && (instr_type == INSTR_DATA_PROC) && instruction[4] && instruction[7] == 1'b0;
    assign shift_rs = instruction[11:8];  // Rs register for register-controlled shifts
    assign shift_amount = shift_reg ? 5'b0 : shift_amt_field;  // Use Rs[7:0] when shift_reg is true
    
    // Branch decode
    assign is_branch = (instr_type == INSTR_BRANCH);
    assign branch_offset = branch_offset_field;
    assign branch_link = l_bit && is_branch;
    
    // Memory decode
    assign is_memory = (instr_type == INSTR_SINGLE_DT) || (instr_type == INSTR_HALFWORD_DT) || 
                       (instr_type == INSTR_BLOCK_DT) || (instr_type == INSTR_SINGLE_SWAP);
    assign mem_load = l_bit_mem;
    assign mem_byte = b_bit;
    assign mem_pre = p_bit;
    assign mem_up = u_bit;
    assign mem_writeback = w_bit;
    
    // PSR transfer decode
    assign psr_to_reg = (instr_type == INSTR_PSR_TRANSFER) && !instruction[21];  // MRS = L=0, MSR = L=1
    assign psr_spsr = (instr_type == INSTR_PSR_TRANSFER) && instruction[22];     // SPSR = R=1, CPSR = R=0  
    assign psr_immediate = (instr_type == INSTR_PSR_TRANSFER) && instruction[25]; // Immediate MSR
    
    // Coprocessor decode
    always_comb begin
        cp_op = CP_CDP;
        cp_num = 4'b0;
        cp_rd = 4'b0;
        cp_rn = 4'b0;
        cp_opcode1 = 3'b0;
        cp_opcode2 = 3'b0;
        cp_load = 1'b0;
        
        if (instr_type == INSTR_COPROCESSOR) begin
            cp_num = instruction[11:8];  // Coprocessor number
            
            if (instruction[27:25] == 3'b110) begin
                // LDC/STC - Coprocessor data transfer
                cp_rd = instruction[15:12];     // CRd
                cp_opcode1 = instruction[23:21]; // Opcode
                cp_load = instruction[20];       // L bit
                
                if (cp_load) begin
                    cp_op = CP_LDC;
                end else begin
                    cp_op = CP_STC;
                end
            end else if (instruction[27:25] == 3'b111) begin
                if (instruction[4]) begin
                    // MCR/MRC - Coprocessor register transfer
                    cp_rd = instruction[15:12];     // Rd (ARM register)
                    cp_rn = instruction[19:16];     // CRn (coprocessor register)
                    cp_opcode1 = instruction[23:21]; // Opcode 1
                    cp_opcode2 = instruction[7:5];   // Opcode 2
                    
                    if (instruction[20]) begin
                        cp_op = CP_MRC;  // Move to ARM from coprocessor
                    end else begin
                        cp_op = CP_MCR;  // Move to coprocessor from ARM
                    end
                end else begin
                    // CDP - Coprocessor data processing
                    cp_op = CP_CDP;
                    cp_rd = instruction[15:12];     // CRd
                    cp_rn = instruction[19:16];     // CRn
                    cp_opcode1 = instruction[23:21]; // Opcode 1
                    cp_opcode2 = instruction[7:5];   // Opcode 2
                end
            end
        end
    end
    
    // Thumb instruction decode
    always_comb begin
        thumb_instr_type = THUMB_ALU_REG;
        thumb_rd = 3'b0;
        thumb_rs = 3'b0;
        thumb_rn = 3'b0;
        thumb_imm8 = 8'b0;
        thumb_imm5 = 5'b0;
        thumb_offset11 = 11'b0;
        thumb_offset8 = 8'b0;
        
        if (thumb_mode) begin
            // Check for BL instruction first (top-level 11110/11111 patterns)
            if (instruction[15:11] == 5'b11110) begin
                // BL/BLX prefix - high part (H=10)
                thumb_instr_type = THUMB_BL_HIGH;
                thumb_offset11 = instruction[10:0]; // High offset
            end else if (instruction[15:11] == 5'b11111) begin
                // BL suffix - low part (H=11)  
                thumb_instr_type = THUMB_BL_LOW;
                thumb_offset11 = instruction[10:0]; // Low offset
            end else begin
                // Extract common fields
                thumb_rd = instruction[2:0];   // Destination register (low 3 bits)
                thumb_rs = instruction[5:3];   // Source register
                thumb_rn = instruction[8:6];   // Operand register
                
                case (instruction[15:13])
                3'b000: begin
                    if (instruction[12:11] == 2'b11) begin
                        // ADD/SUB immediate  
                        thumb_instr_type = THUMB_ALU_IMM;
                        thumb_imm5 = {2'b0, instruction[8:6]}; // 3-bit immediate
                    end else begin
                        // Shift by immediate
                        thumb_instr_type = THUMB_SHIFT;
                        thumb_imm5 = instruction[10:6];
                    end
                end
                3'b001: begin
                    // Move/Compare/Add/Subtract immediate
                    thumb_instr_type = THUMB_CMP_MOV_IMM;
                    thumb_rd = instruction[10:8];  // 3-bit register field
                    thumb_imm8 = instruction[7:0];
                end
                3'b010: begin
                    if (instruction[12:10] == 3'b000) begin
                        // ALU operations
                        thumb_instr_type = THUMB_ALU_REG;
                    end else if (instruction[12:10] == 3'b001) begin
                        // Hi register operations
                        thumb_instr_type = THUMB_ALU_HI;
                        thumb_rd = {instruction[7], instruction[2:0]}; // 4-bit register
                        thumb_rs = instruction[6:3];  // 4-bit register
                    end else if (instruction[12:10] == 3'b101) begin
                        // Load/Store register offset
                        thumb_instr_type = THUMB_LOAD_STORE;
                    end else begin
                        // PC-relative load
                        thumb_instr_type = THUMB_PC_REL_LOAD;
                        thumb_rd = instruction[10:8];
                        thumb_imm8 = instruction[7:0];
                    end
                end
                3'b011: begin
                    // Load/Store with immediate offset (5-bit)
                    thumb_instr_type = THUMB_LOAD_STORE_IMM;
                    thumb_imm5 = instruction[10:6];
                end
                3'b100: begin
                    if (instruction[11]) begin
                        // Load/Store halfword
                        thumb_instr_type = THUMB_LOAD_STORE_HW;
                        thumb_imm5 = instruction[10:6];
                    end else begin
                        // Load/Store immediate offset
                        thumb_instr_type = THUMB_LOAD_STORE_IMM;
                        thumb_imm5 = instruction[10:6];
                    end
                end
                3'b101: begin
                    if (instruction[12]) begin
                        // SP-relative load/store
                        thumb_instr_type = THUMB_SP_REL_LOAD;
                        thumb_rd = instruction[10:8];
                        thumb_imm8 = instruction[7:0];
                    end else begin
                        // Get relative address
                        thumb_instr_type = THUMB_GET_REL_ADDR;
                        thumb_rd = instruction[10:8];
                        thumb_imm8 = instruction[7:0];
                    end
                end
                3'b110: begin
                    if (instruction[12]) begin
                        if (instruction[11:8] == 4'b0100) begin
                            // Push/Pop
                            thumb_instr_type = THUMB_PUSH_POP;
                        end else if (instruction[11:8] == 4'b1111) begin
                            // Software interrupt
                            thumb_instr_type = THUMB_ALU_REG; // Placeholder, should be SWI
                            thumb_imm8 = instruction[7:0];
                        end else begin
                            // Conditional branch
                            thumb_instr_type = THUMB_BRANCH_COND;
                            thumb_offset8 = instruction[7:0];
                        end
                    end else begin
                        // Load/Store multiple
                        thumb_instr_type = THUMB_LOAD_STORE_MULT;
                        thumb_rd = instruction[10:8];
                        thumb_imm8 = instruction[7:0];
                    end
                end
                3'b111: begin
                    if (instruction[12]) begin
                        if (instruction[11:8] == 4'b1111) begin
                            // Software interrupt
                            thumb_imm8 = instruction[7:0];
                        end else begin
                            // Conditional branch
                            thumb_instr_type = THUMB_BRANCH_COND;
                            thumb_offset8 = instruction[7:0];
                        end
                    end else begin
                        // Unconditional branch
                        thumb_instr_type = THUMB_BRANCH_UNCOND;
                        thumb_offset11 = instruction[10:0];
                    end
                end
                endcase
            end
        end
    end
    
    // Outputs
    assign pc_out = pc_reg;
    assign decode_valid = valid_reg;
    
endmodule