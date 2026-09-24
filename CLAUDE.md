# CLAUDE.md — Permanent Rules for This Repository

This file is the contract for every session that works on this repository.
Read it completely before changing anything. When a rule here conflicts with
a habit, the rule wins. When a rule needs to change, change it here first and
record the decision in `PROJECT_STATUS.md` → *Project decisions*.

---

## 1. What this repository is

A structured Verilog HDL learning and RTL-design library that progresses from
single logic gates to integrated, industry-entry-level RTL projects. Every
program is a small, complete engineering deliverable: RTL, a self-checking
testbench, a README that explains the actual implementation, and recorded
simulation results.

Key files:

| File | Role |
|---|---|
| `PROGRAM_CATALOG.md` | Complete planned program list (numbers, names, files, testbench plan). Source of truth for *what* to build. |
| `PROJECT_STATUS.md` | What is done, verified, in progress, blocked; project decisions; resume checkpoint. |
| `README.md` | Public overview and navigation. |
| `scripts/run.py` | Compile + simulate + synthesize + lint one/all programs; updates README result blocks and the status table. |
| `regression/results.json` | Machine-readable result of the last run of each program (written by `run.py --update-docs`). |
| `docs/program_readme_template.md` | Required README structure for every program. |

## 2. Tools (cloud container)

The container starts without HDL tools. Install them once per session:

```bash
sudo apt-get update && sudo apt-get install -y iverilog yosys verilator
```

Versions used so far: Icarus Verilog 12.0, Yosys 0.33, Verilator 5.020.
If `apt-get install` fails with a 404, run `apt-get update` and retry.

## 3. Directory layout

```
<NN>-<category>/<NNN>-<program-name>/
    src/            synthesizable RTL (*.v, one module per file; *.vh includes)
    src/<subdir>/   optional logical grouping for large designs
    tb/             testbenches: tb_<name>.v are top-level benches,
                    any other *.v in tb/ is a helper module (models, BFMs)
    data/           optional memory images ($readmemh/$readmemb), test vectors
    program.conf    optional per-program flow configuration (see run.py header)
    README.md       program documentation (see §7)
```

Categories (two-digit prefix, fixed order):

```
00-foundations            07-finite-state-machines   14-processors
01-basic-gates            08-memory                  15-advanced-rtl
02-multiplexers-encoders-decoders  09-digital-systems  16-verification
03-combinational-logic    10-communication           17-fpga-oriented-designs
04-arithmetic-circuits    11-bus-protocols           18-industry-entry-projects
05-sequential-logic       12-datapath-and-rtl
06-registers-and-counters 13-processor-components
```

### Numbering

* Program numbers are global, three digits, and **stable forever**
  (`017-and-gate`). Never renumber or rename an existing program folder.
* New programs get the next unused number (append to the catalog, in the
  appropriate category section). Numbers inside a category need not be
  contiguous.
* Folder name = `<NNN>-<kebab-case-name>` exactly as in `PROGRAM_CATALOG.md`.
* If an implementation deviates from the catalog (different files, split
  modules), update that catalog row in the same commit.

## 4. Verilog coding standard

* Language: **Verilog-2005** (`iverilog -g2005`). Use another dialect only
  when the lesson requires it (e.g. `16-verification/291` uses `-g2012`) and
  record it in `program.conf` (`IVERILOG_FLAGS=`).
* Every `.v` file starts with `` `timescale 1ns / 1ps ``.
* One module per file; file name = module name (`alu.v` → `module alu`).
* ANSI-style port lists with explicit `input wire` / `output wire|reg`.
* Names: `snake_case` for modules, ports, signals; `UPPER_CASE` for
  `parameter`/`localparam`; active-low signals end in `_n` (`rst_n`);
  clocks `clk` (or `clk_<domain>`); next-state signals `<name>_next`.
* Reset default: **asynchronous assert, active-low `rst_n`**. Programs that
  teach other reset styles say so explicitly. FPGA-oriented programs may use
  synchronous active-high reset and must explain why.
* Sequential logic: `always @(posedge clk or negedge rst_n)` with
  non-blocking `<=` only.
* Combinational logic: `always @(*)` with blocking `=` only, and a default
  assignment for every output at the top of the block (no unintended
  latches). `case` statements always have a `default`.
* FSMs: `localparam` state encodings, separate state register and
  next-state/output logic; illegal states recover to a safe state.
* Parameters only where they genuinely add reuse. Derive widths with
  `$clog2` in `localparam`s. No `defparam`.
* No `initial` blocks in synthesizable RTL except memory initialization
  with `$readmemh/$readmemb` (allowed for ROM/RAM inference).
* No `#` delays in RTL (except programs that teach delay modelling, which
  set `SYNTH=no`).
* Comments explain intent, interfaces, assumptions and non-obvious logic —
  not every trivial line.
* Hierarchical designs are split into real modules connected through ports
  and parameters. Never flatten a hierarchy into one file to save files.
* No tool/AI attribution text in source files or READMEs.

## 5. Testbench standard

* Top-level testbench module `tb_<design>` in `tb/tb_<design>.v`. A program
  may have several top-level benches (unit + integration); each is run.
* Testbenches are **self-checking**: they compute or look up the expected
  value and compare. Keep an `errors` counter and a `checks` counter.
* The final line printed must be exactly one of:
  * `TEST PASSED: <n> checks`
  * `TEST FAILED: <e> errors / <n> checks`
* Each mismatch prints a line beginning with `ERROR:` including time,
  inputs, expected and actual values.
* Sequential benches have a watchdog (`TEST FAILED: timeout`) so a hung
  design cannot hang the regression.
* Waveforms only on request: `if ($test$plusargs("vcd")) begin $dumpfile(...);
  $dumpvars(0, tb_<design>); end` — never unconditional.
* Keep console output compact (a table for small designs, a summary for large
  ones); the README embeds the log.
* Cover: normal operation, boundaries, corner cases, reset behaviour,
  exhaustive input space when it is small (≤ 2^16), state transitions,
  full/empty, protocol behaviour, error/invalid inputs where meaningful.
* Randomized tests use a fixed default seed (overridable with `+seed=<n>`)
  so results are reproducible.
* Testbench helper models (memories, sensors, bus slaves) go in `tb/` without
  the `tb_` prefix.

## 6. Verification flow and status definitions

Run a program:

```bash
python3 scripts/run.py 017                 # by number
python3 scripts/run.py 017 --update-docs   # refresh README + status + results.json
python3 scripts/run.py --all -j 4 --update-docs   # full regression
```

`run.py` compiles **all** `src/**/*.v` files with each `tb/tb_*.v` bench,
runs `vvp` from the program directory, and passes only if the exit code is 0,
`TEST PASSED` is printed, `TEST FAILED` is not, and no line starts with
`ERROR`. It then runs Yosys generic synthesis (`synth; check -assert`) and
fails on unintended latches, and a Verilator `--lint-only` pass.

Status vocabulary (use exactly these words):

| Status | Meaning |
|---|---|
| **SIMULATION VERIFIED** | Compiled with all sources, self-checking testbench(es) ran to completion in Icarus Verilog and printed `TEST PASSED`. |
| **SYNTHESIS VERIFIED (Yosys generic synthesis)** | `yosys synth` + `check -assert` completed with no errors and no unintended latches. It does **not** mean timing closure or vendor-tool implementation. |
| **FPGA HARDWARE VERIFIED** | Tested on a physical board. Never claimed from the cloud container — no board is available. |

A program is **VERIFIED** (done) only when: all source files exist, the
design and testbench compile, the simulation passes, failures were fixed,
the README describes the final implementation (with the generated results
block), and `PROJECT_STATUS.md` / `regression/results.json` are updated via
`--update-docs`. Never write simulation results by hand; they are inserted
by `run.py` between the README markers.

## 7. README standard

Use `docs/program_readme_template.md`. Required numbered sections:

1 Objective · 2 What the Design Does · 3 Why It Is Useful ·
4 Interface (inputs/outputs) · 5 Internal Signals · 6 Architecture ·
7 Module Hierarchy and Connections · 8 Verilog Concepts Used ·
9 Source Code Explanation (line-by-line where practical) ·
10 Testbench Explanation · 11 Test Cases and Expected Results ·
12 Actual Simulation Results (generated block) · 13 Design Considerations ·
14 Common Mistakes · 15 Possible Improvements · 16 What This Program Teaches ·
17 Industry Relevance · 18 How to Run.

The README must contain the two generated-block marker pairs:
`<!-- STATUS:BEGIN -->…<!-- STATUS:END -->` (under the title) and
`<!-- SIM-RESULTS:BEGIN -->…<!-- SIM-RESULTS:END -->` (section 12).

Writing rules: describe the *actual* code (quote real signal names and
lines); tiny programs explain essentially every line; large programs explain
every module and every important block. No filler, no marketing language,
no claims that were not demonstrated. Educational designs state their
limitations honestly.

## 8. Per-program workflow

PLAN → IMPLEMENT (src) → TESTBENCH → `run.py` → DEBUG until PASS →
README → `run.py --update-docs` → review README results block →
update `PROJECT_STATUS.md` checkpoint if needed → commit.

Commit in small batches (one program or a few small related programs per
commit) with messages like `Add 017-023 basic gates (simulation verified)`.
Push to the working branch after each batch.

## 9. Resuming work

1. Install tools (§2).
2. Read `PROJECT_STATUS.md` → *Resume checkpoint* for the next program number
   and any in-progress notes.
3. Run `python3 scripts/run.py --all -j 4` to confirm the tree is green.
4. Continue with the next catalog entry. Do not regenerate completed programs.
