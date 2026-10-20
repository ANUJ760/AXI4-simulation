include config/tools.mk

.DEFAULT_GOAL := help
.PHONY: help env-check packages fetch-toolchain toolchain uvm-smoke lint test-rtl
help:
	@echo "Phase 0: env-check packages fetch-toolchain toolchain uvm-smoke"
	@echo "Phase 1: lint test-rtl"
	@echo "JOBS=$(JOBS) SEED=$(SEED); generated outputs: build/ and .tools/"
env-check:
	$(PYTHON) scripts/env_check.py
packages:
	$(PYTHON) scripts/check_packages.py
fetch-toolchain:
	$(PYTHON) scripts/fetch_toolchain.py
toolchain: packages fetch-toolchain
	$(PYTHON) scripts/build_verilator.py --jobs $(JOBS)
uvm-smoke:
	$(PYTHON) scripts/uvm_smoke.py --jobs $(JOBS) --seed $(SEED)

lint:
	$(PYTHON) scripts/rtl_check.py lint --seed $(SEED)
test-rtl:
	$(PYTHON) scripts/rtl_check.py test --jobs $(JOBS) --seed $(SEED)
