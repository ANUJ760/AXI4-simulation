# Reproducible quality checks

Run the installed toolchain inspection before verification:

```sh
make packages
make env-check
make uvm-smoke SEED=42 JOBS=2
make lint
make regress-rtl JOBS=2
make regress SEED=42 JOBS=2
make test-uvm-negative SEED=42 JOBS=2
make mutation-checks SEED=42 JOBS=2
make coverage
make synth SEED=42 JOBS=2
```

`regress` executes the full UVM matrix on SEED, SEED+1000 and SEED+1984.
For a custom list, call `python3 scripts/uvm_regress.py --seeds 42 1042 2026
--jobs 2` on one command line. RTL regression has a separate `RTL_SEEDS`
Make variable. Results and seed-specific logs are in build/; selected actual
artifacts are committed in reports/.

## Fault detection

`test-uvm-negative` changes the testbench's public RDATA bit 0, leaving the DUT
and model unchanged. The ordinary UVM test must fail with MODEL_MISMATCH RDATA;
the wrapper succeeds only when that expected diagnostic was actually observed.
This testbench negative control is distinct from the RTL mutation campaign.

`mutation-checks` generates three guarded, temporary copies of the DUT:

- bad_strobes: PERIOD ignores selected bytes on nonzero strobes.
- early_done: the active terminal comparison is one edge early.
- aw_w_coupling: AWREADY incorrectly depends on manager WVALID.

It compiles each copy into the shared simulator, runs the real UVM environment,
and requires a nonzero test-runner exit plus the expected model diagnostics.
Compile/preflight failures do not count as detection. Each copy records the
original/replacement text and both source hashes. The tracked RTL is never
edited; its hash is checked after each case. The normal RTL is compiled and
run again even if a mutant is not detected. Only a successful fixed rerun and
three detected faults make the campaign pass.

The guide's UVM_NO_DPI setting disables generic DPI-backed UVM command-line
argument discovery. The library has an explicit UVM_TESTNAME fallback; seeds
and traces use simulator/SystemVerilog plusargs. Do not rely on generic UVM
command-line settings such as UVM_MAX_QUIT_COUNT in this configuration.

UVM may exit the simulator normally after reporting errors. Python runners
therefore require both process success and zero actual UVM errors/fatals before
labeling a positive test PASS. Failed or injected-fault results never contribute
to the functional coverage report.

## Synthesis

The installed Yosys frontend cannot parse the canonical package's final function
return syntax. The synthesis script first records the native failure, then
inlines the exact package declarations into the module and changes the helper's
sole final `return merged` to `merge_bytes = merged`. Guards require the expected
source layout; no register values, timing or datapath behavior is rewritten.

The existing directed RTL suite executes against the adapted module before
synthesis. Yosys runs hierarchy checks, generic synthesis, `check -assert`,
statistics and netlist export. The same suite then executes against the generated
Verilog netlist. Adapter and netlist simulations use separate output directories
under build/rtl/variants/. ABC scratch/history stays inside build/synth/.

These checks support generic synthesizability and tested functional preservation.
They do not establish a process-specific frequency, area, power, timing closure,
formal equivalence or hardware implementation. The native frontend failure and
both passing verification transcripts remain available in the synthesis logs.

## Execution and coordination

CI runs the same command stack in Fedora 44 and uploads logs, JSON, native
coverage, VCD and synthesis artifacts even on failure. Remote CI execution is
not implied by a locally passing command or an authored workflow.

Timer UVM tests share build/uvm/obj for efficient compilation. Do not run multiple
build targets concurrently against that directory. Separate test/seed folders
retain results and waveforms. The supervisor reviews retained evidence or uses
isolated storage; only Codex changes implementation or Git state. See AGENTS.md
and the locked append-only communication log for the coordination contract.
