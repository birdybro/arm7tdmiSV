// ARM7TDMI Simple Data Cache
// Simplified design compatible with Icarus Verilog
// Direct-mapped cache with basic functionality

import arm7tdmi_pkg::*;

module arm7tdmi_dcache_simple #(
    parameter CACHE_SIZE_BYTES = 1024,      // 1KB cache for simplicity
    parameter CACHE_LINE_SIZE = 16,         // 16-byte cache lines (4 words)
    parameter ADDR_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // CPU interface
    input  logic [ADDR_WIDTH-1:0]  cpu_addr,           // Data address from CPU
    input  logic                    cpu_req,            // Request valid
    input  logic                    cpu_write,          // Write request
    input  logic [1:0]              cpu_size,           // Transfer size (00=byte, 01=halfword, 10=word)
    input  logic [31:0]             cpu_wdata,          // Write data
    input  logic [3:0]              cpu_byte_en,        // Byte enables for partial writes
    output logic [31:0]             cpu_rdata,          // Read data
    output logic                    cpu_hit,            // Cache hit indication
    output logic                    cpu_ready,          // Request complete
    
    // Memory interface
    output logic [ADDR_WIDTH-1:0]  mem_addr,           // Memory address
    output logic                    mem_req,            // Memory request
    output logic                    mem_write,          // Memory write
    output logic [31:0]             mem_wdata,          // Memory write data
    output logic [3:0]              mem_byte_en,        // Memory byte enables
    input  logic [31:0]             mem_rdata,          // Memory read data
    input  logic                    mem_ready,          // Memory ready
    
    // Cache control
    input  logic                    cache_enable,       // Cache enable
    input  logic                    cache_flush,        // Flush entire cache
    
    // Coherency interface (output to coherency controller)
    output logic [ADDR_WIDTH-1:0]  coherency_addr,     // Address for coherency check
    output logic                    coherency_write,    // Write operation indicator
    output logic                    coherency_req,      // Coherency request
    output logic                    coherency_ready,    // Coherency ready
    
    // Statistics
    output logic [31:0]             cache_hits,         // Cache hit counter
    output logic [31:0]             cache_misses,       // Cache miss counter
    output logic                    cache_busy          // Cache busy indication
);

    // Cache organization
    localparam CACHE_LINES = CACHE_SIZE_BYTES / CACHE_LINE_SIZE;
    localparam WORDS_PER_LINE = CACHE_LINE_SIZE / 4;
    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_LINES);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    
    // Address breakdown
    logic [TAG_BITS-1:0]        addr_tag;
    logic [INDEX_BITS-1:0]      addr_index;
    logic [OFFSET_BITS-1:0]     addr_offset;
    logic [WORD_OFFSET_BITS-1:0] word_offset;
    logic [1:0]                 byte_offset;
    
    assign addr_tag = cpu_addr[ADDR_WIDTH-1:INDEX_BITS+OFFSET_BITS];
    assign addr_index = cpu_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
    assign addr_offset = cpu_addr[OFFSET_BITS-1:0];
    assign word_offset = addr_offset[OFFSET_BITS-1:2];
    assign byte_offset = addr_offset[1:0];
    
    // Write-back cache storage - avoid complex structs
    logic [CACHE_LINES-1:0]                 cache_valid;
    logic [CACHE_LINES-1:0]                 cache_dirty;     // Dirty bits for write-back policy
    logic [CACHE_LINES-1:0][TAG_BITS-1:0]   cache_tags;
    logic [CACHE_LINES-1:0][31:0]           cache_data_word0;
    logic [CACHE_LINES-1:0][31:0]           cache_data_word1;
    logic [CACHE_LINES-1:0][31:0]           cache_data_word2;
    logic [CACHE_LINES-1:0][31:0]           cache_data_word3;
    
    // Write-back cache state machine
    typedef enum logic [2:0] {
        CACHE_IDLE,
        CACHE_LOOKUP,
        CACHE_WRITEBACK,    // New state for write-back operations
        CACHE_FILL,
        CACHE_COMPLETE
    } cache_state_t;
    
    cache_state_t state, next_state;
    
    // Working registers - enhanced for write-back cache
    logic [TAG_BITS-1:0]        miss_tag;
    logic [INDEX_BITS-1:0]      miss_index;
    logic [WORD_OFFSET_BITS-1:0] miss_word_offset;
    logic                       cache_hit_internal;
    logic [1:0]                 fill_counter;
    logic [1:0]                 writeback_counter;   // Counter for write-back operations
    logic [31:0]                selected_word;
    logic [31:0]                write_data_masked;
    logic [TAG_BITS-1:0]        writeback_tag;       // Tag for write-back operation
    logic [INDEX_BITS-1:0]      writeback_index;     // Index for write-back operation
    
    // Hit detection
    assign cache_hit_internal = cache_valid[addr_index] && 
                                (cache_tags[addr_index] == addr_tag);
    
    // Word selection from cache line
    always_comb begin
        case (word_offset)
            2'b00: selected_word = cache_data_word0[addr_index];
            2'b01: selected_word = cache_data_word1[addr_index];
            2'b10: selected_word = cache_data_word2[addr_index];
            2'b11: selected_word = cache_data_word3[addr_index];
        endcase
    end
    
    // Write data masking based on size and byte enables
    always_comb begin
        write_data_masked = selected_word;  // Start with existing data
        
        case (cpu_size)
            2'b00: begin // Byte
                case (byte_offset)
                    2'b00: if (cpu_byte_en[0]) write_data_masked = {selected_word[31:8], cpu_wdata[7:0]};
                    2'b01: if (cpu_byte_en[0]) write_data_masked = {selected_word[31:16], cpu_wdata[7:0], selected_word[7:0]};
                    2'b10: if (cpu_byte_en[0]) write_data_masked = {selected_word[31:24], cpu_wdata[7:0], selected_word[15:0]};
                    2'b11: if (cpu_byte_en[0]) write_data_masked = {cpu_wdata[7:0], selected_word[23:0]};
                endcase
            end
            2'b01: begin // Halfword
                if (byte_offset[0] == 1'b0) begin
                    if (cpu_byte_en[1:0] != 2'b00) write_data_masked = {selected_word[31:16], cpu_wdata[15:0]};
                end else begin
                    if (cpu_byte_en[1:0] != 2'b00) write_data_masked = {cpu_wdata[15:0], selected_word[15:0]};
                end
            end
            2'b10: begin // Word
                write_data_masked = selected_word;
                if (cpu_byte_en[0]) write_data_masked = {write_data_masked[31:8], cpu_wdata[7:0]};
                if (cpu_byte_en[1]) write_data_masked = {write_data_masked[31:16], cpu_wdata[15:8], write_data_masked[7:0]};
                if (cpu_byte_en[2]) write_data_masked = {write_data_masked[31:24], cpu_wdata[23:16], write_data_masked[15:0]};
                if (cpu_byte_en[3]) write_data_masked = {cpu_wdata[31:24], write_data_masked[23:0]};
            end
        endcase
    end
    
    // Output data alignment moved to cpu_rdata assignment block
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= CACHE_IDLE;
            cache_hits <= '0;
            cache_misses <= '0;
            fill_counter <= '0;
            writeback_counter <= '0;
            cache_valid <= '0;
            cache_dirty <= '0;              // Initialize dirty bits
            cache_tags <= '0;
            cache_data_word0 <= '0;
            cache_data_word1 <= '0;
            cache_data_word2 <= '0;
            cache_data_word3 <= '0;
        end else begin
            state <= next_state;
            
            case (state)
                CACHE_LOOKUP: begin
                    if (cache_hit_internal) begin
                        cache_hits <= cache_hits + 1;
                        
                        // Handle cache write hit - write-back policy
                        if (cpu_write) begin
                            case (word_offset)
                                2'b00: cache_data_word0[addr_index] <= write_data_masked;
                                2'b01: cache_data_word1[addr_index] <= write_data_masked;
                                2'b10: cache_data_word2[addr_index] <= write_data_masked;
                                2'b11: cache_data_word3[addr_index] <= write_data_masked;
                            endcase
                            cache_dirty[addr_index] <= 1'b1;  // Mark cache line as dirty
                        end
                    end else begin
                        cache_misses <= cache_misses + 1;
                        miss_tag <= addr_tag;
                        miss_index <= addr_index;
                        miss_word_offset <= word_offset;
                        fill_counter <= 2'b00;
                        
                        // Check if current cache line is dirty and needs write-back
                        if (cache_valid[addr_index] && cache_dirty[addr_index]) begin
                            writeback_tag <= cache_tags[addr_index];
                            writeback_index <= addr_index;
                            writeback_counter <= 2'b00;
                        end
                    end
                end
                
                CACHE_WRITEBACK: begin
                    if (mem_ready) begin
                        if (writeback_counter == WORDS_PER_LINE - 1) begin
                            // Write-back complete, clear dirty bit
                            cache_dirty[writeback_index] <= 1'b0;
                            writeback_counter <= 2'b00;
                        end else begin
                            writeback_counter <= writeback_counter + 1;
                        end
                    end
                end
                
                CACHE_FILL: begin
                    if (mem_ready) begin
                        case (fill_counter)
                            2'b00: cache_data_word0[miss_index] <= mem_rdata;
                            2'b01: cache_data_word1[miss_index] <= mem_rdata;
                            2'b10: cache_data_word2[miss_index] <= mem_rdata;
                            2'b11: cache_data_word3[miss_index] <= mem_rdata;
                        endcase
                        
                        if (fill_counter == WORDS_PER_LINE - 1) begin
                            // Last word - complete the cache line fill
                            cache_valid[miss_index] <= 1'b1;
                            cache_tags[miss_index] <= miss_tag;
                            fill_counter <= 2'b00; // Reset for next time
                            
                            // Handle write allocation - write-back policy
                            if (cpu_write) begin
                                case (miss_word_offset)
                                    2'b00: cache_data_word0[miss_index] <= write_data_masked;
                                    2'b01: cache_data_word1[miss_index] <= write_data_masked;
                                    2'b10: cache_data_word2[miss_index] <= write_data_masked;
                                    2'b11: cache_data_word3[miss_index] <= write_data_masked;
                                endcase
                                cache_dirty[miss_index] <= 1'b1; // Mark as dirty if written
                            end else begin
                                cache_dirty[miss_index] <= 1'b0; // Clean line for read-only fills
                            end
                        end else begin
                            // Continue filling
                            fill_counter <= fill_counter + 1;
                        end
                    end
                end
            endcase
            
            // Handle cache flush - invalidate all lines (note: real implementation should write-back dirty lines)
            if (cache_flush) begin
                cache_valid <= '0;
                cache_dirty <= '0;  // Clear dirty bits on flush (simplified for now)
            end
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            CACHE_IDLE: begin
                if (cpu_req && cache_enable) begin
                    next_state = CACHE_LOOKUP;
                end
            end
            
            CACHE_LOOKUP: begin
                if (cache_hit_internal) begin
                    next_state = CACHE_COMPLETE;
                end else begin
                    // Check if we need to write-back dirty line before filling
                    if (cache_valid[addr_index] && cache_dirty[addr_index]) begin
                        next_state = CACHE_WRITEBACK;
                    end else begin
                        next_state = CACHE_FILL;
                    end
                end
            end
            
            CACHE_WRITEBACK: begin
                if (mem_ready && writeback_counter == WORDS_PER_LINE - 1) begin
                    next_state = CACHE_FILL; // After write-back, proceed to fill
                end
                // Stay in CACHE_WRITEBACK state to continue write-back
            end
            
            CACHE_FILL: begin
                if (mem_ready) begin
                    if (fill_counter == WORDS_PER_LINE - 1) begin
                        next_state = CACHE_COMPLETE;
                    end
                    // Stay in CACHE_FILL state to continue filling
                end
            end
            
            CACHE_COMPLETE: begin
                next_state = CACHE_IDLE;
            end
        endcase
        
        // Handle flush during operation
        if (cache_flush) begin
            next_state = CACHE_IDLE;
        end
    end
    
    // Memory interface control
    always_comb begin
        mem_req = 1'b0;
        mem_write = 1'b0;
        mem_addr = cpu_addr;
        mem_wdata = cpu_wdata;
        mem_byte_en = cpu_byte_en;
        
        case (state)
            CACHE_WRITEBACK: begin
                mem_req = 1'b1;
                mem_write = 1'b1;
                // Write-back dirty cache line to memory
                mem_addr = {writeback_tag, writeback_index, {OFFSET_BITS{1'b0}}} + {writeback_counter, 2'b00};
                case (writeback_counter)
                    2'b00: mem_wdata = cache_data_word0[writeback_index];
                    2'b01: mem_wdata = cache_data_word1[writeback_index];
                    2'b10: mem_wdata = cache_data_word2[writeback_index];
                    2'b11: mem_wdata = cache_data_word3[writeback_index];
                endcase
                mem_byte_en = 4'b1111;
            end
            
            CACHE_FILL: begin
                mem_req = 1'b1;
                mem_write = 1'b0;
                // Fill cache line from memory
                mem_addr = {miss_tag, miss_index, {OFFSET_BITS{1'b0}}} + {fill_counter, 2'b00};
                mem_wdata = '0;
                mem_byte_en = 4'b1111;
            end
            
            default: begin
                if (!cache_enable && cpu_req) begin
                    // Pass-through when cache disabled
                    mem_req = cpu_req;
                    mem_write = cpu_write;
                    mem_addr = cpu_addr;
                    mem_wdata = cpu_wdata;
                    mem_byte_en = cpu_byte_en;
                end
            end
        endcase
    end
    
    // Output control
    assign cpu_hit = cache_hit_internal && (state == CACHE_LOOKUP);
    assign cpu_ready = (state == CACHE_COMPLETE) || 
                      (!cache_enable && mem_ready);
    assign cache_busy = (state != CACHE_IDLE) && (state != CACHE_COMPLETE);
    
    // Coherency interface
    assign coherency_addr = cpu_addr;
    assign coherency_write = cpu_write;
    assign coherency_req = cpu_req && cpu_write && cache_enable;
    assign coherency_ready = cpu_ready;
    
    // CPU read data output - fix missing assignment for cache-enabled case
    always_comb begin
        if (!cache_enable) begin
            cpu_rdata = mem_rdata;
        end else begin
            // Apply data alignment based on CPU request
            case (cpu_size)
                2'b00: begin // Byte
                    case (byte_offset)
                        2'b00: cpu_rdata = {24'h0, selected_word[7:0]};
                        2'b01: cpu_rdata = {24'h0, selected_word[15:8]};
                        2'b10: cpu_rdata = {24'h0, selected_word[23:16]};
                        2'b11: cpu_rdata = {24'h0, selected_word[31:24]};
                    endcase
                end
                2'b01: begin // Halfword
                    if (byte_offset[0] == 1'b0) begin
                        cpu_rdata = {16'h0, selected_word[15:0]};
                    end else begin
                        cpu_rdata = {16'h0, selected_word[31:16]};
                    end
                end
                2'b10: begin // Word
                    cpu_rdata = selected_word;
                end
                default: cpu_rdata = selected_word;
            endcase
        end
    end

endmodule