// ARM7TDMI Memory/Load-Store Unit
// Integrates single data transfer, block data transfer, MMU, and data cache

module arm7tdmi_memory (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from execute stage
    input  logic [3:0]  instr_type,
    input  logic [31:0] memory_address,
    input  logic [31:0] store_data,
    input  logic        mem_req,
    input  logic        mem_write,
    input  logic [1:0]  mem_size,
    input  logic [31:0] pc_in,
    input  logic        execute_valid,
    
    // Load/Store instruction details
    input  logic        mem_load,
    input  logic        mem_byte,
    input  logic        mem_halfword,
    input  logic        mem_signed,
    input  logic        mem_pre,
    input  logic        mem_up,
    input  logic        mem_writeback,
    
    // Block data transfer (LDM/STM) inputs
    input  logic        block_en,
    input  logic        block_load,
    input  logic        block_pre,
    input  logic        block_up,
    input  logic        block_writeback,
    input  logic        block_user_mode,
    input  logic [15:0] register_list,
    input  logic [3:0]  base_register,
    input  logic [31:0] base_address,
    
    // Register file interface
    output logic [3:0]  reg_read_addr,
    input  logic [31:0] reg_read_data,
    output logic [3:0]  reg_write_addr,
    output logic [31:0] reg_write_data,
    output logic        reg_write_enable,
    
    // MMU interface for data accesses
    output logic [31:0] dmem_vaddr,
    output logic        dmem_req,
    output logic        dmem_write,
    output logic [1:0]  dmem_size,
    output logic [31:0] dmem_wdata,
    output logic [3:0]  dmem_byte_en,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_ready,
    input  logic        dmem_abort,
    
    // Cache control interface
    output logic        cache_enable,
    output logic        cache_flush,
    input  logic        cache_hit,
    input  logic        cache_busy,
    
    // Outputs to writeback stage
    output logic [31:0] load_data,
    output logic [31:0] pc_out,
    output logic        memory_valid,
    output logic        memory_complete,
    
    // Exception outputs
    output logic        data_abort,
    output logic [31:0] abort_address,
    output logic        alignment_fault,
    
    // Pipeline control
    input  logic        stall,
    input  logic        flush
);

    // Instruction type constants
    localparam [3:0] INSTR_DATA_PROC   = 4'b0000;
    localparam [3:0] INSTR_SINGLE_DT   = 4'b0110;
    localparam [3:0] INSTR_HALFWORD_DT = 4'b0101;
    localparam [3:0] INSTR_BLOCK_DT    = 4'b1000;
    localparam [3:0] INSTR_SINGLE_SWAP = 4'b0011;

    // Pipeline registers
    logic [31:0] pc_reg;
    logic        valid_reg;
    
    // Memory operation state machine
    typedef enum logic [2:0] {
        MEM_IDLE,
        MEM_SINGLE,
        MEM_BLOCK,
        MEM_SWAP,
        MEM_COMPLETE,
        MEM_ABORT,
        MEM_WAIT
    } mem_state_t;
    
    mem_state_t mem_state, mem_next_state;
    
    // Internal control signals
    logic        is_single_transfer;
    logic        is_block_transfer;
    logic        is_swap_operation;
    logic        memory_operation;
    logic [31:0] effective_address;
    logic [31:0] load_result;
    logic        transfer_complete;
    logic        address_valid;
    
    // Block data transfer interface
    logic        block_dt_en;
    logic        block_dt_complete;
    logic        block_dt_active;
    logic [3:0]  block_reg_addr;
    logic [31:0] block_reg_wdata;
    logic        block_reg_we;
    logic [3:0]  block_base_reg_addr;
    logic [31:0] block_base_reg_data;
    logic        block_base_reg_we;
    logic [31:0] block_mem_addr;
    logic [31:0] block_mem_wdata;
    logic        block_mem_we;
    logic        block_mem_re;
    
    // Data alignment and sign extension
    logic [31:0] aligned_load_data;
    logic [3:0]  byte_enables;
    logic [31:0] aligned_store_data;
    
    // Address alignment checking
    logic        word_aligned;
    logic        halfword_aligned;
    logic        alignment_error;
    
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
            valid_reg <= execute_valid;
        end
    end
    
    // Memory operation detection
    always_comb begin
        is_single_transfer = (instr_type == INSTR_SINGLE_DT || instr_type == INSTR_HALFWORD_DT);
        is_block_transfer = (instr_type == INSTR_BLOCK_DT);
        is_swap_operation = (instr_type == INSTR_SINGLE_SWAP);
        memory_operation = mem_req && (is_single_transfer || is_block_transfer || is_swap_operation);
    end
    
    // Address alignment checking
    assign word_aligned = (memory_address[1:0] == 2'b00);
    assign halfword_aligned = (memory_address[0] == 1'b0);
    
    always_comb begin
        alignment_error = 1'b0;
        case (mem_size)
            2'b10: alignment_error = !word_aligned;     // Word access
            2'b01: alignment_error = !halfword_aligned; // Halfword access
            2'b00: alignment_error = 1'b0;              // Byte access - always aligned
            default: alignment_error = 1'b0;
        endcase
    end
    
    // Effective address calculation (already done in execute stage)
    assign effective_address = memory_address;
    assign address_valid = !alignment_error && !dmem_abort;
    
    // Memory state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_state <= MEM_IDLE;
        end else if (flush) begin
            mem_state <= MEM_IDLE;
        end else begin
            mem_state <= mem_next_state;
        end
    end
    
    // Memory state machine logic
    always_comb begin
        mem_next_state = mem_state;
        
        case (mem_state)
            MEM_IDLE: begin
                if (valid_reg && memory_operation) begin
                    if (alignment_error) begin
                        mem_next_state = MEM_ABORT;
                    end else if (is_single_transfer || is_swap_operation) begin
                        mem_next_state = MEM_SINGLE;
                    end else if (is_block_transfer) begin
                        mem_next_state = MEM_BLOCK;
                    end
                end
            end
            
            MEM_SINGLE: begin
                if (dmem_ready) begin
                    if (dmem_abort) begin
                        mem_next_state = MEM_ABORT;
                    end else begin
                        mem_next_state = MEM_COMPLETE;
                    end
                end else begin
                    mem_next_state = MEM_WAIT;
                end
            end
            
            MEM_BLOCK: begin
                if (block_dt_complete) begin
                    mem_next_state = MEM_COMPLETE;
                end else if (dmem_abort) begin
                    mem_next_state = MEM_ABORT;
                end
            end
            
            MEM_SWAP: begin
                // Swap operations require two memory accesses
                if (dmem_ready) begin
                    if (dmem_abort) begin
                        mem_next_state = MEM_ABORT;
                    end else begin
                        mem_next_state = MEM_COMPLETE;
                    end
                end
            end
            
            MEM_WAIT: begin
                if (dmem_ready) begin
                    if (dmem_abort) begin
                        mem_next_state = MEM_ABORT;
                    end else begin
                        mem_next_state = MEM_COMPLETE;
                    end
                end
            end
            
            MEM_COMPLETE: begin
                if (!stall) begin
                    mem_next_state = MEM_IDLE;
                end
            end
            
            MEM_ABORT: begin
                if (!stall) begin
                    mem_next_state = MEM_IDLE;
                end
            end
        endcase
    end
    
    // Byte enable generation
    always_comb begin
        byte_enables = 4'b0000;
        case (mem_size)
            2'b00: begin // Byte access
                case (effective_address[1:0])
                    2'b00: byte_enables = 4'b0001;
                    2'b01: byte_enables = 4'b0010;
                    2'b10: byte_enables = 4'b0100;
                    2'b11: byte_enables = 4'b1000;
                endcase
            end
            2'b01: begin // Halfword access
                case (effective_address[1])
                    1'b0: byte_enables = 4'b0011;
                    1'b1: byte_enables = 4'b1100;
                endcase
            end
            2'b10: begin // Word access
                byte_enables = 4'b1111;
            end
            default: byte_enables = 4'b0000;
        endcase
    end
    
    // Store data alignment
    always_comb begin
        aligned_store_data = store_data;
        case (mem_size)
            2'b00: begin // Byte store
                case (effective_address[1:0])
                    2'b00: aligned_store_data = {24'b0, store_data[7:0]};
                    2'b01: aligned_store_data = {16'b0, store_data[7:0], 8'b0};
                    2'b10: aligned_store_data = {8'b0, store_data[7:0], 16'b0};
                    2'b11: aligned_store_data = {store_data[7:0], 24'b0};
                endcase
            end
            2'b01: begin // Halfword store
                case (effective_address[1])
                    1'b0: aligned_store_data = {16'b0, store_data[15:0]};
                    1'b1: aligned_store_data = {store_data[15:0], 16'b0};
                endcase
            end
            2'b10: begin // Word store
                aligned_store_data = store_data;
            end
            default: aligned_store_data = store_data;
        endcase
    end
    
    // Load data alignment and sign extension
    always_comb begin
        aligned_load_data = dmem_rdata;
        case (mem_size)
            2'b00: begin // Byte load
                case (effective_address[1:0])
                    2'b00: begin
                        if (mem_signed && dmem_rdata[7]) begin
                            aligned_load_data = {{24{1'b1}}, dmem_rdata[7:0]};
                        end else begin
                            aligned_load_data = {24'b0, dmem_rdata[7:0]};
                        end
                    end
                    2'b01: begin
                        if (mem_signed && dmem_rdata[15]) begin
                            aligned_load_data = {{24{1'b1}}, dmem_rdata[15:8]};
                        end else begin
                            aligned_load_data = {24'b0, dmem_rdata[15:8]};
                        end
                    end
                    2'b10: begin
                        if (mem_signed && dmem_rdata[23]) begin
                            aligned_load_data = {{24{1'b1}}, dmem_rdata[23:16]};
                        end else begin
                            aligned_load_data = {24'b0, dmem_rdata[23:16]};
                        end
                    end
                    2'b11: begin
                        if (mem_signed && dmem_rdata[31]) begin
                            aligned_load_data = {{24{1'b1}}, dmem_rdata[31:24]};
                        end else begin
                            aligned_load_data = {24'b0, dmem_rdata[31:24]};
                        end
                    end
                endcase
            end
            2'b01: begin // Halfword load
                case (effective_address[1])
                    1'b0: begin
                        if (mem_signed && dmem_rdata[15]) begin
                            aligned_load_data = {{16{1'b1}}, dmem_rdata[15:0]};
                        end else begin
                            aligned_load_data = {16'b0, dmem_rdata[15:0]};
                        end
                    end
                    1'b1: begin
                        if (mem_signed && dmem_rdata[31]) begin
                            aligned_load_data = {{16{1'b1}}, dmem_rdata[31:16]};
                        end else begin
                            aligned_load_data = {16'b0, dmem_rdata[31:16]};
                        end
                    end
                endcase
            end
            2'b10: begin // Word load
                aligned_load_data = dmem_rdata;
            end
            default: aligned_load_data = dmem_rdata;
        endcase
    end
    
    // Block data transfer control
    assign block_dt_en = (mem_state == MEM_BLOCK) && is_block_transfer;
    
    // Register file interface for single transfers
    always_comb begin
        if (is_block_transfer && block_dt_active) begin
            // Block transfer controls register file
            reg_read_addr = block_reg_addr;
            reg_write_addr = block_reg_addr;
            reg_write_data = block_reg_wdata;
            reg_write_enable = block_reg_we;
        end else if (mem_load && (mem_state == MEM_COMPLETE)) begin
            // Single load operation
            reg_read_addr = 4'h0;  // Not used for loads
            reg_write_addr = base_register;  // Destination register
            reg_write_data = aligned_load_data;
            reg_write_enable = 1'b1;
        end else begin
            // Default/no operation
            reg_read_addr = base_register;  // Source register for stores
            reg_write_addr = 4'h0;
            reg_write_data = 32'h0;
            reg_write_enable = 1'b0;
        end
    end
    
    // MMU/Memory interface
    always_comb begin
        if (is_block_transfer && block_dt_active) begin
            // Block transfer controls memory
            dmem_vaddr = block_mem_addr;
            dmem_req = block_mem_we || block_mem_re;
            dmem_write = block_mem_we;
            dmem_size = 2'b10;  // Always word for block transfers
            dmem_wdata = block_mem_wdata;
            dmem_byte_en = 4'b1111;  // Always full word
        end else if (mem_state == MEM_SINGLE || mem_state == MEM_WAIT) begin
            // Single transfer
            dmem_vaddr = effective_address;
            dmem_req = 1'b1;
            dmem_write = mem_write;
            dmem_size = mem_size;
            dmem_wdata = aligned_store_data;
            dmem_byte_en = byte_enables;
        end else begin
            // No memory operation
            dmem_vaddr = 32'h0;
            dmem_req = 1'b0;
            dmem_write = 1'b0;
            dmem_size = 2'b00;
            dmem_wdata = 32'h0;
            dmem_byte_en = 4'b0000;
        end
    end
    
    // Cache control (simplified)
    assign cache_enable = 1'b1;  // Always enable cache for now
    assign cache_flush = flush;
    
    // Output assignments
    assign load_data = aligned_load_data;
    assign pc_out = pc_reg;
    assign memory_valid = valid_reg;
    assign memory_complete = (mem_state == MEM_COMPLETE);
    assign transfer_complete = memory_complete;
    
    // Exception handling
    assign data_abort = (mem_state == MEM_ABORT) || dmem_abort;
    assign abort_address = effective_address;
    assign alignment_fault = alignment_error;
    
    // Block data transfer instantiation (commented out until typedef issues fixed)
    /*
    arm7tdmi_block_dt u_block_dt (
        .clk              (clk),
        .rst_n            (rst_n),
        .block_en         (block_dt_en),
        .block_load       (block_load),
        .block_pre        (block_pre),
        .block_up         (block_up),
        .block_writeback  (block_writeback),
        .block_user_mode  (block_user_mode),
        .register_list    (register_list),
        .base_register    (base_register),
        .base_address     (base_address),
        .mem_addr         (block_mem_addr),
        .mem_wdata        (block_mem_wdata),
        .mem_rdata        (dmem_rdata),
        .mem_we           (block_mem_we),
        .mem_re           (block_mem_re),
        .mem_ready        (dmem_ready),
        .reg_addr         (block_reg_addr),
        .reg_wdata        (block_reg_wdata),
        .reg_rdata        (reg_read_data),
        .reg_we           (block_reg_we),
        .base_reg_addr    (block_base_reg_addr),
        .base_reg_data    (block_base_reg_data),
        .base_reg_we      (block_base_reg_we),
        .block_complete   (block_dt_complete),
        .block_active     (block_dt_active)
    );
    */
    
    // Simplified block transfer signals for now
    assign block_mem_addr = base_address;
    assign block_mem_wdata = reg_read_data;
    assign block_mem_we = 1'b0;
    assign block_mem_re = 1'b0;
    assign block_reg_addr = 4'h0;
    assign block_reg_wdata = dmem_rdata;
    assign block_reg_we = 1'b0;
    assign block_base_reg_addr = base_register;
    assign block_base_reg_data = base_address;
    assign block_base_reg_we = 1'b0;
    assign block_dt_complete = 1'b1;
    assign block_dt_active = 1'b0;

endmodule