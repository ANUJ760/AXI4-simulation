# Fedora setup

Use the pinned versions in config/toolchain.json and config/sources.lock.json.
The supplied guide §9A lists these system prerequisites:

```sh
sudo dnf install -y git gcc gcc-c++ make autoconf automake flex bison \
  help2man perl zlib-devel python3 python3-devel iverilog gtkwave yosys z3 curl tar
make packages
make toolchain JOBS=2
make env-check
make uvm-smoke SEED=42 JOBS=2
make lint
make test-rtl SEED=42 JOBS=2
make regress-rtl RTL_SEEDS="42 1042 2026" JOBS=2
```

No pip packages or virtual environment are needed. GTKWave is optional for
headless execution; Icarus/Yosys/Z3 support RTL/synthesis/random testing. `make env-check` lists the complete guide-required command inventory;
`make packages` checks Fedora build/header packages without installing anything.

Fedora may have `perl-interpreter` without the launcher module `FindBin`.
`make packages` checks the Perl modules as well as RPM providers. If only
FindBin is missing, `sudo dnf install -y perl-FindBin` is sufficient.

All downloaded sources/install files live in ignored `.tools/`; compiler output
and raw logs live in ignored `build/`. The bootstrap does not edit PATH or shell
startup files. Make uses the local simulator directly. `JOBS=1` reduces memory
pressure. A source build can take several minutes. Archive SHA256 and the
Verilator commit are checked before use. External UVM overrides must match the
pinned version and are the caller's responsibility for provenance.

Override paths with `make uvm-smoke VERILATOR=/absolute/path/to/verilator
UVM_HOME=/absolute/path/to/uvm/src` on a single command line.

A checkout moved to a different directory needs `make toolchain` to regenerate
absolute installation paths. Keep logs when investigating failures; bootstrap
and smoke timeouts return nonzero. If a download is interrupted, retry the same
command. Delete a corrupt archive explicitly before redownloading; checks never
silently accept changed upstream content.

RTL tests execute with Verilator independently of UVM. Every seed creates
`build/rtl/<seed>/compile.log`, `run.log`, `versions.log`, `result.json` and
`timer.vcd`. Open a trace with `gtkwave build/rtl/42/timer.vcd` from a desktop
terminal. The regression summary is `build/rtl/regression/summary.json`.

VCD tracing requires no additional development package. An FST build was tried
and failed because `lz4.h` was absent; FST is not required by the current targets.
No LZ4 package was installed for this project. Failed compile/run commands stop
the regression; the structured verdict is cleared before each test attempt.

For the complete UVM, mutation, coverage, synthesis and clean-checkout stack,
follow [QUALITY.md](QUALITY.md). The clean-checkout target reuses the pinned
installed toolchain but compiles the committed RTL/UVM from empty build storage.
All verification targets execute real tools and fail on unexpected errors.

References: [Verilator release notes](https://verilator.org/guide/latest/changes.html)
and [Accellera UVM downloads](https://www.accellera.org/downloads/standards/uvm).
