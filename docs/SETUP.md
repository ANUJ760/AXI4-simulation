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
```

No pip packages or virtual environment are needed. GTKWave is optional for
headless smoke execution; Icarus/Yosys/Z3 prepare subsequent RTL/synthesis/random
testing. `make env-check` lists the complete guide-required command inventory;
`make packages` checks Fedora build/header packages without installing anything.

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

References: [Verilator release notes](https://verilator.org/guide/latest/changes.html)
and [Accellera UVM downloads](https://www.accellera.org/downloads/standards/uvm).
