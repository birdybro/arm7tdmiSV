import arm7tdmi_pkg::*;

module arm7tdmi_regfile (
    input  logic        clk,
    input  logic        rst_n,
    
    // Read ports
    input  logic [3:0]  rn_addr,
    input  logic [3:0]  rm_addr,
    output logic [31:0] rn_data,
    output logic [31:0] rm_data,
    
    // Write port
    input  logic [3:0]  rd_addr,
    input  logic [31:0] rd_data,
    input  logic        rd_we,
    
    // PC access
    output logic [31:0] pc_out,
    input  logic [31:0] pc_in,
    input  logic        pc_we,
    
    // Mode control
    input  processor_mode_t current_mode,
    input  processor_mode_t target_mode,
    input  logic            mode_change,
    
    // CPSR/SPSR access
    output logic [31:0] cpsr_out,
    input  logic [31:0] cpsr_in,
    input  logic        cpsr_we,
    output logic [31:0] spsr_out,
    input  logic [31:0] spsr_in,
    input  logic        spsr_we
);

    // Main register banks
    logic [31:0] regs_user [0:15];      // User mode registers (R0-R15)
    logic [31:0] regs_fiq [8:14];       // FIQ mode registers (R8-R14)
    logic [31:0] regs_irq [13:14];      // IRQ mode registers (R13-R14)
    logic [31:0] regs_svc [13:14];      // Supervisor mode registers (R13-R14)
    logic [31:0] regs_abt [13:14];      // Abort mode registers (R13-R14)
    logic [31:0] regs_und [13:14];      // Undefined mode registers (R13-R14)
    
    // Status registers
    logic [31:0] cpsr;                  // Current Program Status Register
    logic [31:0] spsr_fiq;              // Saved PSR for FIQ mode
    logic [31:0] spsr_irq;              // Saved PSR for IRQ mode
    logic [31:0] spsr_svc;              // Saved PSR for Supervisor mode
    logic [31:0] spsr_abt;              // Saved PSR for Abort mode
    logic [31:0] spsr_und;              // Saved PSR for Undefined mode
    
    // Internal signals
    logic [31:0] rn_data_internal, rm_data_internal;
    logic [31:0] current_spsr;
    
    // Initialize registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize user mode registers
            for (int i = 0; i < 16; i++) begin
                regs_user[i] <= 32'b0;
            end
            
            // Initialize banked registers
            for (int i = 8; i < 15; i++) begin
                regs_fiq[i] <= 32'b0;
            end
            for (int i = 13; i < 15; i++) begin
                regs_irq[i] <= 32'b0;
                regs_svc[i] <= 32'b0;
                regs_abt[i] <= 32'b0;
                regs_und[i] <= 32'b0;
            end
            
            // Initialize status registers
            cpsr <= {27'b0, MODE_SUPERVISOR};
            spsr_fiq <= 32'b0;
            spsr_irq <= 32'b0;
            spsr_svc <= 32'b0;
            spsr_abt <= 32'b0;
            spsr_und <= 32'b0;
        end
    end
    
    // Read port logic
    always_comb begin
        // Default to user mode registers
        rn_data_internal = regs_user[rn_addr];
        rm_data_internal = regs_user[rm_addr];
        
        // Handle banked registers based on current mode
        case (current_mode)
            MODE_FIQ: begin
                if (rn_addr >= 8 && rn_addr <= 14) begin
                    rn_data_internal = regs_fiq[rn_addr];
                end
                if (rm_addr >= 8 && rm_addr <= 14) begin
                    rm_data_internal = regs_fiq[rm_addr];
                end
            end
            
            MODE_IRQ: begin
                if (rn_addr == 13 || rn_addr == 14) begin
                    rn_data_internal = regs_irq[rn_addr];
                end
                if (rm_addr == 13 || rm_addr == 14) begin
                    rm_data_internal = regs_irq[rm_addr];
                end
            end
            
            MODE_SUPERVISOR: begin
                if (rn_addr == 13 || rn_addr == 14) begin
                    rn_data_internal = regs_svc[rn_addr];
                end
                if (rm_addr == 13 || rm_addr == 14) begin
                    rm_data_internal = regs_svc[rm_addr];
                end
            end
            
            MODE_ABORT: begin
                if (rn_addr == 13 || rn_addr == 14) begin
                    rn_data_internal = regs_abt[rn_addr];
                end
                if (rm_addr == 13 || rm_addr == 14) begin
                    rm_data_internal = regs_abt[rm_addr];
                end
            end
            
            MODE_UNDEFINED: begin
                if (rn_addr == 13 || rn_addr == 14) begin
                    rn_data_internal = regs_und[rn_addr];
                end
                if (rm_addr == 13 || rm_addr == 14) begin
                    rm_data_internal = regs_und[rm_addr];
                end
            end
            
            default: begin
                // USER and SYSTEM modes use the same registers
            end
        endcase
    end
    
    // Write port logic
    always_ff @(posedge clk) begin
        if (rd_we && rd_addr != 15) begin  // Don't write to PC through normal write port
            case (current_mode)
                MODE_FIQ: begin
                    if (rd_addr >= 8 && rd_addr <= 14) begin
                        regs_fiq[rd_addr] <= rd_data;
                    end else begin
                        regs_user[rd_addr] <= rd_data;
                    end
                end
                
                MODE_IRQ: begin
                    if (rd_addr == 13 || rd_addr == 14) begin
                        regs_irq[rd_addr] <= rd_data;
                    end else begin
                        regs_user[rd_addr] <= rd_data;
                    end
                end
                
                MODE_SUPERVISOR: begin
                    if (rd_addr == 13 || rd_addr == 14) begin
                        regs_svc[rd_addr] <= rd_data;
                    end else begin
                        regs_user[rd_addr] <= rd_data;
                    end
                end
                
                MODE_ABORT: begin
                    if (rd_addr == 13 || rd_addr == 14) begin
                        regs_abt[rd_addr] <= rd_data;
                    end else begin
                        regs_user[rd_addr] <= rd_data;
                    end
                end
                
                MODE_UNDEFINED: begin
                    if (rd_addr == 13 || rd_addr == 14) begin
                        regs_und[rd_addr] <= rd_data;
                    end else begin
                        regs_user[rd_addr] <= rd_data;
                    end
                end
                
                default: begin
                    regs_user[rd_addr] <= rd_data;
                end
            endcase
        end
        
        // PC write port
        if (pc_we) begin
            regs_user[15] <= pc_in;
        end
        
        // CPSR write
        if (cpsr_we) begin
            cpsr <= cpsr_in;
        end
        
        // SPSR write
        if (spsr_we) begin
            case (current_mode)
                MODE_FIQ:       spsr_fiq <= spsr_in;
                MODE_IRQ:       spsr_irq <= spsr_in;
                MODE_SUPERVISOR: spsr_svc <= spsr_in;
                MODE_ABORT:     spsr_abt <= spsr_in;
                MODE_UNDEFINED: spsr_und <= spsr_in;
                default: begin
                    // User and System modes don't have SPSR
                end
            endcase
        end
    end
    
    // SPSR read logic
    always_comb begin
        case (current_mode)
            MODE_FIQ:       current_spsr = spsr_fiq;
            MODE_IRQ:       current_spsr = spsr_irq;
            MODE_SUPERVISOR: current_spsr = spsr_svc;
            MODE_ABORT:     current_spsr = spsr_abt;
            MODE_UNDEFINED: current_spsr = spsr_und;
            default:        current_spsr = 32'b0;
        endcase
    end
    
    // Output assignments
    assign rn_data = rn_data_internal;
    assign rm_data = rm_data_internal;
    assign pc_out = regs_user[15];
    assign cpsr_out = cpsr;
    assign spsr_out = current_spsr;
    
endmodule