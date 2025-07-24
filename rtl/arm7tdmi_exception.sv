import arm7tdmi_pkg::*;

module arm7tdmi_exception (
    input  logic        clk,
    input  logic        rst_n,
    
    // Exception inputs
    input  logic        irq,
    input  logic        fiq,
    input  logic        swi,
    input  logic        undefined_instr,
    input  logic        prefetch_abort,
    input  logic        data_abort,
    
    // Current processor state
    input  processor_mode_t current_mode,
    input  logic [31:0]     current_cpsr,
    input  logic [31:0]     current_pc,
    
    // Exception control
    output logic            exception_taken,
    output processor_mode_t exception_mode,
    output logic [31:0]     exception_vector,
    output logic [31:0]     exception_cpsr,
    output logic [31:0]     exception_spsr,
    
    // Exception priority (highest priority exception)
    output logic [2:0]      exception_type
);

    // Exception types
    parameter EXCEPT_RESET        = 3'd0;
    parameter EXCEPT_UNDEFINED    = 3'd1;
    parameter EXCEPT_SWI          = 3'd2;
    parameter EXCEPT_PREFETCH_ABT = 3'd3;
    parameter EXCEPT_DATA_ABT     = 3'd4;
    parameter EXCEPT_IRQ          = 3'd5;
    parameter EXCEPT_FIQ          = 3'd6;
    
    // Exception vectors
    parameter VECTOR_RESET        = 32'h00000000;
    parameter VECTOR_UNDEFINED    = 32'h00000004;
    parameter VECTOR_SWI          = 32'h00000008;
    parameter VECTOR_PREFETCH_ABT = 32'h0000000C;
    parameter VECTOR_DATA_ABT     = 32'h00000010;
    parameter VECTOR_IRQ          = 32'h00000018;
    parameter VECTOR_FIQ          = 32'h0000001C;
    
    // IRQ and FIQ disable bits
    logic irq_disabled, fiq_disabled;
    assign irq_disabled = current_cpsr[CPSR_I_BIT];
    assign fiq_disabled = current_cpsr[CPSR_F_BIT];
    
    // Exception priority logic (ARM7TDMI priority order)
    always_comb begin
        exception_taken = 1'b0;
        exception_type = EXCEPT_RESET;
        exception_mode = MODE_SUPERVISOR;
        exception_vector = VECTOR_RESET;
        
        // Priority order: Reset > Data Abort > FIQ > IRQ > Prefetch Abort > Undefined > SWI
        if (data_abort) begin
            exception_taken = 1'b1;
            exception_type = EXCEPT_DATA_ABT;
            exception_mode = MODE_ABORT;
            exception_vector = VECTOR_DATA_ABT;
        end else if (fiq && !fiq_disabled) begin
            exception_taken = 1'b1;
            exception_type = EXCEPT_FIQ;
            exception_mode = MODE_FIQ;
            exception_vector = VECTOR_FIQ;
        end else if (irq && !irq_disabled) begin
            exception_taken = 1'b1;
            exception_type = EXCEPT_IRQ;
            exception_mode = MODE_IRQ;
            exception_vector = VECTOR_IRQ;
        end else if (prefetch_abort) begin
            exception_taken = 1'b1;
            exception_type = EXCEPT_PREFETCH_ABT;
            exception_mode = MODE_ABORT;
            exception_vector = VECTOR_PREFETCH_ABT;
        end else if (undefined_instr) begin
            exception_taken = 1'b1;
            exception_type = EXCEPT_UNDEFINED;
            exception_mode = MODE_UNDEFINED;
            exception_vector = VECTOR_UNDEFINED;
        end else if (swi) begin
            exception_taken = 1'b1;
            exception_type = EXCEPT_SWI;
            exception_mode = MODE_SUPERVISOR;
            exception_vector = VECTOR_SWI;
        end
    end
    
    // Generate new CPSR for exception mode
    always_comb begin
        exception_cpsr = current_cpsr;
        
        if (exception_taken) begin
            // Set new processor mode
            exception_cpsr[4:0] = exception_mode;
            
            // Disable interrupts as appropriate
            case (exception_type)
                EXCEPT_FIQ: begin
                    exception_cpsr[CPSR_F_BIT] = 1'b1;  // Disable FIQ
                    exception_cpsr[CPSR_I_BIT] = 1'b1;  // Disable IRQ
                end
                EXCEPT_IRQ: begin
                    exception_cpsr[CPSR_I_BIT] = 1'b1;  // Disable IRQ
                end
                default: begin
                    exception_cpsr[CPSR_I_BIT] = 1'b1;  // Disable IRQ for other exceptions
                end
            endcase
            
            // Clear Thumb bit (exceptions always execute in ARM mode)
            exception_cpsr[CPSR_T_BIT] = 1'b0;
        end
    end
    
    // SPSR gets the old CPSR value
    assign exception_spsr = current_cpsr;

endmodule