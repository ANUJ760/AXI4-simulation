include config/tools.mk

.DEFAULT_GOAL := help
.PHONY: help env-check packages
help:
	@echo "Phase 0: env-check packages toolchain uvm-smoke"
	@echo "JOBS=$(JOBS) SEED=$(SEED); generated outputs: build/ and .tools/"
env-check:
	$(PYTHON) scripts/env_check.py
packages:
	$(PYTHON) scripts/check_packages.py
