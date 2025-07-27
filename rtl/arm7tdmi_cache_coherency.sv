// ARM7TDMI Cache Coherency Controller
// Implements basic cache coherency between instruction and data caches
// Uses a simple invalidation-based protocol for self-modifying code scenarios

import arm7tdmi_pkg::*;

module arm7tdmi_cache_coherency #(
    parameter ADDR_WIDTH = 32,
    parameter ICACHE_LINE_SIZE = 32,    // 32 bytes per I-cache line
    parameter DCACHE_LINE_SIZE = 16     // 16 bytes per D-cache line  
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Data cache interface (snooping writes)
    input  logic [ADDR_WIDTH-1:0]  dcache_addr,
    input  logic                    dcache_write,
    input  logic                    dcache_req,
    input  logic                    dcache_ready,
    
    // Instruction cache coherency interface
    output logic [ADDR_WIDTH-1:0]  icache_invalidate_addr,
    output logic                    icache_invalidate_req,
    input  logic                    icache_invalidate_ack,
    
    // Coherency control
    input  logic                    coherency_enable,
    input  logic [ADDR_WIDTH-1:0]  code_region_base,    // Base address of code region
    input  logic [ADDR_WIDTH-1:0]  code_region_size,    // Size of code region
    
    // Statistics and debug
    output logic [31:0]             coherency_invalidations,
    output logic                    coherency_busy
);

    // Coherency state machine
    typedef enum logic [1:0] {
        COHERENCY_IDLE,
        COHERENCY_CHECK,
        COHERENCY_INVALIDATE,
        COHERENCY_WAIT_ACK
    } coherency_state_t;
    
    coherency_state_t state, next_state;
    
    // Working registers
    logic [ADDR_WIDTH-1:0]  pending_invalidate_addr;
    logic                   invalidate_needed;
    logic                   in_code_region;
    
    // Calculate cache line addresses for coherency checks
    logic [ADDR_WIDTH-1:0]  dcache_line_base;
    logic [ADDR_WIDTH-1:0]  icache_line_base;
    
    // D-cache line base address (aligned to D-cache line size)
    assign dcache_line_base = {dcache_addr[ADDR_WIDTH-1:$clog2(DCACHE_LINE_SIZE)], 
                              {$clog2(DCACHE_LINE_SIZE){1'b0}}};
    
    // I-cache line base address (aligned to I-cache line size)
    assign icache_line_base = {dcache_addr[ADDR_WIDTH-1:$clog2(ICACHE_LINE_SIZE)], 
                              {$clog2(ICACHE_LINE_SIZE){1'b0}}};
    
    // Check if write address is in code region
    always_comb begin
        in_code_region = coherency_enable && 
                        (dcache_addr >= code_region_base) && 
                        (dcache_addr < (code_region_base + code_region_size));
    end
    
    // Determine if invalidation is needed
    always_comb begin
        invalidate_needed = dcache_write && dcache_req && in_code_region;
    end
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= COHERENCY_IDLE;
            pending_invalidate_addr <= '0;
            coherency_invalidations <= '0;
        end else begin
            state <= next_state;
            
            case (state)
                COHERENCY_IDLE: begin
                    if (invalidate_needed) begin
                        pending_invalidate_addr <= icache_line_base;
                    end
                end
                
                COHERENCY_CHECK: begin
                    // State for additional checks if needed
                end
                
                COHERENCY_INVALIDATE: begin
                    // Invalidation request is being sent
                end
                
                COHERENCY_WAIT_ACK: begin
                    if (icache_invalidate_ack) begin
                        coherency_invalidations <= coherency_invalidations + 1;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            COHERENCY_IDLE: begin
                if (invalidate_needed) begin
                    next_state = COHERENCY_CHECK;
                end
            end
            
            COHERENCY_CHECK: begin
                // Could add additional coherency checks here
                next_state = COHERENCY_INVALIDATE;
            end
            
            COHERENCY_INVALIDATE: begin
                next_state = COHERENCY_WAIT_ACK;
            end
            
            COHERENCY_WAIT_ACK: begin
                if (icache_invalidate_ack) begin
                    next_state = COHERENCY_IDLE;
                end
            end
        endcase
    end
    
    // Output control
    assign icache_invalidate_addr = pending_invalidate_addr;
    assign icache_invalidate_req = (state == COHERENCY_INVALIDATE);
    assign coherency_busy = (state != COHERENCY_IDLE);
    
    // Debug and verification
    `ifdef SIMULATION
    // Assertions for coherency protocol
    property invalidate_req_followed_by_ack;
        @(posedge clk) icache_invalidate_req |-> ##[1:10] icache_invalidate_ack;
    endproperty
    assert property (invalidate_req_followed_by_ack);
    
    property no_spurious_invalidations;
        @(posedge clk) icache_invalidate_req |-> coherency_enable;
    endproperty
    assert property (no_spurious_invalidations);
    
    // Coverage for coherency scenarios
    covergroup coherency_scenarios @(posedge clk);
        write_to_code: coverpoint (dcache_write && in_code_region) {
            bins write_in_code = {1};
        }
        invalidation_sent: coverpoint icache_invalidate_req {
            bins invalidation = {1};
        }
        cross write_to_code, invalidation_sent;
    endgroup
    
    coherency_scenarios cov_coherency = new();
    `endif

endmodule