# ARM7TDMI SystemVerilog Implementation

A comprehensive ARM7TDMI processor simulation written in SystemVerilog, developed with Claude Code.

## Overview

This project implements a fully functional ARM7TDMI processor core in SystemVerilog, targeting compatibility with MiSTer FPGA platform while maintaining full architectural accuracy.

## Features

### Complete ARM Instruction Set
- **Data Processing**: All ALU operations (ADD, SUB, AND, OR, XOR, etc.) with immediate and register operands
- **Memory Operations**: Load/Store instructions (LDR, STR) with byte/word/halfword variants
- **Branch Instructions**: B, BL with conditional execution and link register support
- **Multiply Instructions**: Complete multiply family (MUL, MLA, UMULL, SMULL, UMLAL, SMLAL)
- **Block Data Transfer**: LDM/STM instructions for efficient stack and register block operations
- **Halfword Transfer**: LDRH, STRH, LDRSB, LDRSH with sign extension
- **Atomic Operations**: SWP, SWPB single data swap instructions
- **Mode Switching**: BX instruction for ARM/Thumb mode transitions
- **PSR Transfer**: MRS/MSR instructions for accessing CPSR and SPSR registers
- **Coprocessor Interface**: Complete framework supporting CDP, LDC, STC, MCR, MRC operations
- **Exception Handling**: Full interrupt and exception processing (IRQ, FIQ, SWI, Undefined, Abort)

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

## Implementation Status

✅ **Complete**: Core ARM instruction set implementation
✅ **Complete**: Register banking and processor modes  
✅ **Complete**: Exception handling and interrupts
✅ **Complete**: Memory interface and data transfers
✅ **Complete**: Multiply instruction variants (MUL, MLA, UMULL, SMULL, UMLAL, SMLAL)
✅ **Complete**: Block data transfers (LDM/STM)
✅ **Complete**: Atomic operations (SWP/SWPB)
✅ **Complete**: Branch and link operations
✅ **Complete**: PSR transfer instructions (MRS/MSR)
✅ **Complete**: Coprocessor instruction framework (CDP, LDC, STC, MCR, MRC)

🚧 **Future Work**:
- Thumb instruction set implementation
- Cache and MMU simulation  
- Performance optimization
- Additional coprocessor implementations

## Technical Specifications

- **Architecture**: ARM7TDMI (32-bit RISC)
- **Pipeline**: 5-stage (Fetch, Decode, Execute, Memory, Writeback)
- **Instruction Set**: ARM v4T (ARM instructions implemented, Thumb planned)
- **Registers**: 37 registers including banked registers for different modes
- **Exceptions**: 7 exception types with proper priority handling
- **Memory**: Unified 32-bit address space with byte/halfword/word access

## Verification

The implementation includes comprehensive testbenches covering:
- Individual instruction functionality
- Pipeline operation and hazard handling
- Exception processing and recovery
- Memory interface compliance
- Register banking correctness
- Conditional execution validation

## Primary Goals

- **MiSTer FPGA Compatibility**: Designed for FPGA implementation
- **Full Accuracy**: Cycle-accurate ARM7TDMI behavior
- **Comprehensive Testing**: Extensive verification suite
- **Educational Value**: Clear, well-documented SystemVerilog implementation

## License

This project is developed as an educational and research implementation of the ARM7TDMI architecture.

---

*Developed with Claude Code - AI-assisted hardware development*