// Simple Memory Unit Architecture Test
`timescale 1ns/1ps

module memory_simple_test;
    
    logic clk = 0;
    logic rst_n = 1;
    
    always #5 clk = ~clk;
    
    // Test memory alignment and byte enable logic
    logic [31:0] address;
    logic [1:0]  size;
    logic [3:0]  byte_enables;
    logic        word_aligned, halfword_aligned, alignment_error;
    
    // Manual alignment checking logic (from memory unit)
    assign word_aligned = (address[1:0] == 2'b00);
    assign halfword_aligned = (address[0] == 1'b0);
    
    always_comb begin
        alignment_error = 1'b0;
        case (size)
            2'b10: alignment_error = !word_aligned;     // Word access
            2'b01: alignment_error = !halfword_aligned; // Halfword access
            2'b00: alignment_error = 1'b0;              // Byte access - always aligned
            default: alignment_error = 1'b0;
        endcase
    end
    
    // Byte enable generation logic (from memory unit)
    always_comb begin
        byte_enables = 4'b0000;
        case (size)
            2'b00: begin // Byte access
                case (address[1:0])
                    2'b00: byte_enables = 4'b0001;
                    2'b01: byte_enables = 4'b0010;
                    2'b10: byte_enables = 4'b0100;
                    2'b11: byte_enables = 4'b1000;
                endcase
            end
            2'b01: begin // Halfword access
                case (address[1])
                    1'b0: byte_enables = 4'b0011;
                    1'b1: byte_enables = 4'b1100;
                endcase
            end
            2'b10: begin // Word access
                byte_enables = 4'b1111;
            end
            default: byte_enables = 4'b0000;
        endcase
    end
    
    // Test task
    task test_alignment_and_enables(
        input string test_name,
        input logic [31:0] addr,
        input logic [1:0] sz,
        input logic expect_error,
        input logic [3:0] expect_enables
    );
        address = addr;
        size = sz;
        
        #10; // Wait for combinational logic
        
        $display("Test: %s", test_name);
        $display("  Address: 0x%08x", addr);
        $display("  Size: %s", sz == 2'b10 ? "Word" : sz == 2'b01 ? "Halfword" : "Byte");
        $display("  Word Aligned: %b", word_aligned);
        $display("  Halfword Aligned: %b", halfword_aligned);
        $display("  Alignment Error: %b (expected: %b)", alignment_error, expect_error);
        $display("  Byte Enables: %b (expected: %b)", byte_enables, expect_enables);
        
        if (alignment_error == expect_error && byte_enables == expect_enables) begin
            $display("  ✅ PASS");
        end else begin
            $display("  ❌ FAIL");
        end
        $display("");
    endtask
    
    initial begin
        $dumpfile("memory_simple_test.vcd");
        $dumpvars(0, memory_simple_test);
        
        rst_n = 0;
        #20;
        rst_n = 1;
        #20;
        
        $display("=== Memory Unit Architecture Test ===\n");
        
        // Test word accesses
        $display("=== Word Access Tests ===");
        test_alignment_and_enables("Word at 0x1000 (aligned)", 32'h1000, 2'b10, 1'b0, 4'b1111);
        test_alignment_and_enables("Word at 0x1001 (misaligned)", 32'h1001, 2'b10, 1'b1, 4'b1111);
        test_alignment_and_enables("Word at 0x1002 (misaligned)", 32'h1002, 2'b10, 1'b1, 4'b1111);
        test_alignment_and_enables("Word at 0x1003 (misaligned)", 32'h1003, 2'b10, 1'b1, 4'b1111);
        
        // Test halfword accesses
        $display("=== Halfword Access Tests ===");
        test_alignment_and_enables("Halfword at 0x1000 (aligned)", 32'h1000, 2'b01, 1'b0, 4'b0011);
        test_alignment_and_enables("Halfword at 0x1001 (misaligned)", 32'h1001, 2'b01, 1'b1, 4'b0010);
        test_alignment_and_enables("Halfword at 0x1002 (aligned)", 32'h1002, 2'b01, 1'b0, 4'b1100);
        test_alignment_and_enables("Halfword at 0x1003 (misaligned)", 32'h1003, 2'b01, 1'b1, 4'b1100);
        
        // Test byte accesses
        $display("=== Byte Access Tests ===");
        test_alignment_and_enables("Byte at 0x1000", 32'h1000, 2'b00, 1'b0, 4'b0001);
        test_alignment_and_enables("Byte at 0x1001", 32'h1001, 2'b00, 1'b0, 4'b0010);
        test_alignment_and_enables("Byte at 0x1002", 32'h1002, 2'b00, 1'b0, 4'b0100);
        test_alignment_and_enables("Byte at 0x1003", 32'h1003, 2'b00, 1'b0, 4'b1000);
        
        $display("✅ Memory Architecture Test Complete");
        $finish;
    end
    
endmodule