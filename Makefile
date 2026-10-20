include config/tools.mk

.DEFAULT_GOAL := help
.PHONY: help env-check packages fetch-toolchain toolchain uvm-smoke lint test-rtl regress-rtl test-uvm test-uvm-negative regress coverage mutation-checks
help:
	@echo "Phase 0: env-check packages fetch-toolchain toolchain uvm-smoke"
	@echo "Phase 1: lint test-rtl regress-rtl"
	@echo "UVM: test-uvm test-uvm-negative regress coverage mutation-checks"
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

RTL_SEEDS ?= 42 1042 2026
regress-rtl:
	$(PYTHON) scripts/rtl_regress.py --seeds $(RTL_SEEDS) --jobs $(JOBS)

TEST ?= timer_full_test
test-uvm:
	$(PYTHON) scripts/uvm_test.py --test $(TEST) --seed $(SEED) --jobs $(JOBS)

test-uvm-negative:
	$(PYTHON) scripts/uvm_fault_check.py --seed $(SEED) --jobs $(JOBS)

regress:
	$(PYTHON) scripts/uvm_regress.py --seed $(SEED) --jobs $(JOBS)
coverage:
	$(PYTHON) scripts/coverage.py

mutation-checks:
	$(PYTHON) scripts/mutation_checks.py --seed $(SEED) --jobs $(JOBS)
