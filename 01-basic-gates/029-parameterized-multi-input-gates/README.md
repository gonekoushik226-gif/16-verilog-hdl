# 029 — Parameterized Multi-Input Gates

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Elementary | `multi_input_gates` | `src/multi_input_gates.v` | `tb/tb_multi_input_gates.v` |

## 1. Objective

Generalize the fixed 2-input gates of 017-023 to an arbitrary bus width
using a `parameter` and Verilog's unary **reduction operators**, and
verify the generalization is correct by exhaustively testing two very
different widths from the same source code.

## 2. What the Design Does

`multi_input_gates #(N)` takes one `N`-bit bus `a` and produces the AND,
OR, XOR, NAND, NOR and XNOR of *all* `N` bits combined into a single-bit
result each:

| Output | Meaning |
|---|---|
| `y_and` | 1 iff every bit of `a` is 1 |
| `y_or` | 1 iff at least one bit of `a` is 1 |
| `y_xor` | 1 iff an odd number of bits of `a` are 1 (parity) |
| `y_nand`, `y_nor`, `y_xnor` | complements of the three above |

For `N = 2` this collapses exactly to the six 2-input gates of 017-023.

## 3. Why It Is Useful

Reduction operators are how "all enables asserted", "any error flag set",
or "odd/even parity of a word" are expressed in real RTL without writing
an explicit loop — they compile to a balanced tree of 2-input gates
automatically sized to `N`.

## 4. Interface

| Parameter | Default | Description |
|---|---|---|
| `N` | 4 | Width of the input bus |

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | `N` | Bus to reduce |
| `y_and`, `y_or`, `y_xor` | output | 1 | Reduction-AND/OR/XOR of `a` |
| `y_nand`, `y_nor`, `y_xnor` | output | 1 | Complements of the above |

## 5. Internal Signals

None — every output is a direct reduction of the input bus.

## 6. Architecture

```
        ┌──[ &a ]── y_and ──[NOT]── y_nand
 a[N-1:0]─┤
        ├──[ |a ]── y_or  ──[NOT]── y_nor
        │
        └──[ ^a ]── y_xor ──[NOT]── y_xnor
```

Synthesis expands each reduction operator into a balanced tree of
`N-1` 2-input gates of the corresponding type (e.g. `&a` on an 8-bit bus
becomes 7 AND gates arranged in a tree, not a single 8-input gate cell).

## 7. Module Hierarchy and Connections

```
tb_multi_input_gates
├── dut3 : multi_input_gates #(.N(3))
└── dut8 : multi_input_gates #(.N(8))
```

The same module is instantiated twice with different `N`, driven by two
independently-sized stimulus buses.

## 8. Verilog Concepts Used

* `parameter N` with a default value, overridden per instance (`#(.N(3))`,
  `#(.N(8))`).
* Unary reduction operators `&`, `|`, `^` (already introduced on fixed
  4-bit buses in 006, here applied to a *parameterized* width).
* Two differently-parameterized instances of one module driven and
  checked in the same testbench.

## 9. Source Code Explanation

```verilog
module multi_input_gates #(
    parameter N = 4
) (
    input  wire [N-1:0] a,
    output wire         y_and, y_or, y_xor, y_nand, y_nor, y_xnor
);
    assign y_and  = &a;
    assign y_or   = |a;
    assign y_xor  = ^a;
    assign y_nand = ~&a;
    assign y_nor  = ~|a;
    assign y_xnor = ~^a;
endmodule
```

`&a` folds every bit of `a` with AND (`a[N-1] & a[N-2] & ... & a[0]`); `|a`
and `^a` do the same with OR and XOR respectively. The three
complementary outputs simply invert the corresponding reduction. None of
this code depends on the numeric value of `N` — the same six lines work
for `N=1` through any width the target technology can support.

## 10. Testbench Explanation

`tb_multi_input_gates` instantiates the DUT twice, `dut3` with `N=3` and
`dut8` with `N=8`, and sweeps **every** value of each bus exhaustively
(2³ = 8 combinations, then 2⁸ = 256 combinations — both within the
repository's ≤ 2¹⁶ exhaustive-testing guideline). For each value it
computes `&a`, `|a`, `^a` independently with the same operators (a
reference computed the same way is still an independent check here
because it is evaluated by the simulator's expression engine on the
testbench's own copy of the vector, not read back from the DUT) and
compares all six outputs. Mismatches print an `ERROR:` line naming the
width, gate and vector; the run ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

* `N = 3`: all 8 input vectors (100% of the input space for that width).
* `N = 8`: all 256 input vectors (100% of the input space for that width).
* Each vector checks all 6 outputs (6 × (8 + 256) = 1584 checks total).

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 029` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_multi_input_gates` — **PASS**

```text
N=3 sweep done: 8 combinations
N=8 sweep done: 256 combinations
TEST PASSED: 1584 checks
tb/tb_multi_input_gates.v:67: $finish called at 264000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 12 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Reduction-XOR (`^a`) synthesizes to a full XOR tree, which is
  significantly larger than reduction-AND/OR for wide buses (XOR gates use
  more transistors, as noted in 022); wide parity trees are a real area
  cost worth remembering when `N` grows.
* Purely combinational — no clock or reset; timing scales roughly with
  `log2(N)` gate delays through the reduction tree.

## 14. Common Mistakes

* Assuming `&a` is the same as `a[0] & a[1] & ... & a[N-1]` written with
  the wrong bit range for a descending vs. ascending vector declaration —
  reduction operators fold every bit regardless of declared direction, so
  this specific mistake does not apply, but indexing individual bits by
  hand (instead of using the reduction operator) is where such
  off-by-range errors actually occur.
* Forgetting that reduction operators return exactly 1 bit — trying to
  assign `&a` to a multi-bit signal is a width mismatch, not a synthesis
  shortcut.

## 15. Possible Improvements

* Add a `POPCOUNT`-style output (see 055) that returns the *count* of set
  bits rather than a single reduced bit.
* Parameter-sweep the synthesis cell count across several `N` values to
  show the tree growing.

## 16. What This Program Teaches

* Parameterizing a gate-level building block instead of hand-writing one
  version per width.
* Testing a parameterized module at more than one width in a single
  testbench.
* Reduction operators as the N-input generalization of 017-023's fixed
  2-input gates.

## 17. Industry Relevance

Every "all done" / "any error" / "parity of this word" signal in
production RTL is a reduction operator; register files, bus protocols and
memory controllers use them constantly for status and control logic.

## 18. How to Run

```bash
python3 scripts/run.py 029
cd 01-basic-gates/029-parameterized-multi-input-gates && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/multi_input_gates.v tb/tb_multi_input_gates.v
vvp build/sim.vvp +vcd
```
