PYTHON ?= python3
JOBS ?= 2
SEED ?= 42
TOOLS_DIR := $(CURDIR)/.tools
VERILATOR ?= $(TOOLS_DIR)/verilator/bin/verilator
UVM_HOME ?= $(TOOLS_DIR)/uvm/src
BUILD_DIR := $(CURDIR)/build
export VERILATOR UVM_HOME
