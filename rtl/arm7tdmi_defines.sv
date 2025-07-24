package arm7tdmi_pkg;

    // Processor modes
    typedef enum logic [4:0] {
        MODE_USER       = 5'b10000,
        MODE_FIQ        = 5'b10001,
        MODE_IRQ        = 5'b10010,
        MODE_SUPERVISOR = 5'b10011,
        MODE_ABORT      = 5'b10111,
        MODE_UNDEFINED  = 5'b11011,
        MODE_SYSTEM     = 5'b11111
    } processor_mode_t;
    
    // CPU pipeline states
    typedef enum logic [2:0] {
        FETCH,
        DECODE,
        EXECUTE,
        MEMORY,
        WRITEBACK
    } cpu_state_t;
    
    // ARM instruction types
    typedef enum logic [3:0] {
        INSTR_DATA_PROC   = 4'b0000,
        INSTR_MUL         = 4'b0001,
        INSTR_MUL_LONG    = 4'b0010,
        INSTR_SINGLE_SWAP = 4'b0011,
        INSTR_BRANCH_EX   = 4'b0100,
        INSTR_HALFWORD_DT = 4'b0101,
        INSTR_SINGLE_DT   = 4'b0110,
        INSTR_UNDEFINED   = 4'b0111,
        INSTR_BLOCK_DT    = 4'b1000,
        INSTR_BRANCH      = 4'b1001,
        INSTR_COPROCESSOR = 4'b1010,
        INSTR_SWI         = 4'b1011,
        INSTR_PSR_TRANSFER = 4'b1100
    } instr_type_t;
    
    // ALU operations
    typedef enum logic [3:0] {
        ALU_AND = 4'b0000,
        ALU_EOR = 4'b0001,
        ALU_SUB = 4'b0010,
        ALU_RSB = 4'b0011,
        ALU_ADD = 4'b0100,
        ALU_ADC = 4'b0101,
        ALU_SBC = 4'b0110,
        ALU_RSC = 4'b0111,
        ALU_TST = 4'b1000,
        ALU_TEQ = 4'b1001,
        ALU_CMP = 4'b1010,
        ALU_CMN = 4'b1011,
        ALU_ORR = 4'b1100,
        ALU_MOV = 4'b1101,
        ALU_BIC = 4'b1110,
        ALU_MVN = 4'b1111
    } alu_op_t;
    
    // Condition codes
    typedef enum logic [3:0] {
        COND_EQ = 4'b0000,  // Equal
        COND_NE = 4'b0001,  // Not equal
        COND_CS = 4'b0010,  // Carry set
        COND_CC = 4'b0011,  // Carry clear
        COND_MI = 4'b0100,  // Minus
        COND_PL = 4'b0101,  // Plus
        COND_VS = 4'b0110,  // Overflow set
        COND_VC = 4'b0111,  // Overflow clear
        COND_HI = 4'b1000,  // Higher
        COND_LS = 4'b1001,  // Lower or same
        COND_GE = 4'b1010,  // Greater or equal
        COND_LT = 4'b1011,  // Less than
        COND_GT = 4'b1100,  // Greater than
        COND_LE = 4'b1101,  // Less or equal
        COND_AL = 4'b1110,  // Always
        COND_NV = 4'b1111   // Never
    } condition_t;
    
    // Shift types
    typedef enum logic [1:0] {
        SHIFT_LSL = 2'b00,  // Logical shift left
        SHIFT_LSR = 2'b01,  // Logical shift right
        SHIFT_ASR = 2'b10,  // Arithmetic shift right
        SHIFT_ROR = 2'b11   // Rotate right
    } shift_type_t;
    
    // Register addresses
    parameter R0  = 4'd0;
    parameter R1  = 4'd1;
    parameter R2  = 4'd2;
    parameter R3  = 4'd3;
    parameter R4  = 4'd4;
    parameter R5  = 4'd5;
    parameter R6  = 4'd6;
    parameter R7  = 4'd7;
    parameter R8  = 4'd8;
    parameter R9  = 4'd9;
    parameter R10 = 4'd10;
    parameter R11 = 4'd11;
    parameter R12 = 4'd12;
    parameter R13 = 4'd13;  // SP
    parameter R14 = 4'd14;  // LR
    parameter R15 = 4'd15;  // PC
    
    // CPSR bit positions
    parameter CPSR_N_BIT = 31;  // Negative flag
    parameter CPSR_Z_BIT = 30;  // Zero flag
    parameter CPSR_C_BIT = 29;  // Carry flag
    parameter CPSR_V_BIT = 28;  // Overflow flag
    parameter CPSR_I_BIT = 7;   // IRQ disable
    parameter CPSR_F_BIT = 6;   // FIQ disable
    parameter CPSR_T_BIT = 5;   // Thumb state
    
    // Coprocessor instruction types
    typedef enum logic [2:0] {
        CP_CDP = 3'b000,  // Coprocessor Data Processing
        CP_LDC = 3'b001,  // Load Coprocessor
        CP_STC = 3'b010,  // Store Coprocessor  
        CP_MCR = 3'b011,  // Move to Coprocessor from ARM
        CP_MRC = 3'b100   // Move to ARM from Coprocessor
    } cp_op_t;
    
    // Thumb instruction types  
    typedef enum logic [4:0] {
        THUMB_ALU_IMM     = 5'b00000,  // ALU with immediate (ADD/SUB)
        THUMB_ALU_REG     = 5'b00001,  // ALU register operations
        THUMB_SHIFT       = 5'b00010,  // Shift operations
        THUMB_CMP_MOV_IMM = 5'b00011,  // Compare/Move immediate
        THUMB_ALU_HI      = 5'b00100,  // ALU operations with high registers
        THUMB_PC_REL_LOAD = 5'b00101,  // PC-relative load
        THUMB_LOAD_STORE  = 5'b00110,  // Load/Store register offset
        THUMB_LOAD_STORE_IMM = 5'b00111, // Load/Store immediate offset
        THUMB_LOAD_STORE_HW  = 5'b01000, // Load/Store halfword
        THUMB_SP_REL_LOAD    = 5'b01001, // SP-relative load/store
        THUMB_GET_REL_ADDR   = 5'b01010, // Get relative address
        THUMB_ADD_SUB_SP     = 5'b01011, // Add/Subtract to SP
        THUMB_PUSH_POP       = 5'b01100, // Push/Pop multiple
        THUMB_LOAD_STORE_MULT = 5'b01101, // Load/Store multiple
        THUMB_BRANCH_COND    = 5'b01110, // Conditional branch
        THUMB_BRANCH_UNCOND  = 5'b01111, // Unconditional branch
        THUMB_BL_HIGH        = 5'b10000, // BL high part (H=10)
        THUMB_BL_LOW         = 5'b10001  // BL low part (H=11)
    } thumb_instr_type_t;
    
endpackage