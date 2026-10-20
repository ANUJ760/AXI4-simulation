# Phase 0 delivery report

Date: 2026-10-20. Scope: guide §18, which requires Phase 0 first and a
proposed Phase 1 plan. This is the toolchain delivery, not completion of the
AXI4-Lite timer project.

## Implemented files

| Path | Purpose |
| --- | --- |
| `AXI4_Lite_UVM_Agent_Guide_REPAIRED.docx` | Preserved authoritative specification |
| `config/toolchain.json`, `config/sources.lock.json` | Release pins, upstream commit, archive SHA256 |
| `config/tools.mk`, `Makefile` | Local paths, bounded parallelism, reproducible command entry points |
| `scripts/common.py` | Logged subprocesses, exit codes and timeouts |
| `scripts/env_check.py`, `scripts/check_packages.py` | Host/tool versions, Fedora headers, Perl runtime modules |
| `scripts/fetch_toolchain.py` | Verified source acquisition and safe archive extraction |
| `scripts/build_verilator.py` | Local simulator build/install with logs |
| `scripts/uvm_smoke.py`, `scripts/smoke_verdict.py` | Real compilation/execution and strict report validation |
| `tb/smoke/smoke_if.sv` | Clocked interface exercised through a virtual handle |
| `tb/smoke/smoke_item.svh` | Factory-registered sequence item |
| `tb/smoke/smoke_test.svh` | UVM config_db, factory, timed run phase and data check |
| `tb/smoke/tb_top.sv`, `tb/smoke/files.f` | Clock, watchdog, run_test and explicit compilation order |
| `.github/workflows/ci.yml` | Fedora toolchain build and actual UVM smoke job |
| `.gitignore` | Excludes downloaded tools, generated C++, binaries and caches |
| `docs/SETUP.md`, `docs/PHASE0_PLAN.md`, `docs/PHASE1_PLAN.md`, `README.md` | Setup, acceptance, next gate and usage |
| `reports/phase0/` | Actual retained command logs and integrity hashes |

## Toolchain and dependencies

Fedora Linux 44, x86_64. Git 2.55.0; GCC/G++ 16.2.1; Make 4.4.1;
Python 3.14.7; autoconf 2.72; automake 1.18.1; flex 2.6.4; bison 3.8.2;
help2man 1.49.3; Perl 5.42.3; Icarus 13.0; Yosys 0.67+post;
Z3 4.16.0. GTKWave is installed and detected without starting its GUI.
Exact paths and versions are in the environment logs.

Verilator: **5.052, 2026-09-05, v5.052**, built from commit
`ea338be98e1e838d3518809ce8899f85a009963c`.
UVM: **Accellera:1800.2:UVM:2020.3.2**.
Official archive SHA256:
`4664ac015f23c72106dd785906aa874d70932ea63f74b85de1e32fa5339c15eb`.

Initial missing system packages were installed through Fedora DNF. The first
installed Verilator launcher exposed missing `FindBin` in the host's minimal
Perl installation. Sudo retries timed out during authentication; the user then
installed Perl. Subsequent module checks and launcher execution succeed.
The preflight now checks these modules before rebuilding Verilator. Initial
failure logs are preserved rather than overwritten with passing transcripts.

No pip packages, cocotb, pytest, or other Python frameworks were installed.
Sources and installation remain inside ignored `.tools/`; raw generated C++,
objects and execution logs remain inside ignored `build/`. No shell startup
files or global simulator paths were changed.

## Executed checks

| Command/check | Result | Evidence |
| --- | --- | --- |
| `make packages` after Perl installation | PASS | [packages-ready.log](phase0/packages-ready.log) |
| `make toolchain JOBS=2` after Perl installation | PASS | [toolchain-ready.log](phase0/toolchain-ready.log) |
| `make env-check` after Perl installation | PASS | [environment-ready.log](phase0/environment-ready.log) |
| `make uvm-smoke SEED=42 JOBS=2` | PASS, real UVM execution | [compile.log](phase0/compile.log), [run.log](phase0/run.log), [versions.log](phase0/versions.log) |
| Python syntax/import audit | PASS: all seven scripts parse, no unused imported names | AST inspection executed locally |
| `git diff --check` | PASS | Executed locally |
| GitHub Actions workflow | NOT RUN remotely | Workflow authored; local commands above executed |

The smoke test factory-creates an item, generates its value with `$urandom`,
drives it through the virtual interface at a falling edge, compares the value
at the next rising edge and ends its objection. Simulation completes at 15 ns.
Expected data is computed from the generated item; no example result or
simulator transcript is embedded as a test answer.

The actual UVM report has **0 UVM_ERROR and 0 UVM_FATAL**. It reports two UVM
warnings: `NO_DPI_USED` and `NO_VISIT_CHECK`. The guide explicitly uses
`UVM_NO_DPI`; component-name constraint checks are therefore unavailable.
These warnings remain visible and are not relabeled as checked behavior.
The final compile uses an explicit default timescale of `1ns/1ps` and an
explicit smoke package timeunit to address the initial timescale warnings.

Actual compiler and runtime argument lists are recorded at the start of each
log. The build invokes the pinned simulator with `--binary --timing --assert`,
`--timescale 1ns/1ps`, `-j 2`, `-Wno-fatal`, `+define+UVM_NO_DPI`, UVM and
smoke include paths, `uvm_pkg.sv`, and the ordered smoke file list. The generated
executable is run with `+verilator+seed+42`. Both commands must return zero;
the verdict also requires the smoke completion message and zero-error/fatal
UVM report summaries.

## Remaining gates and measured limits

| Guide gate | Status |
| --- | --- |
| Gate 0: real UVM toolchain smoke | PASS |
| Gate 1: timer RTL, lint and directed RTL cases | NOT STARTED |
| Gate 2: reusable bus UVM agent, independent model and scoreboard | NOT STARTED |
| Gate 3: protocol SVA, functional covergroups and random matrix | NOT STARTED |
| Gate 4: regression, three RTL mutations and synthesis evidence | NOT STARTED |

Seed 42 was exercised for the smoke only. No timer functional coverage,
protocol assertion coverage, 100-transaction random suite, mutation detection,
synthesis result, or timer waveform is claimed. No DUT exists in Phase 0.
The smoke is a compatibility probe and does not establish support for every
UVM feature. `--assert` alone does not mean protocol properties were exercised.

Next: follow [the Phase 1 file and acceptance plan](../docs/PHASE1_PLAN.md),
starting with the register contract tests and synthesizable timer RTL.

## Reproduction

Follow [Fedora setup](../docs/SETUP.md) in a fresh checkout. After system
prerequisites, run:

```sh
make packages
make toolchain JOBS=2
make env-check
make uvm-smoke SEED=42 JOBS=2
```

The scripts use only Python's standard library. Downloads require network
access; system package installation requires sudo authentication. No tracked
binaries or previously generated test results are needed to rerun the smoke.
Committed evidence hashes are listed in `phase0/SHA256SUMS.json`.
