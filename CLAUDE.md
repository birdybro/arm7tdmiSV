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

The ARM7TDMI core implementation is now comprehensive and includes:

### Core Pipeline
- 5-stage pipeline (Fetch, Decode, Execute, Memory, Writeback)
- ARM instruction set decoding and execution
- Condition code evaluation for all instructions

### Instruction Set Coverage (71.4% verified)
- **Data Processing Instructions**: All ALU operations (ADD, SUB, AND, OR, XOR, etc.) with register-controlled shifts
- **Advanced Shifter**: Register-controlled shifts and RRX (Rotate Right Extended) operation
- **Memory Instructions**: Load/Store (LDR, STR) with enhanced addressing modes including scaled register offsets
- **Branch Instructions**: B, BL with conditional execution
- **Multiply Instructions**: MUL, MLA, UMULL, SMULL, UMLAL, SMLAL
- **Block Data Transfer**: LDM/STM (Load/Store Multiple) for stack operations
- **Halfword Data Transfer**: LDRH, STRH, LDRSB, LDRSH
- **Single Data Swap**: SWP, SWPB atomic operations
- **Branch Exchange**: BX for ARM/Thumb mode switching
- **PSR Transfer**: MRS/MSR for CPSR and SPSR access
- **Coprocessor Instructions**: CDP, LDC, STC, MCR, MRC with CP15 basic support
- **Exception Handling**: SWI, IRQ, FIQ, Undefined, Abort exceptions
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

### Verification
- Multiple testbenches for different instruction categories (ARM and Thumb)
- Comprehensive multiply unit verification
- Memory operation testing with advanced addressing modes
- Exception flow validation
- PSR transfer instruction testing
- Coprocessor instruction decode verification
- Shifter operation testing (all shift types including RRX)
- Thumb BL instruction sequence validation
- Instruction set completeness analysis (71.4% coverage achieved)

## Testing and Simulation

The project uses Icarus Verilog for simulation with the following test targets:
- `make simulate` - Basic processor test
- `make multiply` - Multiply unit specific tests
- `make complex` - Complex instruction sequences
- `make simple` - Simple instruction tests
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