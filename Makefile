# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: SHL-0.51
#
# Course: Arquitectura de Computadores (2026)
# 
# Authors:
# - Nicolás Villegas <navillegas@miuandes.cl>

# Configuration
TOP  ?= game_top
PCF  := goboard.pcf
GAME_HEX := sw/game.hex

# RTL Sources
SRC  := $(wildcard ./rtl/*.v ./rtl/**/*.v)

# Build Targets
JSON := $(TOP).json
ASC  := $(TOP).asc
BIN  := $(TOP).bin

.PHONY: all prog clean stats game test trade p4-test

# Default target
all: prog

# Step 1: Synthesis using Yosys
$(JSON): $(SRC) $(GAME_HEX)
	yosys -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json ${TOP}.json; stat"

$(GAME_HEX): sw/game.s sw/assembler.py
	$(MAKE) -C sw game.hex

game: $(GAME_HEX)

test:
	$(MAKE) -C sw test

# Proyecto 4: programa de trading y simulacion oficial de practica.
sw/trade.hex: sw/trade.s sw/assembler.py
	python3 sw/assembler.py sw/trade.s sw/trade.hex

trade: sw/trade.hex

p4-test: sw/trade.hex
	iverilog -g2012 -s tb_proyecto_4 -o /tmp/tb_p4 \
		$$(yosys-config --datdir)/ice40/cells_sim.v \
		rtl/*.v rtl/espino_core/*.v tb/tb_proyecto_4.sv
	vvp /tmp/tb_p4

# Step 2: Place and Route using NextPNR
$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --freq 25 --json $(JSON) --pcf $(PCF) --asc $(ASC)

# Step 3: Bitstream Generation
$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

# Step 4: Flash the Board
prog: $(BIN)
	iceprog $(BIN)

# Clean up generated files
clean:
	rm -f $(JSON) $(ASC) $(BIN)
