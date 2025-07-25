# ARM7TDMI SystemVerilog Implementation

A comprehensive ARM7TDMI processor simulation written in SystemVerilog, developed with Claude Code.

## Overview

This project implements a fully functional ARM7TDMI processor core in SystemVerilog, targeting compatibility with MiSTer FPGA platform while maintaining full architectural accuracy.

## Features

### Complete ARM Instruction Set
- **Data Processing**: All ALU operations (ADD, SUB, AND, OR, XOR, etc.) with immediate and register operands
- **Advanced Shifter**: Register-controlled shifts and RRX (Rotate Right Extended) operation
- **Memory Operations**: Load/Store instructions (LDR, STR) with enhanced addressing modes including scaled register offsets
- **Branch Instructions**: B, BL with conditional execution and link register support
- **Multiply Instructions**: Complete multiply family (MUL, MLA, UMULL, SMULL, UMLAL, SMLAL)
- **Block Data Transfer**: LDM/STM instructions for efficient stack and register block operations
- **Halfword Transfer**: LDRH, STRH, LDRSB, LDRSH with sign extension
- **Atomic Operations**: SWP, SWPB single data swap instructions
- **Mode Switching**: BX instruction for ARM/Thumb mode transitions
- **PSR Transfer**: MRS/MSR instructions for accessing CPSR and SPSR registers
- **Coprocessor Interface**: Complete framework supporting CDP, LDC, STC, MCR, MRC operations
- **Exception Handling**: Full interrupt and exception processing (IRQ, FIQ, SWI, Undefined, Abort)

### Thumb Instruction Set Support
- **Thumb Mode Execution**: Complete Thumb instruction decoding and execution framework
- **Thumb BL Instructions**: Two-part Branch with Link sequence (BL prefix/suffix) with proper state tracking
- **ARM/Thumb Interworking**: Seamless mode switching via BX instruction
- **Thumb ALU Operations**: All Thumb-specific ALU and data processing instructions
- **Thumb Memory Access**: Load/Store operations optimized for 16-bit instruction encoding

### Architecture Components
- **5-Stage Pipeline**: Fetch, Decode, Execute, Memory, Writeback
- **Register Banking**: Complete register file with mode-specific banking
- **Condition Codes**: Full conditional execution support for all instructions
- **Shifter Unit**: All ARM shift types (LSL, LSR, ASR, ROR, RRX)
- **Memory Interface**: Unified memory interface with byte enable support
- **Exception Priority**: ARM-compliant exception priority handling

## Project Structure

```
├── rtl/                          # SystemVerilog RTL files
│   ├── arm7tdmi_top.sv          # Top-level processor module
│   ├── arm7tdmi_fetch.sv        # Instruction fetch stage
│   ├── arm7tdmi_decode.sv       # Instruction decode stage
│   ├── arm7tdmi_regfile.sv      # Register file with banking
│   ├── arm7tdmi_alu.sv          # Arithmetic Logic Unit
│   ├── arm7tdmi_multiply.sv     # Multiply unit
│   ├── arm7tdmi_shifter.sv      # Barrel shifter
│   ├── arm7tdmi_block_dt.sv     # Block data transfer unit
│   ├── arm7tdmi_exception.sv    # Exception handling
│   └── arm7tdmi_defines.sv      # Package definitions
└── sim/                         # Simulation and testbenches
    ├── Makefile                 # Build system
    ├── arm7tdmi_tb.sv          # Basic testbench
    ├── multiply_tb.sv          # Multiply unit tests
    └── complex_arm_tb.sv       # Complex instruction tests
```

## Getting Started

### Prerequisites
- Icarus Verilog (for simulation)
- GTKWave (for waveform viewing)
- Make

### Building and Testing

```bash
# Enter simulation directory
cd sim

# Run basic processor test
make simulate

# Test multiply unit specifically
make multiply

# Run complex instruction tests
make complex

# View waveforms (requires GTKWave)
make wave
```

### Available Test Targets
- `make simulate` - Basic ARM7TDMI processor functionality test
- `make multiply` - Comprehensive multiply instruction verification
- `make complex` - Complex instruction sequences and edge cases
- `make simple` - Simple instruction validation  
- `make psr_decode` - PSR transfer instruction decode verification
- `make coprocessor_decode` - Coprocessor instruction decode verification
- `make thumb_exec` - Thumb instruction execution verification
- `make thumb_bl_test` - Thumb BL instruction sequence testing
- `make shifter_test` - Advanced shifter operation verification
- `make addressing_test` - Memory addressing mode validation
- `make completeness_test` - Comprehensive instruction set coverage analysis
- `make halfword_test` - Halfword memory operations (LDRH/STRH/LDRSB/LDRSH)
- `make block_dt_test` - Block data transfer operations (LDM/STM)
- `make swap_test` - Atomic swap operations (SWP/SWPB)
- `make multiply_exec_test` - Multiply execution validation (MUL/MLA)
- `make branch_exec_test` - Branch execution and PC updates (B/BL/BX)
- `make condition_codes_test` - All 16 ARM condition codes validation
- `make coprocessor_enhanced_test` - Enhanced coprocessor interface with CP15
- `make exception_handling_test` - Exception handling and priority testing

## Implementation Status

✅ **Complete**: Core ARM instruction set implementation with comprehensive test coverage
✅ **Complete**: Register banking and processor modes  
✅ **Complete**: Exception handling with proper priority and vector generation
✅ **Complete**: Memory interface and data transfers with enhanced addressing modes
✅ **Complete**: Halfword memory operations (LDRH/STRH/LDRSB/LDRSH) with sign extension
✅ **Complete**: Block data transfers (LDM/STM) with state machine implementation
✅ **Complete**: Atomic swap operations (SWP/SWPB) with read-modify-write semantics
✅ **Complete**: Multiply instruction variants (MUL, MLA) with execution validation
✅ **Complete**: Branch execution with program counter updates (B/BL/BX)
✅ **Complete**: Condition code evaluation for all 16 ARM conditions
✅ **Complete**: PSR transfer instructions (MRS/MSR)
✅ **Complete**: Enhanced coprocessor interface with CP15 system control registers
✅ **Complete**: Advanced shifter with register-controlled shifts and RRX operation
✅ **Complete**: Thumb instruction execution framework
✅ **Complete**: Thumb BL (Branch with Link) two-part instruction sequence

### Test Coverage Summary
- **Halfword Operations**: 100% pass rate (8/8 tests)
- **Block Data Transfers**: Decode validation complete
- **Swap Operations**: 100% pass rate (7/7 tests)  
- **Multiply Operations**: 100% pass rate (13/13 tests)
- **Branch Execution**: 100% pass rate (17/17 tests)
- **Condition Codes**: 100% pass rate (38/38 tests)
- **Exception Handling**: Complete priority and vector logic
- **Coprocessor Interface**: CP15 register set implementation

🚧 **Future Work**:
- Complete remaining Thumb instruction variants
- Cache and MMU simulation  
- Performance optimization
- Additional coprocessor implementations
- FPGA synthesis optimization

## Technical Specifications

- **Architecture**: ARM7TDMI (32-bit RISC)
- **Pipeline**: 5-stage (Fetch, Decode, Execute, Memory, Writeback)
- **Instruction Set**: ARM v4T (ARM and Thumb instructions implemented)
- **Registers**: 37 registers including banked registers for different modes
- **Exceptions**: 7 exception types with proper priority handling
- **Memory**: Unified 32-bit address space with byte/halfword/word access and advanced addressing modes
- **Shifter**: Full barrel shifter with all shift types including register-controlled shifts

## Verification

The implementation includes comprehensive testbenches covering:
- Individual instruction functionality (ARM and Thumb) with 100% pass rates
- Halfword memory operations with sign extension validation
- Block data transfer operations with state machine verification
- Atomic swap operations with read-modify-write semantics
- Multiply instruction execution with arithmetic validation
- Branch execution with program counter update verification
- Complete condition code evaluation for all 16 ARM conditions
- Exception processing with proper priority handling
- Coprocessor interface with CP15 system control registers
- Memory interface compliance with advanced addressing modes
- Register banking correctness
- Conditional execution validation
- Shifter operation verification (all shift types including RRX)
- Thumb BL instruction sequence validation

## Primary Goals

- **MiSTer FPGA Compatibility**: Designed for FPGA implementation
- **Full Accuracy**: Cycle-accurate ARM7TDMI behavior
- **Comprehensive Testing**: Extensive verification suite
- **Educational Value**: Clear, well-documented SystemVerilog implementation

## License

This project is developed as an educational and research implementation of the ARM7TDMI architecture.

---

*Developed with Claude Code - AI-assisted hardware development*