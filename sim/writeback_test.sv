// ARM7TDMI Writeback Unit Test Bench
// Tests register writeback, CPSR updates, exception handling, and instruction retirement

`timescale 1ns/1ps

module writeback_test;
    
    // Test parameters
    localparam CLK_PERIOD = 10;
    
    // System signals
    logic clk = 0;
    logic rst_n = 1;
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Writeback unit inputs (from memory)
    logic [3:0]  instr_type = 4'b0000;          // INSTR_DATA_PROC
    logic [31:0] alu_result = 32'h12345678;
    logic [31:0] load_data = 32'hABCDEF01;
    logic [31:0] pc_in = 32'h1000;
    logic        memory_valid = 1'b1;
    logic        memory_complete = 1'b1;
    
    // Register writeback inputs
    logic [3:0]  reg_write_addr = 4'h2;         // R2
    logic [31:0] reg_write_data = 32'h12345678;
    logic        reg_write_enable = 1'b1;
    
    // CPSR update inputs
    logic [31:0] cpsr_new = 32'h60000010;       // User mode, no flags
    logic        cpsr_update = 1'b0;
    logic        set_flags = 1'b1;
    logic        alu_negative = 1'b0;
    logic        alu_zero = 1'b0;
    logic        alu_carry = 1'b1;
    logic        alu_overflow = 1'b0;
    
    // Branch control inputs
    logic        branch_taken = 1'b0;
    logic [31:0] branch_target = 32'h2000;
    logic        branch_link = 1'b0;
    
    // Exception inputs
    logic        data_abort = 1'b0;
    logic [31:0] abort_address = 32'h0;
    logic        alignment_fault = 1'b0;
    logic        undefined_instr = 1'b0;
    logic        swi_exception = 1'b0;
    logic        irq_request = 1'b0;
    logic        fiq_request = 1'b0;
    
    // PSR transfer inputs
    logic        psr_to_reg = 1'b0;
    logic        psr_spsr = 1'b0;
    logic        psr_from_reg = 1'b0;
    logic [31:0] psr_data = 32'h0;
    
    // Pipeline control inputs
    logic        stall = 1'b0;
    logic        flush = 1'b0;
    
    // Writeback unit outputs
    logic [3:0]  rf_write_addr;
    logic [31:0] rf_write_data;
    logic        rf_write_enable;
    logic [31:0] rf_pc_new;
    logic        rf_pc_write;
    logic [31:0] rf_cpsr_new;
    logic        rf_cpsr_write;
    logic [31:0] rf_spsr_new;
    logic        rf_spsr_write;
    logic [4:0]  rf_mode_new;
    logic        rf_mode_change;
    logic        pipeline_flush;
    logic        pipeline_stall;
    logic [31:0] exception_vector;
    logic        exception_taken;
    logic        instr_retire;
    logic [31:0] retire_pc;
    logic [31:0] retire_instr_count;
    logic [3:0]  forward_reg_addr;
    logic [31:0] forward_reg_data;
    logic        forward_valid;
    logic [31:0] current_cpsr;
    logic [4:0]  current_mode;
    logic        thumb_state;
    logic        irq_disabled;
    logic        fiq_disabled;
    
    // Test variables
    int test_count = 0;
    int test_passed = 0;
    
    // Instantiate writeback unit
    arm7tdmi_writeback u_writeback (
        .clk                  (clk),
        .rst_n                (rst_n),
        .instr_type           (instr_type),
        .alu_result           (alu_result),
        .load_data            (load_data),
        .pc_in                (pc_in),
        .memory_valid         (memory_valid),
        .memory_complete      (memory_complete),
        .reg_write_addr       (reg_write_addr),
        .reg_write_data       (reg_write_data),
        .reg_write_enable     (reg_write_enable),
        .cpsr_new             (cpsr_new),
        .cpsr_update          (cpsr_update),
        .set_flags            (set_flags),
        .alu_negative         (alu_negative),
        .alu_zero             (alu_zero),
        .alu_carry            (alu_carry),
        .alu_overflow         (alu_overflow),
        .branch_taken         (branch_taken),
        .branch_target        (branch_target),
        .branch_link          (branch_link),
        .data_abort           (data_abort),
        .abort_address        (abort_address),
        .alignment_fault      (alignment_fault),
        .undefined_instr      (undefined_instr),
        .swi_exception        (swi_exception),
        .irq_request          (irq_request),
        .fiq_request          (fiq_request),
        .psr_to_reg           (psr_to_reg),
        .psr_spsr             (psr_spsr),
        .psr_from_reg         (psr_from_reg),
        .psr_data             (psr_data),
        .rf_write_addr        (rf_write_addr),
        .rf_write_data        (rf_write_data),
        .rf_write_enable      (rf_write_enable),
        .rf_pc_new            (rf_pc_new),
        .rf_pc_write          (rf_pc_write),
        .rf_cpsr_new          (rf_cpsr_new),
        .rf_cpsr_write        (rf_cpsr_write),
        .rf_spsr_new          (rf_spsr_new),
        .rf_spsr_write        (rf_spsr_write),
        .rf_mode_new          (rf_mode_new),
        .rf_mode_change       (rf_mode_change),
        .pipeline_flush       (pipeline_flush),
        .pipeline_stall       (pipeline_stall),
        .exception_vector     (exception_vector),
        .exception_taken      (exception_taken),
        .instr_retire         (instr_retire),
        .retire_pc            (retire_pc),
        .retire_instr_count   (retire_instr_count),
        .forward_reg_addr     (forward_reg_addr),
        .forward_reg_data     (forward_reg_data),
        .forward_valid        (forward_valid),
        .current_cpsr         (current_cpsr),
        .current_mode         (current_mode),
        .thumb_state          (thumb_state),
        .irq_disabled         (irq_disabled),
        .fiq_disabled         (fiq_disabled),
        .stall                (stall),
        .flush                (flush)
    );
    
    task test_register_writeback(
        input string test_name,
        input logic [3:0] addr,
        input logic [31:0] data,
        input logic enable
    );
        test_count++;
        
        // Setup register writeback
        reg_write_addr = addr;
        reg_write_data = data;
        reg_write_enable = enable;
        instr_type = 4'b0000; // DATA_PROC
        memory_valid = 1'b1;
        memory_complete = 1'b1;
        
        @(posedge clk);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Input: R%d = 0x%08x (enable: %b)", addr, data, enable);
        $display("  Output: R%d = 0x%08x (enable: %b)", rf_write_addr, rf_write_data, rf_write_enable);
        $display("  Forward: R%d = 0x%08x (valid: %b)", forward_reg_addr, forward_reg_data, forward_valid);
        $display("  Retire: %b (PC: 0x%08x)", instr_retire, retire_pc);
        
        if (rf_write_enable == enable && rf_write_addr == addr && 
            forward_valid == enable && instr_retire) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    task test_cpsr_flag_update(
        input string test_name,
        input logic n, z, c, v,
        input logic should_update
    );
        test_count++;
        
        // Setup flag update
        alu_negative = n;
        alu_zero = z;
        alu_carry = c;
        alu_overflow = v;
        set_flags = should_update;
        instr_type = 4'b0000; // DATA_PROC
        cpsr_update = 1'b0;
        
        @(posedge clk);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Flags: N=%b Z=%b C=%b V=%b (update: %b)", n, z, c, v, should_update);
        $display("  CPSR Before: 0x%08x", 32'h0);
        $display("  CPSR After:  0x%08x", current_cpsr);
        $display("  CPSR Write: %b", rf_cpsr_write);
        
        if (rf_cpsr_write == should_update) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Reset for next test
        set_flags = 1'b0;
    endtask
    
    task test_branch_control(
        input string test_name,
        input logic taken,
        input logic [31:0] target,
        input logic link
    );
        test_count++;
        
        // Setup branch
        branch_taken = taken;
        branch_target = target;
        branch_link = link;
        instr_type = 4'b1001; // BRANCH
        
        @(posedge clk);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Branch: taken=%b target=0x%08x link=%b", taken, target, link);
        $display("  PC Write: %b (new PC: 0x%08x)", rf_pc_write, rf_pc_new);
        $display("  Pipeline Flush: %b", pipeline_flush);
        
        if (rf_pc_write == taken && pipeline_flush == taken) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Reset for next test
        branch_taken = 1'b0;
        branch_link = 1'b0;
    endtask
    
    task test_exception_handling(
        input string test_name,
        input logic abort,
        input logic undef,
        input logic swi,
        input logic [31:0] expected_vector
    );
        test_count++;
        
        // Setup exception
        data_abort = abort;
        undefined_instr = undef;
        swi_exception = swi;
        
        @(posedge clk);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Exceptions: abort=%b undef=%b swi=%b", abort, undef, swi);
        $display("  Exception Taken: %b", exception_taken);
        $display("  Exception Vector: 0x%08x (expected: 0x%08x)", exception_vector, expected_vector);
        $display("  Pipeline Flush: %b", pipeline_flush);
        $display("  Mode Change: %b (new mode: %d)", rf_mode_change, rf_mode_new);
        
        if (exception_taken && exception_vector == expected_vector && pipeline_flush) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Reset for next test
        data_abort = 1'b0;
        undefined_instr = 1'b0;
        swi_exception = 1'b0;
    endtask
    
    task test_load_writeback(
        input string test_name,
        input logic [31:0] loaded_data
    );
        test_count++;
        
        // Setup load instruction
        instr_type = 4'b0110; // SINGLE_DT
        load_data = loaded_data;
        reg_write_addr = 4'h5; // R5
        reg_write_enable = 1'b1;
        
        @(posedge clk);
        @(posedge clk);
        
        $display("Test %d: %s", test_count, test_name);
        $display("  Load Data: 0x%08x", loaded_data);
        $display("  Writeback: R%d = 0x%08x (enable: %b)", rf_write_addr, rf_write_data, rf_write_enable);
        
        if (rf_write_enable && rf_write_data == loaded_data) begin
            test_passed++;
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
        
        // Reset for next test
        instr_type = 4'b0000;
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("writeback_test.vcd");
        $dumpvars(0, writeback_test);
        
        // Reset sequence
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== ARM7TDMI Writeback Unit Test ===\n");
        
        // Test 1: Register writeback operations
        $display("=== Register Writeback Tests ===");
        test_register_writeback("Write R2 = 0x12345678", 4'h2, 32'h12345678, 1'b1);
        test_register_writeback("Write R5 = 0xDEADBEEF", 4'h5, 32'hDEADBEEF, 1'b1);
        test_register_writeback("Disabled write", 4'h3, 32'hCAFEBABE, 1'b0);
        
        // Test 2: CPSR flag updates
        $display("=== CPSR Flag Update Tests ===");
        test_cpsr_flag_update("Set carry flag", 1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
        test_cpsr_flag_update("Set zero flag", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        test_cpsr_flag_update("No flag update", 1'b1, 1'b1, 1'b1, 1'b1, 1'b0);
        
        // Test 3: Branch control
        $display("=== Branch Control Tests ===");
        test_branch_control("Branch taken", 1'b1, 32'h2000, 1'b0);
        test_branch_control("Branch with link", 1'b1, 32'h3000, 1'b1);
        test_branch_control("Branch not taken", 1'b0, 32'h4000, 1'b0);
        
        // Test 4: Exception handling
        $display("=== Exception Handling Tests ===");
        test_exception_handling("Data abort", 1'b1, 1'b0, 1'b0, 32'h00000010);  
        test_exception_handling("Undefined instruction", 1'b0, 1'b1, 1'b0, 32'h00000004);
        test_exception_handling("Software interrupt", 1'b0, 1'b0, 1'b1, 32'h00000008);
        
        // Test 5: Load data writeback
        $display("=== Load Data Writeback Tests ===");
        test_load_writeback("Load word data", 32'hFEEDFACE);
        
        // Test 6: Processor state
        $display("=== Processor State Test ===");
        $display("Current Mode: %d (expected: 19 = Supervisor)", current_mode);
        $display("Thumb State: %b", thumb_state);
        $display("IRQ Disabled: %b", irq_disabled);
        $display("FIQ Disabled: %b", fiq_disabled);
        $display("Instruction Count: %d", retire_instr_count);
        
        if (current_mode == 5'd19 && !thumb_state && irq_disabled && fiq_disabled) begin
            test_passed++;
            $display("✅ PASS - Processor state correct");
        end else begin
            $display("❌ FAIL - Processor state incorrect");
        end
        test_count++;
        
        // Final results
        repeat(5) @(posedge clk);
        $display("=== Test Results ===");
        $display("Tests Run: %d", test_count);
        $display("Tests Passed: %d", test_passed);
        $display("Pass Rate: %.1f%%", (test_passed * 100.0) / test_count);
        
        if (test_passed == test_count) begin
            $display("✅ ALL WRITEBACK TESTS PASSED!");
        end else begin
            $display("❌ SOME WRITEBACK TESTS FAILED");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule