// ARM7TDMI Enhanced Data Cache with Multiple Replacement Policies
// Supports LRU, LFU, Random, and Round-Robin replacement policies
// Direct-mapped and N-way set associative configurations

import arm7tdmi_pkg::*;

module arm7tdmi_dcache_enhanced #(
    parameter CACHE_SIZE_BYTES = 1024,      // 1KB cache for simplicity
    parameter CACHE_LINE_SIZE = 16,         // 16-byte cache lines (4 words)
    parameter CACHE_WAYS = 2,               // Number of ways (1=direct-mapped, 2+=set-associative)
    parameter ADDR_WIDTH = 32,
    parameter REPLACEMENT_POLICY = "LRU"    // "LRU", "LFU", "RANDOM", "ROUND_ROBIN"
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
    
    // Replacement policy control
    input  logic [1:0]              replacement_select, // 00=LRU, 01=LFU, 10=RANDOM, 11=ROUND_ROBIN
    
    // Statistics
    output logic [31:0]             cache_hits,         // Cache hit counter
    output logic [31:0]             cache_misses,       // Cache miss counter
    output logic [31:0]             cache_evictions,    // Cache eviction counter
    output logic [31:0]             lru_replacements,   // LRU replacement counter
    output logic [31:0]             lfu_replacements,   // LFU replacement counter
    output logic [31:0]             random_replacements,// Random replacement counter
    output logic [31:0]             rr_replacements,    // Round-robin replacement counter
    output logic                    cache_busy          // Cache busy indication
);

    // Cache organization
    localparam CACHE_SETS = CACHE_SIZE_BYTES / (CACHE_LINE_SIZE * CACHE_WAYS);
    localparam WORDS_PER_LINE = CACHE_LINE_SIZE / 4;
    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SETS);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    localparam WAY_BITS = $clog2(CACHE_WAYS);
    
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
    
    // Cache storage arrays
    logic                           cache_valid     [CACHE_SETS][CACHE_WAYS];
    logic                           cache_dirty     [CACHE_SETS][CACHE_WAYS];
    logic [TAG_BITS-1:0]           cache_tags      [CACHE_SETS][CACHE_WAYS];
    logic [31:0]                   cache_data_word0[CACHE_SETS][CACHE_WAYS];
    logic [31:0]                   cache_data_word1[CACHE_SETS][CACHE_WAYS];
    logic [31:0]                   cache_data_word2[CACHE_SETS][CACHE_WAYS];
    logic [31:0]                   cache_data_word3[CACHE_SETS][CACHE_WAYS];
    
    // Replacement policy tracking
    logic [WAY_BITS-1:0]           lru_order       [CACHE_SETS][CACHE_WAYS];  // LRU order (0=most recent)
    logic [7:0]                    access_count    [CACHE_SETS][CACHE_WAYS];  // LFU access counter
    logic [WAY_BITS-1:0]           rr_next_way     [CACHE_SETS];              // Round-robin next way
    logic [15:0]                   lfsr;                                       // LFSR for random replacement
    
    // Cache state machine
    typedef enum logic [2:0] {
        CACHE_IDLE,
        CACHE_LOOKUP,
        CACHE_WRITEBACK,
        CACHE_FILL,
        CACHE_COMPLETE
    } cache_state_t;
    
    cache_state_t state, next_state;
    
    // Working registers
    logic [TAG_BITS-1:0]        miss_tag;
    logic [INDEX_BITS-1:0]      miss_index;
    logic [WORD_OFFSET_BITS-1:0] miss_word_offset;
    logic                       cache_hit_internal;
    logic [WAY_BITS-1:0]        hit_way;
    logic [WAY_BITS-1:0]        replace_way;
    logic [1:0]                 fill_counter;
    logic [1:0]                 writeback_counter;
    logic [31:0]                selected_word;
    logic [31:0]                write_data_masked;
    logic [TAG_BITS-1:0]        writeback_tag;
    logic [INDEX_BITS-1:0]      writeback_index;
    logic [WAY_BITS-1:0]        writeback_way;
    
    // Hit detection
    always_comb begin
        cache_hit_internal = 1'b0;
        hit_way = '0;
        
        for (int i = 0; i < CACHE_WAYS; i++) begin
            if (cache_valid[addr_index][i] && 
                (cache_tags[addr_index][i] == addr_tag)) begin
                cache_hit_internal = 1'b1;
                hit_way = i;
                // Note: Icarus doesn't support break in combinational loops
            end
        end
    end
    
    // Word selection from cache line
    always_comb begin
        case (word_offset)
            2'b00: selected_word = cache_data_word0[addr_index][hit_way];
            2'b01: selected_word = cache_data_word1[addr_index][hit_way];
            2'b10: selected_word = cache_data_word2[addr_index][hit_way];
            2'b11: selected_word = cache_data_word3[addr_index][hit_way];
        endcase
    end
    
    // Replacement policy selection
    always_comb begin
        case (replacement_select)
            2'b00: replace_way = get_lru_way(addr_index);      // LRU
            2'b01: replace_way = get_lfu_way(addr_index);      // LFU  
            2'b10: replace_way = get_random_way();             // Random
            2'b11: replace_way = rr_next_way[addr_index];      // Round-robin
        endcase
    end
    
    // LRU replacement policy function
    function logic [WAY_BITS-1:0] get_lru_way(logic [INDEX_BITS-1:0] set_index);
        logic [WAY_BITS-1:0] lru_way = 0;
        logic [WAY_BITS-1:0] max_order = 0;
        
        for (int i = 0; i < CACHE_WAYS; i++) begin
            if (!cache_valid[set_index][i]) begin
                return i; // Return first invalid way
            end
            if (lru_order[set_index][i] > max_order) begin
                max_order = lru_order[set_index][i];
                lru_way = i;
            end
        end
        return lru_way;
    endfunction
    
    // LFU replacement policy function
    function logic [WAY_BITS-1:0] get_lfu_way(logic [INDEX_BITS-1:0] set_index);
        logic [WAY_BITS-1:0] lfu_way = 0;
        logic [7:0] min_count = 8'hFF;
        
        for (int i = 0; i < CACHE_WAYS; i++) begin
            if (!cache_valid[set_index][i]) begin
                return i; // Return first invalid way
            end
            if (access_count[set_index][i] < min_count) begin
                min_count = access_count[set_index][i];
                lfu_way = i;
            end
        end
        return lfu_way;
    endfunction
    
    // Random replacement policy function
    function logic [WAY_BITS-1:0] get_random_way();
        if (CACHE_WAYS == 1) return 0;
        else if (CACHE_WAYS == 2) return lfsr[0];
        else return lfsr[WAY_BITS-1:0] % CACHE_WAYS;
    endfunction
    
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
    
    // LFSR for random replacement
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1; // Non-zero seed
        end else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= CACHE_IDLE;
            cache_hits <= '0;
            cache_misses <= '0;
            cache_evictions <= '0;
            lru_replacements <= '0;
            lfu_replacements <= '0;
            random_replacements <= '0;
            rr_replacements <= '0;
            fill_counter <= '0;
            writeback_counter <= '0;
            
            // Initialize cache arrays
            for (int i = 0; i < CACHE_SETS; i++) begin
                rr_next_way[i] <= '0;
                for (int j = 0; j < CACHE_WAYS; j++) begin
                    cache_valid[i][j] <= 1'b0;
                    cache_dirty[i][j] <= 1'b0;
                    cache_tags[i][j] <= '0;
                    cache_data_word0[i][j] <= '0;
                    cache_data_word1[i][j] <= '0;
                    cache_data_word2[i][j] <= '0;
                    cache_data_word3[i][j] <= '0;
                    lru_order[i][j] <= j;
                    access_count[i][j] <= '0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                CACHE_LOOKUP: begin
                    if (cache_hit_internal) begin
                        cache_hits <= cache_hits + 1;
                        
                        // Update replacement policy tracking
                        update_lru(addr_index, hit_way);
                        access_count[addr_index][hit_way] <= access_count[addr_index][hit_way] + 1;
                        
                        // Handle cache write hit - write-back policy
                        if (cpu_write) begin
                            case (word_offset)
                                2'b00: cache_data_word0[addr_index][hit_way] <= write_data_masked;
                                2'b01: cache_data_word1[addr_index][hit_way] <= write_data_masked;
                                2'b10: cache_data_word2[addr_index][hit_way] <= write_data_masked;
                                2'b11: cache_data_word3[addr_index][hit_way] <= write_data_masked;
                            endcase
                            cache_dirty[addr_index][hit_way] <= 1'b1;
                        end
                    end else begin
                        cache_misses <= cache_misses + 1;
                        miss_tag <= addr_tag;
                        miss_index <= addr_index;
                        miss_word_offset <= word_offset;
                        fill_counter <= 2'b00;
                        
                        // Check if replacement way is dirty and needs write-back
                        if (cache_valid[addr_index][replace_way] && 
                            cache_dirty[addr_index][replace_way]) begin
                            cache_evictions <= cache_evictions + 1;
                            writeback_tag <= cache_tags[addr_index][replace_way];
                            writeback_index <= addr_index;
                            writeback_way <= replace_way;
                            writeback_counter <= 2'b00;
                        end
                        
                        // Update replacement counters
                        case (replacement_select)
                            2'b00: lru_replacements <= lru_replacements + 1;
                            2'b01: lfu_replacements <= lfu_replacements + 1;
                            2'b10: random_replacements <= random_replacements + 1;
                            2'b11: rr_replacements <= rr_replacements + 1;
                        endcase
                    end
                end
                
                CACHE_WRITEBACK: begin
                    if (mem_ready) begin
                        if (writeback_counter == WORDS_PER_LINE - 1) begin
                            cache_dirty[writeback_index][writeback_way] <= 1'b0;
                            writeback_counter <= 2'b00;
                        end else begin
                            writeback_counter <= writeback_counter + 1;
                        end
                    end
                end
                
                CACHE_FILL: begin
                    if (mem_ready) begin
                        case (fill_counter)
                            2'b00: cache_data_word0[miss_index][replace_way] <= mem_rdata;
                            2'b01: cache_data_word1[miss_index][replace_way] <= mem_rdata;
                            2'b10: cache_data_word2[miss_index][replace_way] <= mem_rdata;
                            2'b11: cache_data_word3[miss_index][replace_way] <= mem_rdata;
                        endcase
                        
                        if (fill_counter == WORDS_PER_LINE - 1) begin
                            cache_valid[miss_index][replace_way] <= 1'b1;
                            cache_tags[miss_index][replace_way] <= miss_tag;
                            fill_counter <= 2'b00;
                            
                            // Update replacement policy tracking for new entry
                            update_lru(miss_index, replace_way);
                            access_count[miss_index][replace_way] <= 8'h01;
                            rr_next_way[miss_index] <= (replace_way + 1) % CACHE_WAYS;
                            
                            // Handle write allocation
                            if (cpu_write) begin
                                case (miss_word_offset)
                                    2'b00: cache_data_word0[miss_index][replace_way] <= write_data_masked;
                                    2'b01: cache_data_word1[miss_index][replace_way] <= write_data_masked;
                                    2'b10: cache_data_word2[miss_index][replace_way] <= write_data_masked;
                                    2'b11: cache_data_word3[miss_index][replace_way] <= write_data_masked;
                                endcase
                                cache_dirty[miss_index][replace_way] <= 1'b1;
                            end else begin
                                cache_dirty[miss_index][replace_way] <= 1'b0;
                            end
                        end else begin
                            fill_counter <= fill_counter + 1;
                        end
                    end
                end
            endcase
            
            // Handle cache flush
            if (cache_flush) begin
                for (int i = 0; i < CACHE_SETS; i++) begin
                    for (int j = 0; j < CACHE_WAYS; j++) begin
                        cache_valid[i][j] <= 1'b0;
                        cache_dirty[i][j] <= 1'b0;
                        lru_order[i][j] <= j;
                        access_count[i][j] <= '0;
                    end
                    rr_next_way[i] <= '0;
                end
            end
        end
    end
    
    // LRU update task
    task update_lru(logic [INDEX_BITS-1:0] set_idx, logic [WAY_BITS-1:0] accessed_way);
        for (int i = 0; i < CACHE_WAYS; i++) begin
            if (i == accessed_way) begin
                lru_order[set_idx][i] <= '0; // Most recently used
            end else if (lru_order[set_idx][i] < lru_order[set_idx][accessed_way]) begin
                lru_order[set_idx][i] <= lru_order[set_idx][i] + 1; // Age other entries
            end
        end
    endtask
    
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
                    if (cache_valid[addr_index][replace_way] && 
                        cache_dirty[addr_index][replace_way]) begin
                        next_state = CACHE_WRITEBACK;
                    end else begin
                        next_state = CACHE_FILL;
                    end
                end
            end
            
            CACHE_WRITEBACK: begin
                if (mem_ready && writeback_counter == WORDS_PER_LINE - 1) begin
                    next_state = CACHE_FILL;
                end
            end
            
            CACHE_FILL: begin
                if (mem_ready) begin
                    if (fill_counter == WORDS_PER_LINE - 1) begin
                        next_state = CACHE_COMPLETE;
                    end
                end
            end
            
            CACHE_COMPLETE: begin
                next_state = CACHE_IDLE;
            end
        endcase
        
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
                mem_addr = {writeback_tag, writeback_index, {OFFSET_BITS{1'b0}}} + 
                          {writeback_counter, 2'b00};
                case (writeback_counter)
                    2'b00: mem_wdata = cache_data_word0[writeback_index][writeback_way];
                    2'b01: mem_wdata = cache_data_word1[writeback_index][writeback_way];
                    2'b10: mem_wdata = cache_data_word2[writeback_index][writeback_way];
                    2'b11: mem_wdata = cache_data_word3[writeback_index][writeback_way];
                endcase
                mem_byte_en = 4'b1111;
            end
            
            CACHE_FILL: begin
                mem_req = 1'b1;
                mem_write = 1'b0;
                mem_addr = {miss_tag, miss_index, {OFFSET_BITS{1'b0}}} + 
                          {fill_counter, 2'b00};
                mem_wdata = '0;
                mem_byte_en = 4'b1111;
            end
            
            default: begin
                if (!cache_enable && cpu_req) begin
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
    
    // CPU read data output
    always_comb begin
        if (!cache_enable) begin
            cpu_rdata = mem_rdata;
        end else begin
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