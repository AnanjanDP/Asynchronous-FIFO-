# =============================================================================
# Makefile for Asynchronous FIFO Verification Suite
# Tools: Icarus Verilog 12.0+, GTKWave
# =============================================================================

RTL_SRCS = rtl/sync_2ff.sv \
           rtl/fifo_mem.sv \
           rtl/rptr_empty.sv \
           rtl/wptr_full.sv \
           rtl/async_fifo.sv

TB_BASIC    = tb/tb_basic.sv
TB_ADVANCED = tb/tb_advanced.sv

IVL_FLAGS = -g2012 -Wall -I rtl

.PHONY: all basic advanced waves clean help

all: basic advanced

# Run 6-scenario directed smoke test
basic:
	@mkdir -p sim waves
	iverilog $(IVL_FLAGS) -o sim/tb_basic.vvp $(RTL_SRCS) $(TB_BASIC)
	vvp sim/tb_basic.vvp

# Run 15-scenario advanced stress verification test
advanced:
	@mkdir -p sim waves
	iverilog $(IVL_FLAGS) -o sim/tb_advanced.vvp $(RTL_SRCS) $(TB_ADVANCED)
	vvp sim/tb_advanced.vvp

# Open waveforms in GTKWave
waves:
	gtkwave waves/dump_basic.vcd &

# Clean build artifacts
clean:
	rm -rf sim/*.vvp waves/*.vcd waves/*.fst
