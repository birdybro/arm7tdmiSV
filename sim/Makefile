# Makefile for ARM7TDMI SystemVerilog simulation

# Simulator
SIM = iverilog
SIMFLAGS = -g2012 -I../rtl

# Source files
RTL_DIR = ../rtl
SIM_DIR = .

RTL_SOURCES = $(RTL_DIR)/arm7tdmi_defines.sv \
              $(RTL_DIR)/arm7tdmi_fetch.sv \
              $(RTL_DIR)/arm7tdmi_decode.sv \
              $(RTL_DIR)/arm7tdmi_regfile.sv \
              $(RTL_DIR)/arm7tdmi_alu.sv \
              $(RTL_DIR)/arm7tdmi_multiply.sv \
              $(RTL_DIR)/arm7tdmi_shifter.sv \
              $(RTL_DIR)/arm7tdmi_block_dt.sv \
              $(RTL_DIR)/arm7tdmi_exception.sv \
              $(RTL_DIR)/arm7tdmi_top.sv

TB_SOURCES = $(SIM_DIR)/arm7tdmi_tb.sv

# Output files
VVP_FILE = arm7tdmi_tb.vvp
VCD_FILE = arm7tdmi_tb.vcd

# Default target
all: simulate

# Simple test
simple: simple_tb.vvp
	vvp simple_tb.vvp

simple_tb.vvp: $(RTL_SOURCES) simple_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) simple_tb.sv

# ARM instruction test
instr: arm_instr_tb.vvp
	vvp arm_instr_tb.vvp

arm_instr_tb.vvp: $(RTL_SOURCES) arm_instr_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) arm_instr_tb.sv

# Complex ARM instruction test
complex: complex_arm_tb.vvp
	vvp complex_arm_tb.vvp

complex_arm_tb.vvp: $(RTL_SOURCES) complex_arm_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) complex_arm_tb.sv

# Multiply unit test
multiply: multiply_tb.vvp
	vvp multiply_tb.vvp

multiply_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_multiply.sv multiply_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_multiply.sv multiply_tb.sv

# PSR transfer test
psr: psr_tb.vvp
	vvp psr_tb.vvp

psr_tb.vvp: $(RTL_SOURCES) psr_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) psr_tb.sv

# PSR decode test
psr_decode: psr_decode_tb.vvp
	vvp psr_decode_tb.vvp

psr_decode_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv psr_decode_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv psr_decode_tb.sv

# Complete multiply test
multiply_complete: multiply_complete_tb.vvp
	vvp multiply_complete_tb.vvp

multiply_complete_tb.vvp: $(RTL_SOURCES) multiply_complete_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) multiply_complete_tb.sv

# Coprocessor test
coprocessor: coprocessor_tb.vvp
	vvp coprocessor_tb.vvp

coprocessor_tb.vvp: $(RTL_SOURCES) coprocessor_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) coprocessor_tb.sv

# Coprocessor decode test
coprocessor_decode: coprocessor_decode_tb.vvp
	vvp coprocessor_decode_tb.vvp

coprocessor_decode_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv coprocessor_decode_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv coprocessor_decode_tb.sv

# Thumb decode test
thumb_decode: thumb_decode_tb.vvp
	vvp thumb_decode_tb.vvp

thumb_decode_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv thumb_decode_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv thumb_decode_tb.sv

# Thumb execution test
thumb_exec: thumb_exec_tb.vvp
	vvp thumb_exec_tb.vvp

thumb_exec_tb.vvp: $(RTL_SOURCES) thumb_exec_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) thumb_exec_tb.sv

# Shifter test
shifter_test: shifter_test_tb.vvp
	vvp shifter_test_tb.vvp

shifter_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_shifter.sv shifter_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_shifter.sv shifter_test_tb.sv

# Addressing mode test
addressing_test: addressing_test_tb.vvp
	vvp addressing_test_tb.vvp

addressing_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_shifter.sv addressing_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_shifter.sv addressing_test_tb.sv

# Completeness verification test
completeness_test: completeness_test_tb.vvp
	vvp completeness_test_tb.vvp

completeness_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv completeness_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv completeness_test_tb.sv

# Debug decode test
debug_decode: debug_decode_tb.vvp
	vvp debug_decode_tb.vvp

debug_decode_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv debug_decode_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv debug_decode_tb.sv

# Thumb BL instruction test
thumb_bl_test: thumb_bl_test_tb.vvp
	vvp thumb_bl_test_tb.vvp

thumb_bl_test_tb.vvp: $(RTL_SOURCES) thumb_bl_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) thumb_bl_test_tb.sv

# Basic execution test
basic_execution: basic_execution_tb.vvp
	vvp basic_execution_tb.vvp

basic_execution_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv basic_execution_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv basic_execution_tb.sv

# Register file and flag validation test
regfile_flag_test: regfile_flag_test_tb.vvp
	vvp regfile_flag_test_tb.vvp

regfile_flag_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_regfile.sv regfile_flag_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_regfile.sv regfile_flag_test_tb.sv

# Memory operations test
memory_test: memory_test_tb.vvp
	vvp memory_test_tb.vvp

memory_test_tb.vvp: $(RTL_SOURCES) memory_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) memory_test_tb.sv

# Memory interface test
memory_interface_test: memory_interface_test_tb.vvp
	vvp memory_interface_test_tb.vvp

memory_interface_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv memory_interface_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv memory_interface_test_tb.sv

# Halfword operations test
halfword_test: halfword_test_tb.vvp
	vvp halfword_test_tb.vvp

halfword_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv halfword_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv halfword_test_tb.sv

# Block data transfer test
block_dt_test: block_dt_test_tb.vvp
	vvp block_dt_test_tb.vvp

block_dt_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_block_dt.sv block_dt_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv $(RTL_DIR)/arm7tdmi_block_dt.sv block_dt_test_tb.sv

# Swap operations test
swap_test: swap_test_tb.vvp
	vvp swap_test_tb.vvp

swap_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv swap_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv swap_test_tb.sv

# Multiply execution test
multiply_exec_test: multiply_exec_test_tb.vvp
	vvp multiply_exec_test_tb.vvp

multiply_exec_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv multiply_exec_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv multiply_exec_test_tb.sv

# Branch execution test
branch_exec_test: branch_exec_test_tb.vvp
	vvp branch_exec_test_tb.vvp

branch_exec_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv branch_exec_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv branch_exec_test_tb.sv

# Enhanced coprocessor test
coprocessor_enhanced_test: coprocessor_enhanced_test_tb.vvp
	vvp coprocessor_enhanced_test_tb.vvp

coprocessor_enhanced_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv coprocessor_enhanced_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv coprocessor_enhanced_test_tb.sv

# Exception handling test
exception_handling_test: exception_handling_test_tb.vvp
	vvp exception_handling_test_tb.vvp

exception_handling_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv exception_handling_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv exception_handling_test_tb.sv

# Condition codes test
condition_codes_test: condition_codes_test_tb.vvp
	vvp condition_codes_test_tb.vvp

condition_codes_test_tb.vvp: $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv condition_codes_test_tb.sv
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_DIR)/arm7tdmi_defines.sv $(RTL_DIR)/arm7tdmi_decode.sv condition_codes_test_tb.sv

# Compile the design
compile: $(VVP_FILE)

$(VVP_FILE): $(RTL_SOURCES) $(TB_SOURCES)
	$(SIM) $(SIMFLAGS) -o $@ $(RTL_SOURCES) $(TB_SOURCES)

# Run simulation
simulate: $(VVP_FILE)
	vvp $(VVP_FILE)

# View waveforms (requires GTKWave)
wave: $(VCD_FILE)
	gtkwave $(VCD_FILE) &

# Clean generated files
clean:
	rm -f $(VVP_FILE) $(VCD_FILE)

# Help
help:
	@echo "Available targets:"
	@echo "  all       - Compile and simulate (default)"
	@echo "  compile   - Compile the design"
	@echo "  simulate  - Run simulation"
	@echo "  wave      - View waveforms with GTKWave"
	@echo "  clean     - Remove generated files"
	@echo "  help      - Show this help"

.PHONY: all compile simulate wave clean help