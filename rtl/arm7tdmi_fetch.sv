import arm7tdmi_pkg::*;

module arm7tdmi_fetch (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  logic        fetch_en,
    input  logic        branch_taken,
    input  logic [31:0] branch_target,
    input  logic        thumb_mode,
    
    // Memory interface
    output logic [31:0] mem_addr,
    output logic        mem_re,
    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,
    
    // Output to decode stage
    output logic [31:0] instruction,
    output logic [31:0] pc_out,
    output logic        instr_valid,
    
    // Pipeline control
    input  logic        stall,
    input  logic        flush
);

    // Program counter
    logic [31:0] pc, next_pc;
    
    // Instruction buffer
    logic [31:0] instr_buffer;
    logic        instr_ready;
    
    // Fetch state machine
    typedef enum logic [1:0] {
        IDLE,
        FETCHING,
        READY
    } fetch_state_t;
    
    fetch_state_t current_state, next_state;
    
    // PC management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0000_0000;
        end else if (flush) begin
            pc <= 32'h0000_0000;
        end else if (branch_taken) begin
            pc <= branch_target;
        end else if (fetch_en && !stall) begin
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
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (fetch_en && !stall) begin
                    next_state = FETCHING;
                end
            end
            
            FETCHING: begin
                if (mem_ready) begin
                    next_state = READY;
                end
            end
            
            READY: begin
                if (!stall) begin
                    if (fetch_en) begin
                        next_state = FETCHING;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
        endcase
    end
    
    // Memory interface
    always_comb begin
        mem_addr = pc;
        mem_re = (current_state == FETCHING) || 
                 (current_state == IDLE && fetch_en && !stall);
    end
    
    // Instruction buffer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_buffer <= 32'b0;
            instr_ready <= 1'b0;
        end else if (flush) begin
            instr_buffer <= 32'b0;
            instr_ready <= 1'b0;
        end else if (current_state == FETCHING && mem_ready) begin
            instr_buffer <= mem_rdata;
            instr_ready <= 1'b1;
        end else if (current_state == READY && !stall) begin
            instr_ready <= 1'b0;
        end
    end
    
    // Output logic
    assign instruction = instr_buffer;
    assign pc_out = pc;
    assign instr_valid = instr_ready && (current_state == READY);
    
endmodule