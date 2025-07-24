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