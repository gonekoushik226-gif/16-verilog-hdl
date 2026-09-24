# 001 — First Module

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `first_module` | `src/first_module.v` | `tb/tb_first_module.v` |

## 1. Objective

Write, simulate and check a complete (if tiny) Verilog design: one module with
an input and two outputs, plus a testbench that drives the input and verifies
the outputs automatically.

## 2. What the Design Does

`first_module` has one input, `in_sig`, and two outputs:

| `in_sig` | `out_sig` | `out_sig_n` |
|:---:|:---:|:---:|
| 0 | 0 | 1 |
| 1 | 1 | 0 |

`out_sig` is a copy of the input, `out_sig_n` is its inverse. The outputs
change as soon as the input changes; there is no clock and no memory.

## 3. Why It Is Useful

Every Verilog design — from a gate to a processor — has the same skeleton:
a `module` with a port list, some logic, and `endmodule`. Every verification
effort has the same skeleton too: a testbench that instantiates the design,
drives inputs, and compares outputs with expectations. This program shows both
skeletons with nothing else in the way. Producing a signal and its complement
is also a real need (differential signalling, active-high/active-low control
lines).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `in_sig` | input | 1 | Input signal |
| `out_sig` | output | 1 | Equal to `in_sig` |
| `out_sig_n` | output | 1 | Inverse of `in_sig`; the `_n` suffix is the naming convention for inverted/active-low signals |

## 5. Internal Signals

None. Both outputs are driven directly from the input.

## 6. Architecture

```
            +------------------------------+
            |         first_module         |
 in_sig ----+------------------------------+---- out_sig
            |      |                       |
            |      |    +-----+            |
            |      +----| NOT |------------+---- out_sig_n
            |           +-----+            |
            +------------------------------+
```

The design is purely combinational: a wire and an inverter.

## 7. Module Hierarchy and Connections

```
tb_first_module          (testbench, not synthesizable)
└── dut : first_module   (design under test)
```

The testbench `reg in_sig` drives `dut.in_sig`; `dut.out_sig` and
`dut.out_sig_n` drive the testbench wires of the same names.

## 8. Verilog Concepts Used

* `` `timescale 1ns / 1ps `` — the unit for `#` delays (1 ns) and the
  simulation precision (1 ps).
* `module … endmodule` with an **ANSI-style port list** — the direction,
  type and name of each port are declared in the header.
* `input wire` / `output wire` — ports are nets driven continuously.
* `assign` — **continuous assignment**: the left side is re-evaluated whenever
  anything on the right side changes, like a physical wire or gate.
* `~` — bitwise NOT.
* Testbench constructs: `reg` for driven signals, module instantiation with
  named port connections, `initial`, `#` delay, `for`, `$display`,
  `$test$plusargs`, `$dumpfile/$dumpvars`, `$finish`, and the case-equality
  operator `!==`.

## 9. Source Code Explanation

`src/first_module.v`

```verilog
`timescale 1ns / 1ps
```
Compiler directive. Delays in this file are in nanoseconds with picosecond
resolution. The RTL contains no delays, but giving every file the same
timescale avoids "inherited timescale" warnings and mismatches.

```verilog
module first_module (
    input  wire in_sig,
    output wire out_sig,
    output wire out_sig_n
);
```
Declares the module name and its three ports. `wire` means the port is a
net: it has no storage and simply carries whatever drives it.

```verilog
    assign out_sig   = in_sig;
    assign out_sig_n = ~in_sig;
```
Two continuous assignments that run concurrently. Their order in the file
does not matter — hardware has no "first line". Synthesis turns the first
into a plain connection and the second into an inverter.

```verilog
endmodule
```
Closes the module.

## 10. Testbench Explanation

`tb/tb_first_module.v` has no ports: it is the top of the simulation.

* `reg in_sig;` — the testbench drives the DUT input from procedural code,
  and only variables (`reg`) can be assigned inside `initial` blocks.
* `wire out_sig, out_sig_n;` — the DUT drives these.
* `integer errors = 0, checks = 0;` — counters for the pass/fail summary.
* `first_module dut (.in_sig(in_sig), …);` — instantiates the design with
  **named** port connections (`.port(signal)`), which cannot be mixed up by
  port order.
* The `initial` block:
  1. Optionally enables waveform dumping when the simulator is run with
     `+vcd`.
  2. Loops `i` over 0 and 1, assigns `in_sig = i[0]`, and waits `#10` so the
     continuous assignments have settled before sampling.
  3. Prints a row of the truth table and compares both outputs using `!==`.
     Case inequality (`!==`) also catches `x` or `z` outputs, which a plain
     `!=` would silently treat as "unknown" instead of "wrong".
  4. Prints `TEST PASSED`/`TEST FAILED` and calls `$finish`.

## 11. Test Cases and Expected Results

| # | Stimulus | Expected `out_sig` | Expected `out_sig_n` |
|---|---|---|---|
| 1 | `in_sig = 0` | 0 | 1 |
| 2 | `in_sig = 1` | 1 | 0 |

This covers the complete input space.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 001` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_first_module` — **PASS**

```text
time(ns) in_sig | out_sig out_sig_n
      10    0    |    0       1
      20    1    |    1       0
TEST PASSED: 2 checks
tb/tb_first_module.v:45: $finish called at 20000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

The `$finish called at 20000 (1ps)` line is printed by the simulator: time is
reported in the 1 ps precision, so 20000 ps = 20 ns, the end of the second
10 ns step.

## 13. Design Considerations

* The module has no clock, so it is combinational; outputs follow the input
  after the gate delay of the target technology.
* Synthesis produces a single inverter cell (see the Yosys cell count
  above); `out_sig` is just a wire.
* Output ports that are pure copies of inputs are common in top-level
  wrappers (feed-throughs) but add nothing inside a design.

## 14. Common Mistakes

* **Missing `endmodule`** or a missing `;` after the port list `)` — the
  most frequent first-day syntax errors.
* **Assigning a `wire` inside an `initial`/`always` block** — procedural code
  may only assign variables (`reg`). That is why the testbench declares
  `in_sig` as `reg`.
* **Using `!=` to check outputs** — if the DUT output were `x`,
  `x != 0` evaluates to `x`, the `if` is not taken, and the error goes
  unnoticed. Use `!==` in testbenches.
* **Sampling immediately after changing an input** without a delay — the
  continuous assignment has not been evaluated yet in the same time step.

## 15. Possible Improvements

* Make the ports vectors (for example 8 bits) — see program 002.
* Add `` `default_nettype none `` to catch misspelled signal names — see
  program 002.

## 16. What This Program Teaches

* The structure of a Verilog module and an ANSI port list.
* Continuous assignment with `assign`.
* The structure of a self-checking testbench and the pass/fail convention
  used throughout this repository.

## 17. Industry Relevance

Every RTL file in industry follows this skeleton, and every block is signed
off by self-checking tests that report pass/fail automatically so they can
run unattended in regressions. Complementary signal pairs (`sig`/`sig_n`)
and the `_n` naming convention appear in real interfaces such as `rst_n`,
`cs_n` and `oe_n`.

## 18. How to Run

```bash
python3 scripts/run.py 001            # compile, simulate, synthesize, lint

# manual flow with waveform dump
cd 00-foundations/001-first-module
mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/first_module.v tb/tb_first_module.v
vvp build/sim.vvp +vcd                # then open build/tb_first_module.vcd in GTKWave
```
