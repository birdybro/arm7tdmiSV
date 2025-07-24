import arm7tdmi_pkg::*;

module arm7tdmi_block_dt (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  logic        block_en,
    input  logic        block_load,        // 1=LDM, 0=STM
    input  logic        block_pre,         // Pre/post increment
    input  logic        block_up,          // Up/down
    input  logic        block_writeback,   // Write back final address
    input  logic        block_user_mode,   // Use user mode registers
    
    // Register list and base register
    input  logic [15:0] register_list,
    input  logic [3:0]  base_register,
    input  logic [31:0] base_address,
    
    // Memory interface
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    output logic        mem_we,
    output logic        mem_re,
    input  logic        mem_ready,
    
    // Register file interface
    output logic [3:0]  reg_addr,
    output logic [31:0] reg_wdata,
    input  logic [31:0] reg_rdata,
    output logic        reg_we,
    
    // Base register writeback
    output logic [3:0]  base_reg_addr,
    output logic [31:0] base_reg_data,
    output logic        base_reg_we,
    
    // Status
    output logic        block_complete,
    output logic        block_active
);

    // State machine for block transfer
    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        TRANSFER,
        WRITEBACK,
        COMPLETE
    } block_state_t;
    
    block_state_t state, next_state;
    
    // Internal registers
    logic [15:0] remaining_regs;
    logic [3:0]  current_reg;
    logic [31:0] current_addr;
    logic [4:0]  reg_count;
    logic        first_transfer;
    
    // Register scanning logic
    logic [3:0] next_reg;
    always_comb begin
        next_reg = 4'd0;
        for (int i = 0; i < 16; i++) begin
            if (remaining_regs[i] && next_reg == 4'd0) begin
                next_reg = i[3:0];
            end
        end
    end
    
    // Count registers in list
    logic [4:0] total_regs;
    always_comb begin
        total_regs = 5'd0;
        for (int i = 0; i < 16; i++) begin
            if (register_list[i]) begin
                total_regs = total_regs + 1;
            end
        end
    end
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            remaining_regs <= 16'b0;
            current_reg <= 4'd0;
            current_addr <= 32'b0;
            reg_count <= 5'd0;
            first_transfer <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (block_en) begin
                        remaining_regs <= register_list;
                        current_reg <= next_reg;
                        reg_count <= total_regs;
                        first_transfer <= 1'b1;
                        
                        // Calculate starting address
                        if (block_up) begin
                            if (block_pre) begin
                                current_addr <= base_address + 32'd4;
                            end else begin
                                current_addr <= base_address;
                            end
                        end else begin
                            if (block_pre) begin
                                current_addr <= base_address - (total_regs << 2);
                            end else begin
                                current_addr <= base_address - (total_regs << 2) + 32'd4;
                            end
                        end
                    end
                end
                
                SETUP: begin
                    current_reg <= next_reg;
                    first_transfer <= 1'b0;
                end
                
                TRANSFER: begin
                    if (mem_ready) begin
                        remaining_regs[current_reg] <= 1'b0;
                        reg_count <= reg_count - 1;
                        
                        // Address increment
                        if (block_up) begin
                            current_addr <= current_addr + 32'd4;
                        end else begin
                            current_addr <= current_addr - 32'd4;
                        end
                    end
                end
                
                WRITEBACK: begin
                    // Stay in writeback for one cycle
                end
                
                COMPLETE: begin
                    // Stay in complete until block_en goes low
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (block_en && register_list != 16'b0) begin
                    next_state = SETUP;
                end
            end
            
            SETUP: begin
                next_state = TRANSFER;
            end
            
            TRANSFER: begin
                if (mem_ready) begin
                    if (reg_count == 5'd1) begin
                        if (block_writeback) begin
                            next_state = WRITEBACK;
                        end else begin
                            next_state = COMPLETE;
                        end
                    end else begin
                        next_state = SETUP;
                    end
                end
            end
            
            WRITEBACK: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                if (!block_en) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    // Memory interface
    assign mem_addr = current_addr;
    assign mem_we = (state == TRANSFER) && !block_load;
    assign mem_re = (state == TRANSFER) && block_load;
    assign mem_wdata = reg_rdata;
    
    // Register file interface
    assign reg_addr = current_reg;
    assign reg_wdata = mem_rdata;
    assign reg_we = (state == TRANSFER) && block_load && mem_ready;
    
    // Base register writeback
    assign base_reg_addr = base_register;
    assign base_reg_we = (state == WRITEBACK);
    
    always_comb begin
        if (block_up) begin
            if (block_pre) begin
                base_reg_data = base_address + (total_regs << 2);
            end else begin
                base_reg_data = base_address + (total_regs << 2);
            end
        end else begin
            if (block_pre) begin
                base_reg_data = base_address - (total_regs << 2);
            end else begin
                base_reg_data = base_address - (total_regs << 2);
            end
        end
    end
    
    // Status outputs
    assign block_active = (state != IDLE);
    assign block_complete = (state == COMPLETE);

endmodule