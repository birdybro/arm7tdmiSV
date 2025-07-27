// ARM7TDMI Writeback Unit
// Final stage of the 5-stage pipeline: handles register writeback, CPSR updates, 
// PC control, exception handling, and instruction retirement

module arm7tdmi_writeback (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from memory stage
    input  logic [3:0]  instr_type,
    input  logic [31:0] alu_result,
    input  logic [31:0] load_data,
    input  logic [31:0] pc_in,
    input  logic        memory_valid,
    input  logic        memory_complete,
    
    // Register writeback inputs
    input  logic [3:0]  reg_write_addr,
    input  logic [31:0] reg_write_data,
    input  logic        reg_write_enable,
    
    // CPSR update inputs
    input  logic [31:0] cpsr_new,
    input  logic        cpsr_update,
    input  logic        set_flags,
    input  logic        alu_negative,
    input  logic        alu_zero,
    input  logic        alu_carry,
    input  logic        alu_overflow,
    
    // Branch control inputs
    input  logic        branch_taken,
    input  logic [31:0] branch_target,
    input  logic        branch_link,
    
    // Exception inputs
    input  logic        data_abort,
    input  logic [31:0] abort_address,
    input  logic        alignment_fault,
    input  logic        undefined_instr,
    input  logic        swi_exception,
    input  logic        irq_request,
    input  logic        fiq_request,
    
    // PSR transfer inputs
    input  logic        psr_to_reg,
    input  logic        psr_spsr,
    input  logic        psr_from_reg,
    input  logic [31:0] psr_data,
    
    // Register file interface
    output logic [3:0]  rf_write_addr,
    output logic [31:0] rf_write_data,
    output logic        rf_write_enable,
    output logic [31:0] rf_pc_new,
    output logic        rf_pc_write,
    output logic [31:0] rf_cpsr_new,
    output logic        rf_cpsr_write,
    output logic [31:0] rf_spsr_new,
    output logic        rf_spsr_write,
    output logic [4:0]  rf_mode_new,
    output logic        rf_mode_change,
    
    // Pipeline control outputs
    output logic        pipeline_flush,
    output logic        pipeline_stall,
    output logic [31:0] exception_vector,
    output logic        exception_taken,
    
    // Instruction retirement
    output logic        instr_retire,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instr_count,
    
    // Hazard detection and forwarding
    output logic [3:0]  forward_reg_addr,
    output logic [31:0] forward_reg_data,
    output logic        forward_valid,
    
    // Status outputs
    output logic [31:0] current_cpsr,
    output logic [4:0]  current_mode,
    output logic        thumb_state,
    output logic        irq_disabled,
    output logic        fiq_disabled,
    
    // Pipeline control inputs
    input  logic        stall,
    input  logic        flush
);

    // Instruction type constants
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

    // Processor mode constants
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

    // Exception vector addresses
    localparam [31:0] VEC_RESET      = 32'h00000000;
    localparam [31:0] VEC_UNDEFINED  = 32'h00000004;
    localparam [31:0] VEC_SWI        = 32'h00000008;
    localparam [31:0] VEC_PREFETCH   = 32'h0000000C;
    localparam [31:0] VEC_DATA_ABORT = 32'h00000010;
    localparam [31:0] VEC_IRQ        = 32'h00000018;
    localparam [31:0] VEC_FIQ        = 32'h0000001C;

    // Pipeline registers
    logic [31:0] pc_reg;
    logic        valid_reg;
    logic [31:0] instruction_count;
    
    // Current processor state
    logic [31:0] cpsr_current;
    logic [4:0]  mode_current;
    logic        thumb_current;
    logic        irq_disable_current;
    logic        fiq_disable_current;
    
    // Exception handling state
    logic        exception_pending;
    logic [31:0] exception_vector_addr;
    logic [4:0]  exception_target_mode;
    logic [31:0] exception_return_addr;
    logic [31:0] exception_spsr;
    
    // Writeback control signals
    logic [31:0] writeback_data;
    logic [3:0]  writeback_addr;
    logic        writeback_enable;
    logic        writeback_is_load;
    logic        writeback_is_alu;
    logic        writeback_is_pc;
    
    // CPSR update control
    logic [31:0] cpsr_updated;
    logic        cpsr_write_enable;
    logic        spsr_write_enable;
    logic [31:0] spsr_data;
    
    // Exception priority encoder
    logic        highest_priority_exception;
    logic [31:0] highest_priority_vector;
    logic [4:0]  highest_priority_mode;
    
    // Pipeline registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'b0;
            valid_reg <= 1'b0;
            instruction_count <= 32'b0;
            cpsr_current <= {27'b0, MODE_SUPERVISOR}; // Start in supervisor mode
            mode_current <= MODE_SUPERVISOR;
            thumb_current <= 1'b0;
            irq_disable_current <= 1'b1;  // Start with IRQs disabled
            fiq_disable_current <= 1'b1;  // Start with FIQs disabled
        end else if (flush || exception_taken) begin
            valid_reg <= 1'b0;
            if (exception_taken) begin
                // Update processor state for exception
                cpsr_current <= exception_spsr;
                mode_current <= exception_target_mode;
                thumb_current <= 1'b0;  // Always ARM mode after exception
                irq_disable_current <= 1'b1;
                fiq_disable_current <= (exception_target_mode == MODE_FIQ) ? 1'b1 : irq_disable_current;
            end
        end else if (!stall) begin
            pc_reg <= pc_in;
            valid_reg <= memory_valid;
            
            if (valid_reg && instr_retire) begin
                instruction_count <= instruction_count + 1;
            end
            
            // Update CPSR if required
            if (cpsr_write_enable) begin
                cpsr_current <= cpsr_updated;
                mode_current <= cpsr_updated[4:0];
                thumb_current <= cpsr_updated[CPSR_T_BIT];
                irq_disable_current <= cpsr_updated[CPSR_I_BIT];
                fiq_disable_current <= cpsr_updated[CPSR_F_BIT];
            end
        end
    end
    
    // Exception priority logic (highest priority first)
    always_comb begin
        highest_priority_exception = 1'b0;
        highest_priority_vector = VEC_RESET;
        highest_priority_mode = MODE_SUPERVISOR;
        
        if (fiq_request && !fiq_disable_current) begin
            highest_priority_exception = 1'b1;
            highest_priority_vector = VEC_FIQ;
            highest_priority_mode = MODE_FIQ;
        end else if (irq_request && !irq_disable_current) begin
            highest_priority_exception = 1'b1;
            highest_priority_vector = VEC_IRQ;
            highest_priority_mode = MODE_IRQ;
        end else if (data_abort || alignment_fault) begin
            highest_priority_exception = 1'b1;
            highest_priority_vector = VEC_DATA_ABORT;
            highest_priority_mode = MODE_ABORT;
        end else if (undefined_instr) begin
            highest_priority_exception = 1'b1;
            highest_priority_vector = VEC_UNDEFINED;
            highest_priority_mode = MODE_UNDEFINED;
        end else if (swi_exception) begin
            highest_priority_exception = 1'b1;
            highest_priority_vector = VEC_SWI;
            highest_priority_mode = MODE_SUPERVISOR;
        end
    end
    
    // Exception handling logic
    always_comb begin
        exception_pending = highest_priority_exception && valid_reg;
        exception_vector_addr = highest_priority_vector;
        exception_target_mode = highest_priority_mode;
        
        // Calculate return address based on exception type
        if (data_abort || alignment_fault) begin
            exception_return_addr = pc_reg; // Return to faulting instruction
        end else begin
            exception_return_addr = pc_reg + (thumb_current ? 32'd2 : 32'd4);
        end
        
        // Save current CPSR as SPSR for target mode
        exception_spsr = cpsr_current;
    end
    
    // Writeback data selection
    always_comb begin
        writeback_is_load = (instr_type == INSTR_SINGLE_DT || 
                           instr_type == INSTR_HALFWORD_DT || 
                           instr_type == INSTR_BLOCK_DT) && memory_complete;
        writeback_is_alu = (instr_type == INSTR_DATA_PROC || 
                          instr_type == INSTR_MUL || 
                          instr_type == INSTR_MUL_LONG);
        writeback_is_pc = (instr_type == INSTR_BRANCH) && branch_link;
        
        // Select writeback data source
        if (writeback_is_load) begin
            writeback_data = load_data;
        end else if (writeback_is_alu) begin
            writeback_data = alu_result;
        end else if (writeback_is_pc) begin
            writeback_data = pc_reg + (thumb_current ? 32'd2 : 32'd4); // Return address
        end else if (psr_to_reg) begin
            writeback_data = psr_spsr ? rf_spsr_new : cpsr_current;
        end else begin
            writeback_data = reg_write_data;
        end
        
        writeback_addr = reg_write_addr;
        writeback_enable = reg_write_enable && valid_reg && !exception_pending;
    end
    
    // CPSR update logic
    always_comb begin
        cpsr_updated = cpsr_current;
        cpsr_write_enable = 1'b0;
        spsr_write_enable = 1'b0;
        spsr_data = 32'b0;
        
        if (valid_reg && !exception_pending) begin
            if (cpsr_update) begin
                cpsr_updated = cpsr_new;
                cpsr_write_enable = 1'b1;
            end else if (set_flags && instr_type == INSTR_DATA_PROC) begin
                // Update condition flags from ALU
                cpsr_updated[CPSR_N_BIT] = alu_negative;
                cpsr_updated[CPSR_Z_BIT] = alu_zero;
                cpsr_updated[CPSR_C_BIT] = alu_carry;
                cpsr_updated[CPSR_V_BIT] = alu_overflow;
                cpsr_write_enable = 1'b1;
            end else if (psr_from_reg && instr_type == INSTR_PSR_TRANSFER) begin
                if (psr_spsr) begin
                    spsr_data = psr_data;
                    spsr_write_enable = 1'b1;
                end else begin
                    cpsr_updated = psr_data;
                    cpsr_write_enable = 1'b1;
                end
            end
        end
    end
    
    // Register file interface
    assign rf_write_addr = writeback_addr;
    assign rf_write_data = writeback_data;
    assign rf_write_enable = writeback_enable;
    assign rf_pc_new = exception_pending ? exception_vector_addr : branch_target;
    assign rf_pc_write = exception_pending || (branch_taken && valid_reg);
    assign rf_cpsr_new = cpsr_updated;
    assign rf_cpsr_write = cpsr_write_enable;
    assign rf_spsr_new = exception_pending ? exception_spsr : spsr_data;
    assign rf_spsr_write = exception_pending || spsr_write_enable;
    assign rf_mode_new = exception_pending ? exception_target_mode : cpsr_updated[4:0];
    assign rf_mode_change = exception_pending || (cpsr_write_enable && (cpsr_updated[4:0] != mode_current));
    
    // Pipeline control
    assign pipeline_flush = exception_pending || (branch_taken && valid_reg);
    assign pipeline_stall = 1'b0; // Writeback stage doesn't generate stalls
    assign exception_vector = exception_vector_addr;
    assign exception_taken = exception_pending;
    
    // Instruction retirement
    assign instr_retire = valid_reg && memory_complete && !exception_pending;
    assign retire_pc = pc_reg;
    assign retire_instr_count = instruction_count;
    
    // Hazard detection and forwarding
    assign forward_reg_addr = writeback_addr;
    assign forward_reg_data = writeback_data;
    assign forward_valid = writeback_enable;
    
    // Status outputs
    assign current_cpsr = cpsr_current;
    assign current_mode = mode_current;
    assign thumb_state = thumb_current;
    assign irq_disabled = irq_disable_current;
    assign fiq_disabled = fiq_disable_current;

endmodule