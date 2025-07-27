// ARM7TDMI Cache Subsystem with Coherency
// Integrates instruction cache, data cache, and coherency controller

import arm7tdmi_pkg::*;

module arm7tdmi_cache_subsystem #(
    parameter ICACHE_SIZE_BYTES = 4096,     // 4KB instruction cache
    parameter ICACHE_LINE_SIZE = 32,        // 32 bytes per I-cache line
    parameter DCACHE_SIZE_BYTES = 1024,     // 1KB data cache
    parameter DCACHE_LINE_SIZE = 16,        // 16 bytes per D-cache line
    parameter ADDR_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // CPU instruction interface
    input  logic [ADDR_WIDTH-1:0]  cpu_iaddr,
    input  logic                    cpu_ireq,
    input  logic                    cpu_thumb_mode,
    output logic [31:0]             cpu_idata,
    output logic                    cpu_ihit,
    output logic                    cpu_iready,
    
    // CPU data interface
    input  logic [ADDR_WIDTH-1:0]  cpu_daddr,
    input  logic                    cpu_dreq,
    input  logic                    cpu_dwrite,
    input  logic [1:0]              cpu_dsize,
    input  logic [31:0]             cpu_dwdata,
    input  logic [3:0]              cpu_dbyte_en,
    output logic [31:0]             cpu_drdata,
    output logic                    cpu_dhit,
    output logic                    cpu_dready,
    
    // Memory interface (shared)
    output logic [ADDR_WIDTH-1:0]  mem_addr,
    output logic                    mem_req,
    output logic                    mem_write,
    output logic [2:0]              mem_burst_len,
    output logic [31:0]             mem_wdata,
    output logic [3:0]              mem_byte_en,
    input  logic [31:0]             mem_rdata,
    input  logic                    mem_valid,
    input  logic                    mem_ready,
    
    // Cache control
    input  logic                    cache_enable,
    input  logic                    icache_flush,
    input  logic                    icache_invalidate,
    input  logic                    dcache_flush,
    
    // Coherency control
    input  logic                    coherency_enable,
    input  logic [ADDR_WIDTH-1:0]  code_region_base,
    input  logic [ADDR_WIDTH-1:0]  code_region_size,
    
    // Statistics and debug
    output logic [31:0]             icache_hits,
    output logic [31:0]             icache_misses,
    output logic [31:0]             dcache_hits,
    output logic [31:0]             dcache_misses,
    output logic [31:0]             coherency_invalidations,
    output logic                    icache_busy,
    output logic                    dcache_busy,
    output logic                    coherency_busy
);

    // Memory arbiter state
    typedef enum logic [1:0] {
        MEM_IDLE,
        MEM_ICACHE,
        MEM_DCACHE
    } mem_arbiter_state_t;
    
    mem_arbiter_state_t mem_state;
    
    // Internal memory interfaces
    logic [ADDR_WIDTH-1:0]  icache_mem_addr;
    logic                   icache_mem_req;
    logic [2:0]             icache_mem_burst_len;
    logic                   icache_mem_ready;
    
    logic [ADDR_WIDTH-1:0]  dcache_mem_addr;
    logic                   dcache_mem_req;
    logic                   dcache_mem_write;
    logic [31:0]            dcache_mem_wdata;
    logic [3:0]             dcache_mem_byte_en;
    logic                   dcache_mem_ready;
    
    // Coherency signals
    logic [ADDR_WIDTH-1:0]  coherency_invalidate_addr;
    logic                   coherency_invalidate_req;
    logic                   coherency_invalidate_ack;
    
    logic [ADDR_WIDTH-1:0]  dcache_coherency_addr;
    logic                   dcache_coherency_write;
    logic                   dcache_coherency_req;
    logic                   dcache_coherency_ready;
    
    // Instruction Cache
    arm7tdmi_icache #(
        .CACHE_SIZE_BYTES(ICACHE_SIZE_BYTES),
        .CACHE_LINE_SIZE(ICACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_icache (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .cpu_addr                   (cpu_iaddr),
        .cpu_req                    (cpu_ireq),
        .cpu_thumb_mode             (cpu_thumb_mode),
        .cpu_data                   (cpu_idata),
        .cpu_hit                    (cpu_ihit),
        .cpu_ready                  (cpu_iready),
        .mem_addr                   (icache_mem_addr),
        .mem_req                    (icache_mem_req),
        .mem_burst_len              (icache_mem_burst_len),
        .mem_data                   (mem_rdata),
        .mem_valid                  (mem_valid && (mem_state == MEM_ICACHE)),
        .mem_ready                  (icache_mem_ready),
        .cache_enable               (cache_enable),
        .cache_flush                (icache_flush),
        .cache_invalidate           (icache_invalidate),
        .coherency_invalidate_addr  (coherency_invalidate_addr),
        .coherency_invalidate_req   (coherency_invalidate_req),
        .coherency_invalidate_ack   (coherency_invalidate_ack),
        .cache_hits                 (icache_hits),
        .cache_misses               (icache_misses),
        .cache_busy                 (icache_busy)
    );
    
    // Data Cache
    arm7tdmi_dcache_simple #(
        .CACHE_SIZE_BYTES(DCACHE_SIZE_BYTES),
        .CACHE_LINE_SIZE(DCACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dcache (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .cpu_addr               (cpu_daddr),
        .cpu_req                (cpu_dreq),
        .cpu_write              (cpu_dwrite),
        .cpu_size               (cpu_dsize),
        .cpu_wdata              (cpu_dwdata),
        .cpu_byte_en            (cpu_dbyte_en),
        .cpu_rdata              (cpu_drdata),
        .cpu_hit                (cpu_dhit),
        .cpu_ready              (cpu_dready),
        .mem_addr               (dcache_mem_addr),
        .mem_req                (dcache_mem_req),
        .mem_write              (dcache_mem_write),
        .mem_wdata              (dcache_mem_wdata),
        .mem_byte_en            (dcache_mem_byte_en),
        .mem_rdata              (mem_rdata),
        .mem_ready              (dcache_mem_ready),
        .cache_enable           (cache_enable),
        .cache_flush            (dcache_flush),
        .coherency_addr         (dcache_coherency_addr),
        .coherency_write        (dcache_coherency_write),
        .coherency_req          (dcache_coherency_req),
        .coherency_ready        (dcache_coherency_ready),
        .cache_hits             (dcache_hits),
        .cache_misses           (dcache_misses),
        .cache_busy             (dcache_busy)
    );
    
    // Cache Coherency Controller
    arm7tdmi_cache_coherency #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ICACHE_LINE_SIZE(ICACHE_LINE_SIZE),
        .DCACHE_LINE_SIZE(DCACHE_LINE_SIZE)
    ) u_coherency (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .dcache_addr                (dcache_coherency_addr),
        .dcache_write               (dcache_coherency_write),
        .dcache_req                 (dcache_coherency_req),
        .dcache_ready               (dcache_coherency_ready),
        .icache_invalidate_addr     (coherency_invalidate_addr),
        .icache_invalidate_req      (coherency_invalidate_req),
        .icache_invalidate_ack      (coherency_invalidate_ack),
        .coherency_enable           (coherency_enable),
        .code_region_base           (code_region_base),
        .code_region_size           (code_region_size),
        .coherency_invalidations    (coherency_invalidations),
        .coherency_busy             (coherency_busy)
    );
    
    // Memory Arbiter
    // Simple priority scheme: D-cache has priority over I-cache
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_state <= MEM_IDLE;
        end else begin
            case (mem_state)
                MEM_IDLE: begin
                    if (dcache_mem_req) begin
                        mem_state <= MEM_DCACHE;
                    end else if (icache_mem_req) begin
                        mem_state <= MEM_ICACHE;
                    end
                end
                
                MEM_ICACHE: begin
                    if (!icache_mem_req) begin
                        mem_state <= MEM_IDLE;
                    end
                end
                
                MEM_DCACHE: begin
                    if (!dcache_mem_req) begin
                        mem_state <= MEM_IDLE;
                    end
                end
            endcase
        end
    end
    
    // Memory interface multiplexing
    always_comb begin
        case (mem_state)
            MEM_ICACHE: begin
                mem_addr = icache_mem_addr;
                mem_req = icache_mem_req;
                mem_write = 1'b0;
                mem_burst_len = icache_mem_burst_len;
                mem_wdata = 32'h0;
                mem_byte_en = 4'b1111;
                icache_mem_ready = mem_ready;
                dcache_mem_ready = 1'b0;
            end
            
            MEM_DCACHE: begin
                mem_addr = dcache_mem_addr;
                mem_req = dcache_mem_req;
                mem_write = dcache_mem_write;
                mem_burst_len = 3'b000;  // Single transfers for D-cache
                mem_wdata = dcache_mem_wdata;
                mem_byte_en = dcache_mem_byte_en;
                icache_mem_ready = 1'b0;
                dcache_mem_ready = mem_ready;
            end
            
            default: begin // MEM_IDLE
                mem_addr = 32'h0;
                mem_req = 1'b0;
                mem_write = 1'b0;
                mem_burst_len = 3'b000;
                mem_wdata = 32'h0;
                mem_byte_en = 4'b0000;
                icache_mem_ready = 1'b0;
                dcache_mem_ready = 1'b0;
            end
        endcase
    end
    
    // Debug and verification
    `ifdef SIMULATION
    // Coherency protocol assertions
    property coherency_invalidation_handled;
        @(posedge clk) coherency_invalidate_req |-> ##[1:5] coherency_invalidate_ack;
    endproperty
    assert property (coherency_invalidation_handled);
    
    property no_simultaneous_memory_access;
        @(posedge clk) icache_mem_req && dcache_mem_req |-> $past(mem_state) != MEM_IDLE;
    endproperty
    assert property (no_simultaneous_memory_access);
    
    // Coverage for cache interactions
    covergroup cache_interactions @(posedge clk);
        icache_access: coverpoint cpu_ireq;
        dcache_access: coverpoint cpu_dreq;
        dcache_write: coverpoint (cpu_dreq && cpu_dwrite);
        coherency_active: coverpoint coherency_invalidate_req;
        
        cross icache_access, dcache_write;
        cross dcache_write, coherency_active;
    endgroup
    
    cache_interactions cov_interactions = new();
    `endif

endmodule