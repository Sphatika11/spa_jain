# SPDX-License-Identifier: Apache-2.0
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../src/tt_um_sphatika11_minitage.v
VERILOG_SOURCES += $(PWD)/../src/ghr.v
VERILOG_SOURCES += $(PWD)/../src/bimodal.v
VERILOG_SOURCES += $(PWD)/../src/tage_table.v
VERILOG_SOURCES += $(PWD)/../src/loop_predictor.v
VERILOG_SOURCES += $(PWD)/../src/predictor_core.v

TOPLEVEL = tt_um_sphatika11_minitage
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
