include config/tools.mk

.DEFAULT_GOAL := help
.PHONY: help env-check packages fetch-toolchain toolchain uvm-smoke
help:
	@echo "Phase 0: env-check packages fetch-toolchain toolchain uvm-smoke"
	@echo "JOBS=$(JOBS) SEED=$(SEED); generated outputs: build/ and .tools/"
env-check:
	$(PYTHON) scripts/env_check.py
packages:
	$(PYTHON) scripts/check_packages.py
fetch-toolchain:
	$(PYTHON) scripts/fetch_toolchain.py
toolchain: fetch-toolchain
	$(PYTHON) scripts/build_verilator.py --jobs $(JOBS)
uvm-smoke:
	$(PYTHON) scripts/uvm_smoke.py --jobs $(JOBS) --seed $(SEED)
