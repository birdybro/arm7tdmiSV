// ARM7TDMI Instruction Cache
// Implements a direct-mapped instruction cache with configurable size
// Supports both ARM (32-bit) and Thumb (16-bit) instruction modes

import arm7tdmi_pkg::*;

module arm7tdmi_icache #(
    parameter CACHE_SIZE_BYTES = 4096,    // 4KB cache
    parameter CACHE_LINE_SIZE = 32,       // 32 bytes per cache line (8 words)
    parameter ADDR_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // CPU interface
    input  logic [ADDR_WIDTH-1:0]  cpu_addr,
    input  logic                    cpu_req,
    input  logic                    cpu_thumb_mode,
    output logic [31:0]             cpu_data,
    output logic                    cpu_hit,
    output logic                    cpu_ready,
    
    // Memory interface
    output logic [ADDR_WIDTH-1:0]  mem_addr,
    output logic                    mem_req,
    output logic [2:0]              mem_burst_len,  // For burst reads
    input  logic [31:0]             mem_data,
    input  logic                    mem_valid,
    input  logic                    mem_ready,
    
    // Control interface
    input  logic                    cache_enable,
    input  logic                    cache_flush,
    input  logic                    cache_invalidate,
    
    // Coherency interface
    input  logic [ADDR_WIDTH-1:0]  coherency_invalidate_addr,
    input  logic                    coherency_invalidate_req,
    output logic                    coherency_invalidate_ack,
    
    // Debug/Status interface
    output logic [31:0]             cache_hits,
    output logic [31:0]             cache_misses,
    output logic                    cache_busy
);

    // Cache parameters
    localparam CACHE_LINES = CACHE_SIZE_BYTES / CACHE_LINE_SIZE;
    localparam INDEX_BITS = $clog2(CACHE_LINES);
    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE = CACHE_LINE_SIZE / 4;
    
    // Cache memory arrays
    logic [31:0]            cache_data [CACHE_LINES][WORDS_PER_LINE];
    logic [TAG_BITS-1:0]    cache_tags [CACHE_LINES];
    logic                   cache_valid [CACHE_LINES];
    
    // Address breakdown
    logic [TAG_BITS-1:0]    addr_tag;
    logic [INDEX_BITS-1:0]  addr_index;
    logic [OFFSET_BITS-1:0] addr_offset;
    logic [1:0]             word_select;
    
    assign addr_tag = cpu_addr[ADDR_WIDTH-1:ADDR_WIDTH-TAG_BITS];
    assign addr_index = cpu_addr[ADDR_WIDTH-TAG_BITS-1:OFFSET_BITS];
    assign addr_offset = cpu_addr[OFFSET_BITS-1:0];
    assign word_select = addr_offset[OFFSET_BITS-1:2];
    
    // Cache state machine
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        MISS_REQ,
        MISS_FILL,
        MISS_WAIT
    } cache_state_t;
    
    cache_state_t state, next_state;
    
    // Internal signals
    logic                    tag_match;
    logic                    cache_hit_internal;
    logic [2:0]              fill_counter;
    logic [INDEX_BITS-1:0]   fill_index;
    logic [TAG_BITS-1:0]     fill_tag;
    logic [31:0]             selected_word;
    
    // Coherency signals
    logic [TAG_BITS-1:0]     coherency_tag;
    logic [INDEX_BITS-1:0]   coherency_index;
    logic                    coherency_match;
    logic                    coherency_ack_reg;
    
    // Tag comparison
    assign tag_match = (cache_tags[addr_index] == addr_tag);
    assign cache_hit_internal = cache_enable && cache_valid[addr_index] && tag_match;
    
    // Coherency address breakdown
    assign coherency_tag = coherency_invalidate_addr[ADDR_WIDTH-1:ADDR_WIDTH-TAG_BITS];
    assign coherency_index = coherency_invalidate_addr[ADDR_WIDTH-TAG_BITS-1:OFFSET_BITS];
    assign coherency_match = cache_valid[coherency_index] && 
                            (cache_tags[coherency_index] == coherency_tag);
    
    // Word selection from cache line
    assign selected_word = cache_data[addr_index][word_select];
    
    // CPU data output - handle Thumb mode and cache disabled
    always_comb begin
        logic [31:0] output_word;
        
        if (!cache_enable) begin
            // When cache disabled, pass through memory data directly
            output_word = mem_data;
        end else begin
            // Use cached word
            output_word = selected_word;
        end
        
        if (cpu_thumb_mode) begin
            // For Thumb mode, select appropriate 16-bit halfword
            if (cpu_addr[1]) begin
                cpu_data = {16'h0000, output_word[31:16]};
            end else begin
                cpu_data = {16'h0000, output_word[15:0]};
            end
        end else begin
            // ARM mode - full 32-bit word
            cpu_data = output_word;
        end
    end
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fill_counter <= 3'b0;
            fill_index <= '0;
            fill_tag <= '0;
            cache_hits <= 32'b0;
            cache_misses <= 32'b0;
            coherency_ack_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (cpu_req && cache_enable) begin
                        fill_index <= addr_index;
                        fill_tag <= addr_tag;
                    end
                end
                
                LOOKUP: begin
                    if (cache_hit_internal && cpu_req) begin
                        cache_hits <= cache_hits + 1;
                    end else if (cpu_req && cache_enable) begin
                        cache_misses <= cache_misses + 1;
                        fill_counter <= 3'b0;
                    end
                end
                
                MISS_FILL: begin
                    if (mem_valid) begin
                        cache_data[fill_index][fill_counter] <= mem_data;
                        fill_counter <= fill_counter + 1;
                        
                        // Mark as valid when fill completes
                        if (fill_counter == WORDS_PER_LINE - 1) begin
                            cache_valid[fill_index] <= 1'b1;
                            cache_tags[fill_index] <= fill_tag;
                        end
                    end
                end
            endcase
            
            // Handle coherency invalidation requests
            coherency_ack_reg <= 1'b0;
            if (coherency_invalidate_req && coherency_match) begin
                cache_valid[coherency_index] <= 1'b0;
                coherency_ack_reg <= 1'b1;
            end else if (coherency_invalidate_req) begin
                // Acknowledge even if no match (line not cached)
                coherency_ack_reg <= 1'b1;
            end
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (cpu_req && cache_enable) begin
                    next_state = LOOKUP;
                end
            end
            
            LOOKUP: begin
                if (!cpu_req) begin
                    next_state = IDLE;
                end else if (cache_hit_internal) begin
                    next_state = IDLE;  // Hit - ready for next request
                end else if (cache_enable) begin
                    next_state = MISS_REQ;
                end else begin
                    next_state = IDLE;  // Cache disabled
                end
            end
            
            MISS_REQ: begin
                next_state = MISS_FILL;  // Start filling immediately
            end
            
            MISS_FILL: begin
                if (mem_valid && (fill_counter == WORDS_PER_LINE - 1)) begin
                    next_state = IDLE;
                end
            end
        endcase
        
        // Handle flush and invalidate
        if (cache_flush || cache_invalidate) begin
            next_state = IDLE;
        end
    end
    
    // Memory interface
    assign mem_addr = {fill_tag, fill_index, {OFFSET_BITS{1'b0}}};
    assign mem_req = (state == MISS_REQ);
    assign mem_burst_len = WORDS_PER_LINE - 1;  // Burst length for cache line fill
    
    // CPU interface
    assign cpu_hit = cache_hit_internal && (state == LOOKUP || state == IDLE);
    assign cpu_ready = (state == IDLE) || (cache_hit_internal && state == LOOKUP) || !cache_enable;
    assign cache_busy = (state == MISS_REQ) || (state == MISS_FILL);
    
    // Coherency interface
    assign coherency_invalidate_ack = coherency_ack_reg;
    
    // Cache maintenance operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CACHE_LINES; i++) begin
                cache_valid[i] <= 1'b0;
                cache_tags[i] <= '0;
            end
        end else if (cache_flush || cache_invalidate) begin
            for (int i = 0; i < CACHE_LINES; i++) begin
                cache_valid[i] <= 1'b0;
            end
        end
    end
    
    // Debug and verification
    `ifdef SIMULATION
    // Coverage and debug signals
    logic [31:0] debug_total_accesses;
    real debug_hit_rate;
    
    assign debug_total_accesses = cache_hits + cache_misses;
    assign debug_hit_rate = (debug_total_accesses > 0) ? 
                           (real'(cache_hits) / real'(debug_total_accesses)) * 100.0 : 0.0;
    
    // Assertions
    property cache_hit_valid;
        @(posedge clk) cpu_hit |-> cache_valid[addr_index];
    endproperty
    assert property (cache_hit_valid);
    
    property cache_ready_when_hit;
        @(posedge clk) cpu_hit |-> cpu_ready;
    endproperty
    assert property (cache_ready_when_hit);
    `endif

endmodule