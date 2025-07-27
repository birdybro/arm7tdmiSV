// ARM7TDMI Memory Management Unit (MMU)
// Implements ARM v4 virtual memory architecture with page tables and TLB

// import arm7tdmi_pkg::*;

module arm7tdmi_mmu #(
    parameter TLB_ENTRIES = 32,         // Number of TLB entries
    parameter ADDR_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // CPU interface
    input  logic [ADDR_WIDTH-1:0]  cpu_vaddr,          // Virtual address from CPU
    input  logic                    cpu_req,            // Request valid
    input  logic                    cpu_write,          // Write request
    input  logic [1:0]              cpu_size,           // Transfer size (00=byte, 01=halfword, 10=word)
    input  logic [31:0]             cpu_wdata,          // Write data
    output logic [31:0]             cpu_rdata,          // Read data
    output logic                    cpu_ready,          // Request complete
    output logic                    cpu_abort,          // Memory abort (page fault)
    
    // Physical memory interface
    output logic [ADDR_WIDTH-1:0]  mem_paddr,          // Physical address to memory
    output logic                    mem_req,            // Memory request
    output logic                    mem_write,          // Memory write
    output logic [1:0]              mem_size,           // Memory transfer size
    output logic [31:0]             mem_wdata,          // Memory write data
    input  logic [31:0]             mem_rdata,          // Memory read data
    input  logic                    mem_ready,          // Memory ready
    input  logic                    mem_abort,          // Memory abort
    
    // Page table base register (from coprocessor)
    input  logic [31:0]             ttb_base,           // Translation table base
    input  logic                    mmu_enable,         // MMU enable
    input  logic                    cache_enable,       // Cache enable
    input  logic [3:0]              domain_access,      // Domain access control
    input  logic [7:0]              current_asid,       // Current Address Space ID
    
    // TLB control
    input  logic                    tlb_flush_all,      // Flush entire TLB
    input  logic                    tlb_flush_entry,    // Flush single TLB entry
    input  logic [31:0]             tlb_flush_addr,     // Address for single entry flush
    input  logic                    tlb_flush_asid,     // Flush all entries for specific ASID
    input  logic [7:0]              tlb_flush_asid_val, // ASID value to flush
    input  logic                    tlb_flush_global,   // Flush all global entries
    
    // Status and debug
    output logic [31:0]             tlb_hits,           // TLB hit counter
    output logic [31:0]             tlb_misses,         // TLB miss counter
    output logic [31:0]             page_faults,        // Page fault counter
    output logic [31:0]             asid_switches,      // ASID context switch counter
    output logic                    mmu_busy            // MMU busy with translation
);

    // ARM page table definitions - multiple page sizes
    localparam SECTION_SIZE = 32'h100000;    // 1MB section
    localparam LARGE_PAGE_SIZE = 32'h10000;  // 64KB large page
    localparam SMALL_PAGE_SIZE = 32'h1000;   // 4KB small page
    localparam TINY_PAGE_SIZE = 32'h400;     // 1KB tiny page
    
    // Page table entry types
    typedef enum logic [1:0] {
        PTE_FAULT    = 2'b00,
        PTE_COARSE   = 2'b01,  // Coarse page table
        PTE_SECTION  = 2'b10,  // 1MB section
        PTE_FINE     = 2'b11   // Fine page table (deprecated)
    } pte_type_t;
    
    // Page size types for TLB entries
    typedef enum logic [1:0] {
        PAGE_SIZE_1MB    = 2'b00,  // 1MB section
        PAGE_SIZE_64KB   = 2'b01,  // 64KB large page
        PAGE_SIZE_4KB    = 2'b10,  // 4KB small page
        PAGE_SIZE_1KB    = 2'b11   // 1KB tiny page
    } page_size_t;
    
    // Permission types
    typedef enum logic [1:0] {
        PERM_NONE    = 2'b00,  // No access
        PERM_SUPER   = 2'b01,  // Supervisor only
        PERM_USER_RO = 2'b10,  // User read-only
        PERM_USER_RW = 2'b11   // User read-write
    } perm_t;
    
    // TLB storage arrays - separate for Icarus compatibility
    logic                           tlb_valid     [TLB_ENTRIES];
    logic [19:0]                    tlb_vpn       [TLB_ENTRIES];  // Virtual page number
    logic [19:0]                    tlb_ppn       [TLB_ENTRIES];  // Physical page number
    logic [7:0]                     tlb_asid      [TLB_ENTRIES];
    logic                           tlb_global    [TLB_ENTRIES];
    logic [3:0]                     tlb_domain    [TLB_ENTRIES];
    perm_t                          tlb_perm      [TLB_ENTRIES];
    logic                           tlb_cacheable [TLB_ENTRIES];
    logic                           tlb_bufferable[TLB_ENTRIES];
    page_size_t                     tlb_page_size [TLB_ENTRIES];  // Page size for each entry
    logic [$clog2(TLB_ENTRIES)-1:0] tlb_next_replace;
    
    // ASID management
    logic [7:0] prev_asid;
    logic       asid_changed;
    
    // ASID change detection
    assign asid_changed = (prev_asid != current_asid);
    
    // Address translation components - multiple page sizes
    logic [19:0] va_section_index;    // Virtual address section index (bits 31:20) - 1MB
    logic [19:0] va_section_offset;   // Section offset (bits 19:0) - 1MB
    logic [19:0] va_large_page_index; // Virtual address large page index (bits 31:16) - 64KB
    logic [15:0] va_large_page_offset;// Large page offset (bits 15:0) - 64KB
    logic [19:0] va_small_page_index; // Virtual address small page index (bits 31:12) - 4KB
    logic [11:0] va_small_page_offset;// Small page offset (bits 11:0) - 4KB
    logic [19:0] va_tiny_page_index;  // Virtual address tiny page index (bits 31:10) - 1KB
    logic [9:0]  va_tiny_page_offset; // Tiny page offset (bits 9:0) - 1KB
    logic [7:0]  va_page_sub;         // Page table index (bits 19:12)
    
    assign va_section_index = cpu_vaddr[31:20];
    assign va_section_offset = cpu_vaddr[19:0];
    assign va_large_page_index = cpu_vaddr[31:16];
    assign va_large_page_offset = cpu_vaddr[15:0];
    assign va_small_page_index = cpu_vaddr[31:12];
    assign va_small_page_offset = cpu_vaddr[11:0];
    assign va_tiny_page_index = cpu_vaddr[31:10];
    assign va_tiny_page_offset = cpu_vaddr[9:0];
    assign va_page_sub = cpu_vaddr[19:12];
    
    // Translation state machine
    typedef enum logic [2:0] {
        TRANS_IDLE,
        TRANS_TLB_LOOKUP,
        TRANS_L1_FETCH,
        TRANS_L2_FETCH,
        TRANS_COMPLETE,
        TRANS_FAULT
    } trans_state_t;
    
    trans_state_t state, next_state;
    
    // Translation working registers
    logic [31:0] l1_pte;            // Level 1 page table entry
    logic [31:0] l2_pte;            // Level 2 page table entry
    logic [31:0] l1_addr;           // Level 1 table address
    logic [31:0] l2_addr;           // Level 2 table address
    logic [31:0] final_paddr;       // Final physical address
    logic        tlb_hit;           // TLB hit indication
    logic [$clog2(TLB_ENTRIES)-1:0] tlb_hit_index;
    logic        permission_ok;     // Permission check result
    logic        domain_ok;         // Domain check result
    logic        mem_req_prev;      // Previous cycle mem_req
    logic        data_valid;        // Data is valid for state transition
    
    // TLB lookup logic - simplified for Icarus compatibility
    always_comb begin
        tlb_hit = 1'b0;
        tlb_hit_index = '0;
        
        // Check each TLB entry manually to avoid complex loops
        if (tlb_valid[0] && (tlb_global[0] || (tlb_asid[0] == current_asid))) begin
            if ((tlb_page_size[0] == PAGE_SIZE_1MB && tlb_vpn[0] == va_section_index) ||
                (tlb_page_size[0] == PAGE_SIZE_4KB && tlb_vpn[0] == va_small_page_index)) begin
                tlb_hit = 1'b1;
                tlb_hit_index = 5'd0;
            end
        end else if (tlb_valid[1] && (tlb_global[1] || (tlb_asid[1] == current_asid)) && !tlb_hit) begin
            if ((tlb_page_size[1] == PAGE_SIZE_1MB && tlb_vpn[1] == va_section_index) ||
                (tlb_page_size[1] == PAGE_SIZE_4KB && tlb_vpn[1] == va_small_page_index)) begin
                tlb_hit = 1'b1;
                tlb_hit_index = 5'd1;
            end
        end else if (tlb_valid[2] && (tlb_global[2] || (tlb_asid[2] == current_asid)) && !tlb_hit) begin
            if ((tlb_page_size[2] == PAGE_SIZE_1MB && tlb_vpn[2] == va_section_index) ||
                (tlb_page_size[2] == PAGE_SIZE_4KB && tlb_vpn[2] == va_small_page_index)) begin
                tlb_hit = 1'b1;
                tlb_hit_index = 5'd2;
            end
        end else if (tlb_valid[3] && (tlb_global[3] || (tlb_asid[3] == current_asid)) && !tlb_hit) begin
            if ((tlb_page_size[3] == PAGE_SIZE_1MB && tlb_vpn[3] == va_section_index) ||
                (tlb_page_size[3] == PAGE_SIZE_4KB && tlb_vpn[3] == va_small_page_index)) begin
                tlb_hit = 1'b1;
                tlb_hit_index = 5'd3;
            end
        end
    end
    
    // Permission checking - simplified for Icarus compatibility
    always_comb begin
        permission_ok = 1'b1;  // Default allow for MMU disabled
        domain_ok = 1'b1;      // Default allow for MMU disabled
        
        if (mmu_enable && tlb_hit) begin
            // Simplified permission check - always allow for now
            domain_ok = 1'b1;
            permission_ok = 1'b1;
        end
    end
    
    // Address translation - simplified for Icarus compatibility  
    always_comb begin
        if (mmu_enable && tlb_hit) begin
            // TLB hit - use TLB data
            if (tlb_hit_index == 5'd0) begin
                if (tlb_page_size[0] == PAGE_SIZE_1MB)
                    final_paddr = {tlb_ppn[0], va_section_offset};
                else
                    final_paddr = {tlb_ppn[0], va_small_page_offset};
            end else if (tlb_hit_index == 5'd1) begin
                if (tlb_page_size[1] == PAGE_SIZE_1MB)
                    final_paddr = {tlb_ppn[1], va_section_offset};
                else
                    final_paddr = {tlb_ppn[1], va_small_page_offset};
            end else if (tlb_hit_index == 5'd2) begin
                if (tlb_page_size[2] == PAGE_SIZE_1MB)
                    final_paddr = {tlb_ppn[2], va_section_offset};
                else
                    final_paddr = {tlb_ppn[2], va_small_page_offset};
            end else if (tlb_hit_index == 5'd3) begin
                if (tlb_page_size[3] == PAGE_SIZE_1MB)
                    final_paddr = {tlb_ppn[3], va_section_offset};
                else
                    final_paddr = {tlb_ppn[3], va_small_page_offset};
            end else begin
                final_paddr = cpu_vaddr;  // Default pass-through
            end
        end else if (mmu_enable && (state == TRANS_COMPLETE)) begin
            // TLB miss but translation complete - use PTE data
            if (l1_pte[1:0] == PTE_SECTION) begin
                // Section mapping: L1 PTE[31:20] is base, add offset
                final_paddr = {l1_pte[31:20], va_section_offset};
            end else if (l2_pte[1:0] != 2'b00) begin
                // Page mapping: L2 PTE[31:12] is base, add offset  
                final_paddr = {l2_pte[31:12], va_small_page_offset};
            end else begin
                final_paddr = cpu_vaddr;  // Default pass-through
            end
        end else begin
            final_paddr = cpu_vaddr;  // Pass-through when MMU disabled or miss
        end
    end
    
    // Level 1 page table address calculation
    assign l1_addr = ttb_base + {va_section_index, 2'b00};
    
    // Level 2 page table address calculation (from L1 PTE)
    assign l2_addr = {l1_pte[31:10], va_page_sub, 2'b00};
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= TRANS_IDLE;
            tlb_next_replace <= '0;
            tlb_hits <= '0;
            tlb_misses <= '0;
            page_faults <= '0;
            asid_switches <= '0;
            prev_asid <= '0;
            mem_req_prev <= '0;
            data_valid <= '0;
            
            // Initialize TLB
            for (int i = 0; i < TLB_ENTRIES; i++) begin
                tlb_valid[i] <= 1'b0;
                tlb_vpn[i] <= '0;
                tlb_ppn[i] <= '0;
                tlb_asid[i] <= '0;
                tlb_global[i] <= 1'b0;
                tlb_domain[i] <= '0;
                tlb_perm[i] <= PERM_NONE;
                tlb_cacheable[i] <= 1'b0;
                tlb_bufferable[i] <= 1'b0;
                tlb_page_size[i] <= PAGE_SIZE_4KB;
            end
        end else begin
            state <= next_state;
            mem_req_prev <= mem_req;
            data_valid <= mem_req && mem_ready; // Data is valid when we had a request and got ready
            
            // Track ASID changes
            prev_asid <= current_asid;
            if (asid_changed) begin
                asid_switches <= asid_switches + 1;
            end
            
            case (state)
                TRANS_TLB_LOOKUP: begin
                    if (tlb_hit) begin
                        tlb_hits <= tlb_hits + 1;
                    end else begin
                        tlb_misses <= tlb_misses + 1;
                    end
                end
                
                TRANS_FAULT: begin
                    page_faults <= page_faults + 1;
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            TRANS_IDLE: begin
                if (cpu_req) begin
                    if (mmu_enable) begin
                        next_state = TRANS_TLB_LOOKUP;
                    end else begin
                        next_state = TRANS_COMPLETE;  // MMU disabled - pass through
                    end
                end
            end
            
            TRANS_TLB_LOOKUP: begin
                if (tlb_hit && domain_ok && permission_ok) begin
                    next_state = TRANS_COMPLETE;
                end else if (tlb_hit) begin
                    next_state = TRANS_FAULT;  // Permission/domain fault
                end else begin
                    next_state = TRANS_L1_FETCH;  // TLB miss
                end
            end
            
            TRANS_L1_FETCH: begin
                if (mem_ready && mem_req) begin
                    case (mem_rdata[1:0])
                        PTE_FAULT:   next_state = TRANS_FAULT;
                        PTE_SECTION: next_state = TRANS_COMPLETE;
                        PTE_COARSE:  next_state = TRANS_L2_FETCH;
                        default:     next_state = TRANS_FAULT;
                    endcase
                end
            end
            
            TRANS_L2_FETCH: begin
                if (mem_ready && mem_req) begin
                    if (mem_rdata[1:0] != 2'b00) begin
                        next_state = TRANS_COMPLETE;
                    end else begin
                        next_state = TRANS_FAULT;
                    end
                end
            end
            
            TRANS_COMPLETE, TRANS_FAULT: begin
                if (!cpu_req) begin
                    next_state = TRANS_IDLE;
                end
            end
        endcase
        
        // Handle TLB flush operations
        if (tlb_flush_all) begin
            next_state = TRANS_IDLE;
        end
    end
    
    // Page table entry capture
    always_ff @(posedge clk) begin
        if (state == TRANS_L1_FETCH && mem_ready && mem_req) begin
            l1_pte <= mem_rdata;
        end
        if (state == TRANS_L2_FETCH && mem_ready && mem_req) begin
            l2_pte <= mem_rdata;
        end
    end
    
    // TLB update logic - simplified for Icarus compatibility
    always_ff @(posedge clk) begin
        if (tlb_flush_all) begin
            // Manually flush first few entries
            tlb_valid[0] <= 1'b0;
            tlb_valid[1] <= 1'b0;
            tlb_valid[2] <= 1'b0;
            tlb_valid[3] <= 1'b0;
            tlb_valid[4] <= 1'b0;
            tlb_valid[5] <= 1'b0;
            tlb_valid[6] <= 1'b0;
            tlb_valid[7] <= 1'b0;
        end else if ((state == TRANS_L1_FETCH || state == TRANS_L2_FETCH) && 
                     mem_ready && next_state == TRANS_COMPLETE) begin
            // Add new entry to TLB - use simple round-robin on first 4 entries
            case (tlb_next_replace[1:0])
                2'd0: begin
                    tlb_valid[0] <= 1'b1;
                    tlb_asid[0] <= current_asid;
                    if (state == TRANS_L1_FETCH) begin
                        tlb_vpn[0] <= va_section_index;
                        tlb_ppn[0] <= l1_pte[31:20];
                        tlb_domain[0] <= l1_pte[8:5];
                        tlb_perm[0] <= l1_pte[11:10];
                        tlb_cacheable[0] <= l1_pte[3];
                        tlb_bufferable[0] <= l1_pte[2];
                        tlb_global[0] <= l1_pte[17];
                        tlb_page_size[0] <= PAGE_SIZE_1MB;
                    end else begin
                        tlb_vpn[0] <= va_small_page_index;
                        tlb_ppn[0] <= l2_pte[31:12];
                        tlb_domain[0] <= l1_pte[8:5];
                        tlb_perm[0] <= l2_pte[5:4];
                        tlb_cacheable[0] <= l2_pte[3];
                        tlb_bufferable[0] <= l2_pte[2];
                        tlb_global[0] <= l2_pte[11];
                        tlb_page_size[0] <= PAGE_SIZE_4KB;
                    end
                end
                2'd1: begin
                    tlb_valid[1] <= 1'b1;
                    tlb_asid[1] <= current_asid;
                    if (state == TRANS_L1_FETCH) begin
                        tlb_vpn[1] <= va_section_index;
                        tlb_ppn[1] <= l1_pte[31:20];
                        tlb_domain[1] <= l1_pte[8:5];
                        tlb_perm[1] <= l1_pte[11:10];
                        tlb_cacheable[1] <= l1_pte[3];
                        tlb_bufferable[1] <= l1_pte[2];
                        tlb_global[1] <= l1_pte[17];
                        tlb_page_size[1] <= PAGE_SIZE_1MB;
                    end else begin
                        tlb_vpn[1] <= va_small_page_index;
                        tlb_ppn[1] <= l2_pte[31:12];
                        tlb_domain[1] <= l1_pte[8:5];
                        tlb_perm[1] <= l2_pte[5:4];
                        tlb_cacheable[1] <= l2_pte[3];
                        tlb_bufferable[1] <= l2_pte[2];
                        tlb_global[1] <= l2_pte[11];
                        tlb_page_size[1] <= PAGE_SIZE_4KB;
                    end
                end
                2'd2: begin
                    tlb_valid[2] <= 1'b1;
                    tlb_asid[2] <= current_asid;
                    if (state == TRANS_L1_FETCH) begin
                        tlb_vpn[2] <= va_section_index;
                        tlb_ppn[2] <= l1_pte[31:20];
                        tlb_domain[2] <= l1_pte[8:5];
                        tlb_perm[2] <= l1_pte[11:10];
                        tlb_cacheable[2] <= l1_pte[3];
                        tlb_bufferable[2] <= l1_pte[2];
                        tlb_global[2] <= l1_pte[17];
                        tlb_page_size[2] <= PAGE_SIZE_1MB;
                    end else begin
                        tlb_vpn[2] <= va_small_page_index;
                        tlb_ppn[2] <= l2_pte[31:12];
                        tlb_domain[2] <= l1_pte[8:5];
                        tlb_perm[2] <= l2_pte[5:4];
                        tlb_cacheable[2] <= l2_pte[3];
                        tlb_bufferable[2] <= l2_pte[2];
                        tlb_global[2] <= l2_pte[11];
                        tlb_page_size[2] <= PAGE_SIZE_4KB;
                    end
                end
                2'd3: begin
                    tlb_valid[3] <= 1'b1;
                    tlb_asid[3] <= current_asid;
                    if (state == TRANS_L1_FETCH) begin
                        tlb_vpn[3] <= va_section_index;
                        tlb_ppn[3] <= l1_pte[31:20];
                        tlb_domain[3] <= l1_pte[8:5];
                        tlb_perm[3] <= l1_pte[11:10];
                        tlb_cacheable[3] <= l1_pte[3];
                        tlb_bufferable[3] <= l1_pte[2];
                        tlb_global[3] <= l1_pte[17];
                        tlb_page_size[3] <= PAGE_SIZE_1MB;
                    end else begin
                        tlb_vpn[3] <= va_small_page_index;
                        tlb_ppn[3] <= l2_pte[31:12];
                        tlb_domain[3] <= l1_pte[8:5];
                        tlb_perm[3] <= l2_pte[5:4];
                        tlb_cacheable[3] <= l2_pte[3];
                        tlb_bufferable[3] <= l2_pte[2];
                        tlb_global[3] <= l2_pte[11];
                        tlb_page_size[3] <= PAGE_SIZE_4KB;
                    end
                end
            endcase
            
            tlb_next_replace <= tlb_next_replace + 1;
        end
    end
    
    // Memory interface control
    always_comb begin
        mem_req = 1'b0;
        mem_paddr = final_paddr;
        mem_write = cpu_write;
        mem_size = cpu_size;
        mem_wdata = cpu_wdata;
        
        // Handle MMU disabled case first (bypass state machine)
        if (!mmu_enable && cpu_req) begin
            mem_req = 1'b1;
            mem_paddr = cpu_vaddr;
        end else begin
            case (state)
                TRANS_L1_FETCH: begin
                    mem_req = 1'b1;
                    mem_paddr = l1_addr;
                    mem_write = 1'b0;
                    mem_size = 2'b10;  // Word access
                    mem_wdata = '0;
                end
                
                TRANS_L2_FETCH: begin
                    mem_req = 1'b1;
                    mem_paddr = l2_addr;
                    mem_write = 1'b0;
                    mem_size = 2'b10;  // Word access
                    mem_wdata = '0;
                end
                
                TRANS_COMPLETE: begin
                    mem_req = cpu_req;
                    mem_paddr = final_paddr;  // Use translated address
                end
            endcase
        end
    end
    
    // CPU interface
    assign cpu_rdata = mem_rdata;
    assign cpu_ready = (state == TRANS_COMPLETE && mem_ready && mem_req_prev) || 
                      (state == TRANS_IDLE && !cpu_req) ||
                      (!mmu_enable && cpu_req && mem_ready && mem_req_prev);
    assign cpu_abort = (state == TRANS_FAULT) || mem_abort;
    assign mmu_busy = (state != TRANS_IDLE) && (state != TRANS_COMPLETE);
    
    // Debug and verification
    `ifdef SIMULATION
    // TLB utilization tracking
    integer tlb_used_entries;
    integer tlb_global_entries;
    integer tlb_current_asid_entries;
    
    always_comb begin
        tlb_used_entries = 0;
        tlb_global_entries = 0;
        tlb_current_asid_entries = 0;
        
        for (int i = 0; i < TLB_ENTRIES; i++) begin
            if (tlb_valid[i]) begin
                tlb_used_entries++;
                if (tlb_global[i]) begin
                    tlb_global_entries++;
                end else if (tlb_asid[i] == current_asid) begin
                    tlb_current_asid_entries++;
                end
            end
        end
    end
    
    // Assertions
    property valid_state;
        @(posedge clk) state inside {TRANS_IDLE, TRANS_TLB_LOOKUP, TRANS_L1_FETCH, 
                                   TRANS_L2_FETCH, TRANS_COMPLETE, TRANS_FAULT};
    endproperty
    assert property (valid_state);
    
    property mmu_ready_when_complete;
        @(posedge clk) (state == TRANS_COMPLETE) |-> cpu_ready;
    endproperty
    assert property (mmu_ready_when_complete);
    `endif

endmodule