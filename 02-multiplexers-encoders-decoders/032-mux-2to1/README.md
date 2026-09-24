# 032 — 2-to-1 Multiplexer

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `mux2to1` | `src/mux2to1.v` | `tb/tb_mux2to1.v` |

## 1. Objective

Implement a width-generic 2-to-1 multiplexer and verify it exhaustively at
1 bit and with random vectors at 8 bits, establishing the mux building block
used by every wider selector in this category.

## 2. What the Design Does

`mux2to1` selects between two `WIDTH`-bit data inputs, `d0` and `d1`, based
on the single-bit `sel`:

| `sel` | `y` |
|---|---|
| 0 | `d0` |
| 1 | `d1` |

The selection is bitwise-uniform: every bit of `y` follows the same input
bus for a given `sel`, there is no per-bit mixing.

## 3. Why It Is Useful

The 2:1 mux is the atomic selection primitive of digital design: register
input selection (hold vs. new value), ALU operand routing, bus arbitration
winners, and Shannon-expansion decomposition of arbitrary Boolean functions
(used later in program 044) are all built by composing 2:1 muxes.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `sel` | input | 1 | Selects `d0` (0) or `d1` (1) |
| `d0` | input | `WIDTH` | Data input selected when `sel = 0` |
| `d1` | input | `WIDTH` | Data input selected when `sel = 1` |
| `y` | output | `WIDTH` | Selected data |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 1 | Bus width of `d0`, `d1` and `y` |

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 d0 ──┐
      │  sel=0 ──► y = d0
      ├──[ mux ]──── y
      │  sel=1 ──► y = d1
 d1 ──┘
      sel
```

A single combinational selector; no internal state or hierarchy.

## 7. Module Hierarchy and Connections

```
tb_mux2to1
├── dut1 : mux2to1 #(.WIDTH(1))   -- exhaustive 1-bit instance
└── dut8 : mux2to1 #(.WIDTH(8))   -- random 8-bit instance
```

The testbench instantiates the same module twice with different `WIDTH`
overrides, driving each independently.

## 8. Verilog Concepts Used

* `parameter` for a width-generic module.
* The ternary (conditional) operator `?:` as a 2-way combinational select.
* Continuous assignment (`assign`) applied to a vector.
* Multiple parameterized instances of one module in a single testbench.

## 9. Source Code Explanation

```verilog
module mux2to1 #(
    parameter WIDTH = 1
) (
    input  wire             sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    output wire [WIDTH-1:0] y
);

    assign y = sel ? d1 : d0;

endmodule
```

* `#(parameter WIDTH = 1)` makes the data width a compile-time constant,
  defaulting to 1 bit so the smallest instantiation needs no override.
* `sel`, `d0`, `d1` and `y` are declared with `[WIDTH-1:0]` so the same RTL
  text elaborates to a 1-bit or an N-bit multiplexer depending on the
  instance's `#(.WIDTH(N))`.
* `assign y = sel ? d1 : d0;` is the entire behaviour: `sel` picks the whole
  bus at once, there is no bit-by-bit logic to write by hand.

## 10. Testbench Explanation

`tb_mux2to1` instantiates two versions of the DUT:

1. `dut1` (`WIDTH=1`): the 3-bit combination `{sel, d0, d1}` is swept from
   `0` to `7`, covering all 8 possible input states, and each output is
   compared against `sel ? d1 : d0` computed independently in the bench.
2. `dut8` (`WIDTH=8`): 200 random 8-bit pairs are generated with `$random`,
   each applied with both `sel = 0` and `sel = 1`, for 400 additional
   checks that the whole bus (not just bit 0) is routed correctly.

Every check increments `checks`; a mismatch increments `errors` and prints
an `ERROR:` line with time, inputs, expected and actual values. The final
line is `TEST PASSED: 408 checks` (8 exhaustive + 400 random-driven) or a
`TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive 1-bit | `{sel,d0,d1}` = 0..7 | `y = sel ? d1 : d0` for all 8 cases |
| 2 | Random 8-bit, `sel=0` | 200 random `(d0,d1)` pairs | `y = d0` |
| 3 | Random 8-bit, `sel=1` | same 200 pairs | `y = d1` |

All 8 states of the 1-bit instance (100% of its input space) plus 400
randomized checks of the 8-bit instance are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 032` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_mux2to1` — **PASS**

```text
WIDTH=1 exhaustive:
sel d0 d1 | y
 0   0  0  | 0
 0   0  1  | 0
 0   1  0  | 1
 0   1  1  | 1
 1   0  0  | 0
 1   0  1  | 1
 1   1  0  | 0
 1   1  1  | 1
WIDTH=8 random (200 vectors x 2 sel values):
done: 408 checks
TEST PASSED: 408 checks
tb/tb_mux2to1.v:76: $finish called at 408000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `WIDTH` scales the design to any data bus without touching the logic —
  the ternary operator already works bit-for-bit on vectors.
* A single `assign` with `?:` synthesizes to one level of 2:1 mux cells per
  bit; there is no timing or area concern at this scale.
* No reset or clock is needed — this is pure combinational logic.

## 14. Common Mistakes

* Swapping the sense of `sel` (treating 0 as "choose `d1`"): always confirm
  against the truth table in section 2, since both conventions are common
  across vendors and datasheets.
* Declaring `d0`/`d1` with mismatched widths from `y`, which truncates or
  zero-extends silently instead of producing a clean N-bit select.

## 15. Possible Improvements

* Build a 4:1 mux from two 2:1 muxes plus a third (program 033).
* Add a `case`-based implementation for direct comparison with the ternary
  style (program 034 uses `case` on a wider select).

## 16. What This Program Teaches

* Using `parameter` to make a module width-generic instead of hard-coding
  a bit count.
* The ternary operator as a synthesizable 2-way selector.
* Combining exhaustive testing (small input space) with randomized testing
  (larger input space) in the same testbench.

## 17. Industry Relevance

Every synthesis tool maps a 2:1 select directly onto a technology mux cell
(or absorbs it into a LUT on FPGAs); this exact `sel ? d1 : d0` idiom is
the standard way register-update muxes, bypass muxes and operand-select
muxes are written in production RTL.

## 18. How to Run

```bash
python3 scripts/run.py 032            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/032-mux-2to1 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/mux2to1.v tb/tb_mux2to1.v
vvp build/sim.vvp +vcd
```
