// Testbench for ARM7TDMI Coprocessor Interface (CP15)
`timescale 1ns/1ps

module coprocessor_test_tb;

    // Import package
    import arm7tdmi_pkg::*;
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Coprocessor interface
    logic        cp_en;
    cp_op_t      cp_op;
    logic [3:0]  cp_num;
    logic [3:0]  cp_crn;
    logic [3:0]  cp_crm;
    logic [2:0]  cp_op1;
    logic [2:0]  cp_op2;
    logic [31:0] cp_data_in;
    
    // Coprocessor response
    logic        cp_busy;
    logic        cp_absent;
    logic [31:0] cp_data_out;
    
    // System control outputs
    logic        mmu_enable;
    logic        dcache_enable;
    logic        icache_enable;
    logic        write_buffer_en;
    logic [31:0] ttb_base;
    logic [1:0]  ttb_ctrl;
    logic [31:0] domain_access;
    logic        high_vectors;
    logic        rom_protection;
    logic        system_protect;
    
    // Cache control
    logic        dcache_clean;
    logic        dcache_flush;
    logic        icache_flush;
    logic        tlb_flush;
    
    // System information
    logic [31:0] cpu_id;
    logic [31:0] cache_type;
    
    // Debug
    logic        debug_mode = 0;
    logic [31:0] cp15_reg_out;
    
    // Test variables
    int tests_run = 0;
    int tests_passed = 0;
    
    // DUT instantiation
    arm7tdmi_coprocessor u_coprocessor (
        .clk                (clk),
        .rst_n              (rst_n),
        .cp_en              (cp_en),
        .cp_op              (cp_op),
        .cp_num             (cp_num),
        .cp_crn             (cp_crn),
        .cp_crm             (cp_crm),
        .cp_op1             (cp_op1),
        .cp_op2             (cp_op2),
        .cp_data_in         (cp_data_in),
        .cp_busy            (cp_busy),
        .cp_absent          (cp_absent),
        .cp_data_out        (cp_data_out),
        .mmu_enable         (mmu_enable),
        .dcache_enable      (dcache_enable),
        .icache_enable      (icache_enable),
        .write_buffer_en    (write_buffer_en),
        .ttb_base           (ttb_base),
        .ttb_ctrl           (ttb_ctrl),
        .domain_access      (domain_access),
        .high_vectors       (high_vectors),
        .rom_protection     (rom_protection),
        .system_protect     (system_protect),
        .dcache_clean       (dcache_clean),
        .dcache_flush       (dcache_flush),
        .icache_flush       (icache_flush),
        .tlb_flush          (tlb_flush),
        .cpu_id             (cpu_id),
        .cache_type         (cache_type),
        .debug_mode         (debug_mode),
        .cp15_reg_out       (cp15_reg_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Helper tasks
    task automatic mrc(input [3:0] crn, input [3:0] crm, input [2:0] op1, input [2:0] op2, output [31:0] data);
        @(posedge clk);
        cp_en = 1;
        cp_op = CP_MRC;
        cp_num = 15;  // CP15
        cp_crn = crn;
        cp_crm = crm;
        cp_op1 = op1;
        cp_op2 = op2;
        cp_data_in = 0;
        @(posedge clk);
        data = cp_data_out;
        cp_en = 0;
        @(posedge clk);
    endtask
    
    task automatic mcr(input [3:0] crn, input [3:0] crm, input [2:0] op1, input [2:0] op2, input [31:0] data);
        @(posedge clk);
        cp_en = 1;
        cp_op = CP_MCR;
        cp_num = 15;  // CP15
        cp_crn = crn;
        cp_crm = crm;
        cp_op1 = op1;
        cp_op2 = op2;
        cp_data_in = data;
        @(posedge clk);
        cp_en = 0;
        @(posedge clk);
    endtask
    
    // Test CPU ID register
    task test_cpu_id();
        logic [31:0] id;
        logic test_passed;
        
        tests_run++;
        $display("\n=== Testing CPU ID Register ===");
        
        // Read CPU ID (c0, c0, 0, 0)
        mrc(0, 0, 0, 0, id);
        
        test_passed = (id == 32'h41007000);  // ARM7TDMI ID
        
        if (test_passed) begin
            tests_passed++;
            $display("✅ CPU ID test PASSED: 0x%08X", id);
        end else begin
            $display("❌ CPU ID test FAILED: expected 0x41007000, got 0x%08X", id);
        end
    endtask
    
    // Test control register
    task test_control_register();
        logic [31:0] ctrl_write, ctrl_read;
        logic test_passed;
        
        tests_run++;
        $display("\n=== Testing Control Register ===");
        
        // Write control register
        ctrl_write = 32'h00003005;  // Enable MMU, D-cache, I-cache
        mcr(1, 0, 0, 0, ctrl_write);
        
        // Read back
        mrc(1, 0, 0, 0, ctrl_read);
        
        // Check system outputs
        test_passed = (ctrl_read[13:0] == ctrl_write[13:0]) &&
                      mmu_enable && 
                      dcache_enable && 
                      icache_enable;
        
        if (test_passed) begin
            tests_passed++;
            $display("✅ Control register test PASSED");
            $display("   MMU=%b, D-cache=%b, I-cache=%b", mmu_enable, dcache_enable, icache_enable);
        end else begin
            $display("❌ Control register test FAILED");
            $display("   Written: 0x%08X, Read: 0x%08X", ctrl_write, ctrl_read);
        end
    endtask
    
    // Test translation table base
    task test_ttb_register();
        logic [31:0] ttb_write, ttb_read;
        logic test_passed;
        
        tests_run++;
        $display("\n=== Testing Translation Table Base ===");
        
        // Write TTB
        ttb_write = 32'h80000000;  // TTB at 0x80000000
        mcr(2, 0, 0, 0, ttb_write);
        
        // Read back
        mrc(2, 0, 0, 0, ttb_read);
        
        test_passed = (ttb_read == ttb_write) && (ttb_base == ttb_write);
        
        if (test_passed) begin
            tests_passed++;
            $display("✅ TTB register test PASSED: 0x%08X", ttb_read);
        end else begin
            $display("❌ TTB register test FAILED");
            $display("   Written: 0x%08X, Read: 0x%08X", ttb_write, ttb_read);
        end
    endtask
    
    // Test cache operations
    task test_cache_operations();
        logic test_passed;
        
        tests_run++;
        $display("\n=== Testing Cache Operations ===");
        
        test_passed = 1;
        
        // Test I-cache flush
        @(posedge clk);
        mcr(7, 5, 0, 0, 0);  // Flush I-cache
        @(posedge clk);
        if (!icache_flush) begin
            $display("❌ I-cache flush failed");
            test_passed = 0;
        end
        @(posedge clk);
        if (icache_flush) begin
            $display("❌ I-cache flush signal not cleared");
            test_passed = 0;
        end
        
        // Test D-cache flush
        @(posedge clk);
        mcr(7, 6, 0, 0, 0);  // Flush D-cache
        @(posedge clk);
        if (!dcache_flush) begin
            $display("❌ D-cache flush failed");
            test_passed = 0;
        end
        
        // Test D-cache clean
        @(posedge clk);
        mcr(7, 10, 0, 1, 0);  // Clean D-cache
        @(posedge clk);
        if (!dcache_clean) begin
            $display("❌ D-cache clean failed");
            test_passed = 0;
        end
        
        if (test_passed) begin
            tests_passed++;
            $display("✅ Cache operations test PASSED");
        end else begin
            $display("❌ Cache operations test FAILED");
        end
    endtask
    
    // Test coprocessor absent
    task test_coprocessor_absent();
        logic [31:0] data;
        logic test_passed;
        
        tests_run++;
        $display("\n=== Testing Coprocessor Absent ===");
        
        // Try to access CP14 (should be absent)
        @(posedge clk);
        cp_en = 1;
        cp_op = CP_MRC;
        cp_num = 14;  // CP14 (not present)
        cp_crn = 0;
        cp_crm = 0;
        cp_op1 = 0;
        cp_op2 = 0;
        @(posedge clk);
        
        test_passed = cp_absent && !cp_busy;
        
        cp_en = 0;
        @(posedge clk);
        
        if (test_passed) begin
            tests_passed++;
            $display("✅ Coprocessor absent test PASSED");
        end else begin
            $display("❌ Coprocessor absent test FAILED");
        end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("coprocessor_test_tb.vcd");
        $dumpvars(0, coprocessor_test_tb);
        
        // Initialize
        rst_n = 0;
        cp_en = 0;
        cp_op = CP_MRC;
        cp_num = 15;
        cp_crn = 0;
        cp_crm = 0;
        cp_op1 = 0;
        cp_op2 = 0;
        cp_data_in = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Coprocessor (CP15) Test ===\n");
        
        // Run tests
        test_cpu_id();
        test_control_register();
        test_ttb_register();
        test_cache_operations();
        test_coprocessor_absent();
        
        // Test summary
        repeat(10) @(posedge clk);
        $display("\n=== Test Summary ===");
        $display("Tests Run:    %0d", tests_run);
        $display("Tests Passed: %0d", tests_passed);
        $display("Pass Rate:    %0.1f%%", (tests_passed * 100.0) / tests_run);
        
        if (tests_passed == tests_run) begin
            $display("✅ ALL COPROCESSOR TESTS PASSED!");
        end else begin
            $display("❌ SOME COPROCESSOR TESTS FAILED");
        end
        
        $finish;
    end

endmodule