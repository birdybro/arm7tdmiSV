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

## Implementation Status

The ARM7TDMI core implementation is now comprehensive and includes:

### Core Pipeline
- 5-stage pipeline (Fetch, Decode, Execute, Memory, Writeback)
- ARM instruction set decoding and execution
- Condition code evaluation for all instructions

### Instruction Set Coverage
- **Data Processing Instructions**: All ALU operations (ADD, SUB, AND, OR, XOR, etc.)
- **Memory Instructions**: Load/Store (LDR, STR) with byte/word variants
- **Branch Instructions**: B, BL with conditional execution
- **Multiply Instructions**: MUL, MLA, UMULL, SMULL, UMLAL, SMLAL
- **Block Data Transfer**: LDM/STM (Load/Store Multiple) for stack operations
- **Halfword Data Transfer**: LDRH, STRH, LDRSB, LDRSH
- **Single Data Swap**: SWP, SWPB atomic operations
- **Branch Exchange**: BX for ARM/Thumb mode switching
- **Exception Handling**: SWI, IRQ, FIQ, Undefined, Abort exceptions

### Architecture Components
- **Register File**: Full register banking for different processor modes
- **ALU**: Complete arithmetic and logic operations with flag setting
- **Shifter**: All ARM shift types (LSL, LSR, ASR, ROR, RRX)
- **Multiply Unit**: Single and long multiply variants with accumulation
- **Block Transfer Unit**: Multi-register load/store operations
- **Exception Handler**: Priority-based exception processing
- **Memory Interface**: Unified memory interface with byte enables

### Verification
- Multiple testbenches for different instruction categories
- Comprehensive multiply unit verification
- Memory operation testing
- Exception flow validation

## Testing and Simulation

The project uses Icarus Verilog for simulation with the following test targets:
- `make simulate` - Basic processor test
- `make multiply` - Multiply unit specific tests
- `make complex` - Complex instruction sequences
- `make simple` - Simple instruction tests

## Code Validation

When generating or modifying ARM7TDMI SystemVerilog code, always reference the ARM7TDMI specification to ensure accuracy and compliance with the processor behavior, timing, and implementation details.

## Development Guidelines

- Maintain compatibility with Icarus Verilog simulator
- Follow ARM7TDMI architectural specifications exactly
- Ensure all instructions support conditional execution
- Test with comprehensive instruction sequences
- Verify exception handling priority and behavior