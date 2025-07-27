// ARM7TDMI Package
// Common types and definitions

package arm7tdmi_pkg;

    // Coprocessor operation types
    typedef enum logic [2:0] {
        CP_CDP = 3'b000,   // Coprocessor data processing
        CP_LDC = 3'b001,   // Load coprocessor
        CP_STC = 3'b010,   // Store coprocessor
        CP_MRC = 3'b100,   // Move from coprocessor to ARM register
        CP_MCR = 3'b110    // Move from ARM register to coprocessor
    } cp_op_t;

endpackage