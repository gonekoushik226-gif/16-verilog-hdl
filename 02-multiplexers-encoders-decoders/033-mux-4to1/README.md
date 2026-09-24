# 033 — 4-to-1 Multiplexer (Hierarchical)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `mux4to1` | `src/mux2to1.v`, `src/mux4to1.v` | `tb/tb_mux4to1.v` |

## 1. Objective

Build a 4-to-1 multiplexer structurally out of three instances of the
program-032 `mux2to1` block, showing how a wider selector is composed from
smaller ones instead of being written as one flat expression.

## 2. What the Design Does

`mux4to1` routes one of four `WIDTH`-bit inputs to `y` according to the
2-bit select `sel`:

| `sel` | `y` |
|---|---|
| `00` | `d0` |
| `01` | `d1` |
| `10` | `d2` |
| `11` | `d3` |

Internally this is done in two stages: `sel[0]` first narrows `{d0,d1}` to
one candidate and `{d2,d3}` to another, then `sel[1]` picks between those
two candidates.

## 3. Why It Is Useful

Real muxes are rarely built as one giant `case`; tree composition from 2:1
cells is exactly how wide multiplexers are assembled from a technology
library's mux primitive, and the same tree shape reappears in register
read-muxes, cache way-select, and pipeline bypass networks.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `sel` | input | 2 | Selects `d0`..`d3` (binary-encoded) |
| `d0` | input | `WIDTH` | Data input for `sel = 00` |
| `d1` | input | `WIDTH` | Data input for `sel = 01` |
| `d2` | input | `WIDTH` | Data input for `sel = 10` |
| `d3` | input | `WIDTH` | Data input for `sel = 11` |
| `y` | output | `WIDTH` | Selected data |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 1 | Bus width of every data port and `y` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `lo` | `WIDTH` | First-stage result: `d0` or `d1`, chosen by `sel[0]` |
| `hi` | `WIDTH` | First-stage result: `d2` or `d3`, chosen by `sel[0]` |

`y` itself is the second-stage `mux2to1` output, chosen from `{lo,hi}` by
`sel[1]`.

## 6. Architecture

```
 d0 ──┐
      ├─[mux_lo: sel[0]]── lo ──┐
 d1 ──┘                          ├─[mux_out: sel[1]]── y
 d2 ──┐                          │
      ├─[mux_hi: sel[0]]── hi ──┘
 d3 ──┘
```

A two-level binary tree of 2:1 muxes; `sel[0]` fans out to both first-stage
muxes, `sel[1]` drives only the final stage.

## 7. Module Hierarchy and Connections

```
tb_mux4to1
├── dut1 : mux4to1 #(.WIDTH(1))
│   ├── mux_lo  : mux2to1 (sel[0], d0, d1) -> lo
│   ├── mux_hi  : mux2to1 (sel[0], d2, d3) -> hi
│   └── mux_out : mux2to1 (sel[1], lo, hi) -> y
└── dut8 : mux4to1 #(.WIDTH(8))
    └── (same three mux2to1 instances, WIDTH=8)
```

`WIDTH` is passed down unchanged from `mux4to1` to every `mux2to1` instance,
so the whole tree resizes together.

## 8. Verilog Concepts Used

* Structural instantiation of a smaller module (`mux2to1`) to build a larger
  one, with named port connections.
* Parameter propagation (`#(.WIDTH(WIDTH))`) through a hierarchy level.
* Internal `wire`s (`lo`, `hi`) connecting instances.
* A reference-model `function` in the testbench (`pick1`/`pick8`) instead of
  re-deriving the mux logic inline.

## 9. Source Code Explanation

```verilog
module mux4to1 #(
    parameter WIDTH = 1
) (
    input  wire [1:0]       sel,
    input  wire [WIDTH-1:0] d0, d1, d2, d3,
    output wire [WIDTH-1:0] y
);
    wire [WIDTH-1:0] lo, hi;

    mux2to1 #(.WIDTH(WIDTH)) mux_lo (.sel(sel[0]), .d0(d0), .d1(d1), .y(lo));
    mux2to1 #(.WIDTH(WIDTH)) mux_hi (.sel(sel[0]), .d0(d2), .d1(d3), .y(hi));
    mux2to1 #(.WIDTH(WIDTH)) mux_out(.sel(sel[1]), .d0(lo), .d1(hi), .y(y));
endmodule
```

* `mux_lo` and `mux_hi` both use `sel[0]` as their select input, running in
  parallel to produce the two first-stage candidates `lo` and `hi`.
* `mux_out` uses `sel[1]` to choose between `lo` and `hi`, producing the
  final `y`. Because `sel[1]` only needs to settle after `sel[0]`'s effect
  has propagated through one mux level, this is a genuine 2-level tree, not
  a re-implementation of a 4-way case in disguise.
* `#(.WIDTH(WIDTH))` on every instance re-uses the parent's `WIDTH`, so a
  single override at the `mux4to1` instantiation resizes the entire tree.

## 10. Testbench Explanation

`tb_mux4to1` instantiates `dut1` (`WIDTH=1`) and `dut8` (`WIDTH=8`):

1. `dut1`: the 6-bit combination `{sel, d0, d1, d2, d3}` is swept from 0 to
   63 (all 64 states), and each output is checked against the `pick1`
   reference function, which selects the expected bit independently of the
   mux-tree structure.
2. `dut8`: 100 random 8-bit values are generated for `d0..d3`; for each set,
   all four `sel` values are applied and checked against `pick8`.

Every check increments `checks`; a mismatch increments `errors` and prints
an `ERROR:` line with time, all inputs, expected and actual values. The
final line is `TEST PASSED: 464 checks` (64 exhaustive + 400 random-driven)
or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive 1-bit | `{sel,d0,d1,d2,d3}` = 0..63 | `y` matches the truth table for every combination |
| 2 | Random 8-bit | 100 random `(d0,d1,d2,d3)` sets x 4 `sel` values | `y` equals the selected input bus |

All 64 states of the 1-bit instance (100% of its input space) plus 400
randomized checks of the 8-bit instance are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 033` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_mux4to1` — **PASS**

```text
WIDTH=1 exhaustive (64 combinations):
WIDTH=8 random (100 vectors x 4 sel values):
done: 464 checks
TEST PASSED: 464 checks
tb/tb_mux4to1.v:95: $finish called at 464000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 3 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The tree structure adds one extra mux level of delay compared to a flat
  4-way case, but keeps every stage a simple 2:1 mux, which is how
  technology libraries and FPGA LUTs actually implement selection.
* Yosys folds the three `mux2to1` cells into 3 mux primitives (`stat`
  reports 3 cells) — no logic is lost or duplicated by the hierarchy.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Assuming `sel[1]` alone picks `{d0,d1}` vs `{d2,d3}` — it is `sel[0]` that
  distinguishes within each pair, and `sel[1]` that distinguishes between
  pairs; swapping the roles silently reorders the truth table.
* Forgetting to pass `WIDTH` down to the inner `mux2to1` instances, which
  would leave them stuck at the default width of 1 regardless of the outer
  parameter.

## 15. Possible Improvements

* Generalize to an 8:1 mux by adding another tree level (a `case`-based
  8:1 mux is instead shown directly in program 034 for comparison).
* Replace the fixed two-level tree with a `generate`-for loop for an
  arbitrary power-of-two fan-in (done generically in program 035).

## 16. What This Program Teaches

* Composing a wider structural block from a previously verified smaller
  one, with parameters threaded through the hierarchy.
* How a binary selector decomposes into independent select bits at each
  tree level.
* Writing a testbench reference model as a reusable `function` instead of
  duplicating the DUT's logic inline.

## 17. Industry Relevance

Wide multiplexers in real designs (register file read ports, cache way
selection, crossbar inputs) are built exactly this way: a balanced tree of
small mux cells, because that is what standard-cell libraries provide and
what timing tools can pipeline stage-by-stage if needed.

## 18. How to Run

```bash
python3 scripts/run.py 033            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/033-mux-4to1 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/mux2to1.v src/mux4to1.v tb/tb_mux4to1.v
vvp build/sim.vvp +vcd
```
