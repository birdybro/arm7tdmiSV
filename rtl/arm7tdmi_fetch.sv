// import arm7tdmi_pkg::*;

module arm7tdmi_fetch (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  logic        fetch_en,
    input  logic        branch_taken,
    input  logic [31:0] branch_target,
    input  logic        thumb_mode,
    input  logic        high_vectors,      // High exception vectors from CP15
    
    // MMU interface (replaces direct memory interface)
    output logic [31:0] imem_vaddr,        // Virtual address to MMU
    output logic        imem_req,          // Memory request to MMU
    output logic        imem_write,        // Write enable (always 0 for fetch)
    output logic [1:0]  imem_size,         // Transfer size
    output logic [31:0] imem_wdata,        // Write data (unused)
    input  logic [31:0] imem_rdata,        // Read data from MMU
    input  logic        imem_ready,        // MMU ready
    input  logic        imem_abort,        // MMU abort (page fault)
    
    // Output to decode stage
    output logic [31:0] instruction,
    output logic [31:0] pc_out,
    output logic        instr_valid,
    
    // Pipeline control
    input  logic        stall,
    input  logic        flush,
    
    // Exception handling
    output logic        fetch_abort,       // Instruction fetch abort
    output logic [31:0] fetch_abort_addr   // Address that caused abort
);

    // Program counter
    logic [31:0] pc, next_pc;
    
    // ARM7TDMI prefetch buffer (2-stage)
    logic [31:0] prefetch_buffer [1:0];
    logic        prefetch_valid [1:0];
    logic [31:0] prefetch_pc [1:0];
    logic        prefetch_thumb [1:0];
    
    // Fetch state machine - enhanced for MMU and prefetch
    typedef enum logic [2:0] {
        IDLE,
        FETCHING,
        READY,
        ABORT,
        FLUSH_WAIT
    } fetch_state_t;
    
    fetch_state_t current_state, next_state;
    
    // Fetch control
    logic fetch_needed;
    logic prefetch_shift;
    
    // PC management - enhanced with high vectors support
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset vector - high or low based on CP15 setting
            pc <= high_vectors ? 32'hFFFF0000 : 32'h00000000;
        end else if (flush) begin
            // Keep current PC on pipeline flush, don't reset to 0
            pc <= pc;
        end else if (branch_taken) begin
            pc <= branch_target;
        end else if (prefetch_shift) begin
            // Increment PC when instruction is consumed by decode stage
            if (thumb_mode) begin
                pc <= pc + 32'd2;  // Thumb instructions are 2 bytes
            end else begin
                pc <= pc + 32'd4;  // ARM instructions are 4 bytes
            end
        end
    end
    
    // Fetch state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else if (flush) begin
            current_state <= FLUSH_WAIT;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic - enhanced for MMU and abort handling
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (fetch_en && fetch_needed && !stall) begin
                    next_state = FETCHING;
                end else if (fetch_en && prefetch_valid[0] && !stall) begin
                    next_state = READY;
                end
            end
            
            FETCHING: begin
                if (imem_ready && !imem_abort) begin
                    next_state = READY;
                end else if (imem_abort) begin
                    next_state = ABORT;
                end
            end
            
            READY: begin
                if (!stall) begin
                    if (fetch_en && fetch_needed) begin
                        next_state = FETCHING;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            
            ABORT: begin
                // Stay in abort state until pipeline flush
                if (flush) begin
                    next_state = FLUSH_WAIT;
                end
            end
            
            FLUSH_WAIT: begin
                // Wait one cycle after flush to ensure prefetch buffer is cleared
                next_state = IDLE;
            end
        endcase
    end
    
    //===========================================
    // Prefetch Buffer Management
    //===========================================
    
    // Determine fetch address for next prefetch  
    logic [31:0] fetch_addr;
    always_comb begin
        if (!prefetch_valid[0]) begin
            fetch_addr = pc;
        end else if (!prefetch_valid[1]) begin
            // Calculate next sequential address
            if (thumb_mode) begin
                fetch_addr = prefetch_pc[0] + 32'd4;  // Always fetch word-aligned for both modes
            end else begin
                fetch_addr = prefetch_pc[0] + 32'd4;
            end
        end else begin
            fetch_addr = pc;  // Shouldn't happen if logic is correct
        end
    end
    
    // Determine if we need to fetch
    assign fetch_needed = (!prefetch_valid[0] || !prefetch_valid[1]) && fetch_en;
    assign prefetch_shift = instr_valid && !stall;
    
    // Prefetch buffer management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefetch_buffer[0] <= 32'b0;
            prefetch_buffer[1] <= 32'b0;
            prefetch_valid[0] <= 1'b0;
            prefetch_valid[1] <= 1'b0;
            prefetch_pc[0] <= 32'b0;
            prefetch_pc[1] <= 32'b0;
            prefetch_thumb[0] <= 1'b0;
            prefetch_thumb[1] <= 1'b0;
        end else if (flush || (current_state == FLUSH_WAIT)) begin
            // Clear prefetch buffer on flush
            prefetch_valid[0] <= 1'b0;
            prefetch_valid[1] <= 1'b0;
        end else begin
            // Store fetched instruction
            if (current_state == FETCHING && imem_ready && !imem_abort) begin
                if (!prefetch_valid[0]) begin
                    prefetch_buffer[0] <= imem_rdata;
                    prefetch_valid[0] <= 1'b1;
                    prefetch_pc[0] <= pc;  // Store PC that corresponds to this instruction
                    prefetch_thumb[0] <= thumb_mode;
                end else if (!prefetch_valid[1]) begin
                    prefetch_buffer[1] <= imem_rdata;
                    prefetch_valid[1] <= 1'b1;
                    prefetch_pc[1] <= pc + (thumb_mode ? 32'd2 : 32'd4);  // Store next PC
                    prefetch_thumb[1] <= thumb_mode;
                end
            end
            
            // Shift prefetch buffer when instruction is consumed
            if (prefetch_shift) begin
                prefetch_buffer[0] <= prefetch_buffer[1];
                prefetch_valid[0] <= prefetch_valid[1];
                prefetch_pc[0] <= prefetch_pc[1];
                prefetch_thumb[0] <= prefetch_thumb[1];
                
                prefetch_valid[1] <= 1'b0;
            end
        end
    end
    
    //===========================================
    // MMU Interface
    //===========================================
    
    assign imem_vaddr = fetch_addr;
    assign imem_req = (current_state == FETCHING);
    assign imem_write = 1'b0;  // Instruction fetch is always read
    assign imem_size = 2'b10;  // Always word access for ARM
    assign imem_wdata = 32'b0; // Unused for reads
    
    //===========================================
    // Instruction Output with ARM/Thumb Handling
    //===========================================
    
    // Extract instruction based on mode and alignment - Icarus compatible
    logic [31:0] extracted_instruction;
    always_comb begin
        if (prefetch_valid[0]) begin
            if (prefetch_thumb[0]) begin
                // Thumb mode - extract 16-bit instruction
                case (prefetch_pc[0][1])
                    1'b0: extracted_instruction = {16'h0, prefetch_buffer[0][15:0]};
                    1'b1: extracted_instruction = {16'h0, prefetch_buffer[0][31:16]};
                endcase
            end else begin
                // ARM mode - use full 32-bit instruction
                extracted_instruction = prefetch_buffer[0];
            end
        end else begin
            extracted_instruction = 32'h0;
        end
    end
    
    //===========================================
    // Output Assignments
    //===========================================
    
    assign instruction = extracted_instruction;
    assign pc_out = pc;  // Always use current PC for consistent timing
    assign instr_valid = prefetch_valid[0] && fetch_en && !flush &&
                        (current_state != ABORT);
    
    assign fetch_abort = (current_state == ABORT);
    assign fetch_abort_addr = fetch_addr;
    
endmodule