# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ARM7TDMI processor simulation written in SystemVerilog. The project aims for:
- Compatibility with MiSTer FPGA platform
- Full accuracy in simulation
- Development of simulation tools

## Project Structure

- `rtl/` - SystemVerilog design files for the ARM7TDMI core
- `sim/` - Simulation files including testbenches and simulation scripts
- `doc/` - Technical documentation for the ARM7TDMI processor

## Implementation Status

The ARM7TDMI core implementation is now comprehensive with extensive validation and includes:

### Core Pipeline
- 5-stage pipeline (Fetch, Decode, Execute, Memory, Writeback)
- ARM instruction set decoding and execution
- Complete condition code evaluation for all 16 ARM conditions (100% validated)

### Instruction Set Coverage (Comprehensive Testing Completed)
- **Data Processing Instructions**: All ALU operations (ADD, SUB, AND, OR, XOR, etc.) with register-controlled shifts
- **Advanced Shifter**: Register-controlled shifts and RRX (Rotate Right Extended) operation
- **Memory Instructions**: Load/Store (LDR, STR) with enhanced addressing modes including scaled register offsets
- **Halfword Data Transfer**: LDRH, STRH, LDRSB, LDRSH (100% pass rate - 8/8 tests)
- **Block Data Transfer**: LDM/STM (Load/Store Multiple) with state machine implementation
- **Single Data Swap**: SWP, SWPB atomic operations (100% pass rate - 7/7 tests)
- **Branch Instructions**: B, BL, BX with conditional execution (100% pass rate - 17/17 tests)
- **Multiply Instructions**: MUL, MLA with execution validation (100% pass rate - 13/13 tests)
- **Branch Exchange**: BX for ARM/Thumb mode switching
- **PSR Transfer**: MRS/MSR for CPSR and SPSR access
- **Coprocessor Instructions**: Enhanced CP15 interface with system control registers
- **Exception Handling**: Complete priority-based exception processing with vector generation
- **Condition Codes**: All 16 ARM condition codes with complete evaluation logic (100% pass rate - 38/38 tests)
- **Thumb Instructions**: Complete Thumb instruction execution framework
- **Thumb BL**: Two-part Branch with Link sequence with proper state tracking

### Architecture Components
- **Register File**: Full register banking for different processor modes
- **ALU**: Complete arithmetic and logic operations with flag setting
- **Advanced Shifter**: All ARM shift types (LSL, LSR, ASR, ROR, RRX) with register-controlled operation
- **Multiply Unit**: Single and long multiply variants with accumulation
- **Block Transfer Unit**: Multi-register load/store operations
- **Exception Handler**: Priority-based exception processing
- **Memory Interface**: Unified memory interface with byte enables and enhanced addressing modes
- **Coprocessor Interface**: Extensible framework with basic CP15 implementation
- **Thumb Support**: Complete Thumb instruction decode and execution with ARM/Thumb interworking

### Verification Status
- **19 comprehensive test suites** covering all major instruction categories
- **100% pass rates achieved** across all functional test categories:
  - Halfword operations: 8/8 tests passed
  - Swap operations: 7/7 tests passed  
  - Multiply operations: 13/13 tests passed
  - Branch execution: 17/17 tests passed
  - Condition codes: 38/38 tests passed
- Block data transfer decode validation complete
- Exception handling with complete priority logic
- Enhanced coprocessor interface with CP15 registers
- Memory operation testing with advanced addressing modes
- PSR transfer instruction testing
- Shifter operation testing (all shift types including RRX)
- Thumb BL instruction sequence validation

## Testing and Simulation

The project uses Icarus Verilog for simulation with comprehensive test coverage:

### Core Test Targets
- `make simulate` - Basic processor test
- `make multiply` - Multiply unit specific tests
- `make complex` - Complex instruction sequences
- `make simple` - Simple instruction tests

### Advanced Test Targets
- `make halfword_test` - Halfword memory operations (100% pass rate)
- `make block_dt_test` - Block data transfer operations
- `make swap_test` - Atomic swap operations (100% pass rate)
- `make multiply_exec_test` - Multiply execution validation (100% pass rate)
- `make branch_exec_test` - Branch execution and PC updates (100% pass rate)
- `make condition_codes_test` - All 16 ARM condition codes (100% pass rate)
- `make coprocessor_enhanced_test` - Enhanced coprocessor with CP15
- `make exception_handling_test` - Exception handling and priority

### Specialized Tests
- `make psr_decode` - PSR transfer instruction decode tests
- `make coprocessor_decode` - Coprocessor instruction decode tests
- `make thumb_exec` - Thumb instruction execution verification
- `make thumb_bl_test` - Thumb BL instruction sequence testing
- `make shifter_test` - Advanced shifter operation verification
- `make addressing_test` - Memory addressing mode validation
- `make completeness_test` - Comprehensive instruction set coverage analysis

## Code Validation

When generating or modifying ARM7TDMI SystemVerilog code, always reference the ARM7TDMI specification to ensure accuracy and compliance with the processor behavior, timing, and implementation details.

## Development Guidelines

- Maintain compatibility with Icarus Verilog simulator
- Follow ARM7TDMI architectural specifications exactly
- Ensure all instructions support conditional execution
- Test with comprehensive instruction sequences
- Verify exception handling priority and behavior