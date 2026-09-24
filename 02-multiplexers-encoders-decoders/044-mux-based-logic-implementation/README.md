# 044 — Implementing a Boolean Function with a Multiplexer (Shannon Expansion)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Elementary | `mux_function` | `src/mux2to1.v`, `src/mux4to1.v`, `src/mux_function.v` | `tb/tb_mux_function.v` |

## 1. Objective

Show that a general-purpose multiplexer is not only a data-selection block
but also a universal logic element: implement a 3-input Boolean function
using a single 4:1 mux and Shannon expansion, instead of a sum-of-products
or `case` expression.

## 2. What the Design Does

`mux_function` implements the 3-input **majority function**:

```
f(a,b,c) = 1  iff at least two of {a,b,c} are 1
         = a&b | b&c | a&c
```

| `a` | `b` | `c` | `y` |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 0 |
| 0 | 1 | 0 | 0 |
| 0 | 1 | 1 | 1 |
| 1 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 |
| 1 | 1 | 0 | 1 |
| 1 | 1 | 1 | 1 |

but the RTL never writes this expression directly — it is realized entirely
by the `mux4to1` instance from program 033, wired according to a Shannon
expansion of `f` around `a` and `b`.

## 3. Why It Is Useful

Shannon expansion (`f = a'·f|_{a=0} + a·f|_{a=1}`) is the theoretical basis
for LUT-based FPGA logic: every FPGA logic cell is fundamentally a small
multiplexer selecting between stored truth-table bits, addressed by the
cell's inputs. Understanding how to expand a function around some of its
variables and drop the residuals into a mux's data inputs is exactly how a
synthesis tool maps arbitrary logic onto LUTs internally.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | Function input (used as the mux's `sel[1]`, i.e. MSB of `{a,b}`) |
| `b` | input | 1 | Function input (used as the mux's `sel[0]`, i.e. LSB of `{a,b}`) |
| `c` | input | 1 | Function input (appears only in the mux's data inputs) |
| `y` | output | 1 | `majority(a,b,c)` |

No parameters.

## 5. Internal Signals

None beyond the `mux4to1` instance's own internal `lo`/`hi` wires (see
program 033); `mux_function` itself introduces no new signals — its four
data inputs are the constants `1'b0`, `c`, `c`, and `1'b1`.

## 6. Architecture

Expanding `f(a,b,c)` around `a` and `b` gives four residual functions of
`c` alone, one per `(a,b)` combination:

| `a` | `b` | Residual `f(a,b,c)` as a function of `c` |
|---|---|---|
| 0 | 0 | `0` (constant) |
| 0 | 1 | `c` |
| 1 | 0 | `c` |
| 1 | 1 | `1` (constant) |

```
 sel = {a,b} ──┐
               │
 d0 = 0   ─────┤
 d1 = c   ─────┼──[ mux4to1 ]──── y
 d2 = c   ─────┤
 d3 = 1   ─────┘
```

Each residual becomes one of the mux's four data inputs; `{a,b}` becomes
the 2-bit select, and the mux itself performs no Boolean computation beyond
routing — all of the function's logic is captured by *which constant or
signal* is wired to each data input.

## 7. Module Hierarchy and Connections

```
tb_mux_function
└── dut : mux_function
    └── mux_inst : mux4to1 (sel={a,b}, d0=0, d1=c, d2=c, d3=1) -> y
        ├── mux_lo  : mux2to1
        ├── mux_hi  : mux2to1
        └── mux_out : mux2to1
```

`mux_function` adds no gates of its own; it only wires `mux4to1`'s ports to
the constants and signals derived from the Shannon expansion.

## 8. Verilog Concepts Used

* Reuse of a previously verified structural block (`mux4to1`, program 033)
  to implement logic, not just data selection.
* Constant (`1'b0`, `1'b1`) and direct-signal (`c`) port connections mixed
  in the same instantiation.
* Bit concatenation (`{a, b}`) to form a 2-bit select from two separate
  1-bit signals.
* Shannon expansion as a design methodology, expressed purely through
  wiring rather than any new RTL logic construct.

## 9. Source Code Explanation

```verilog
module mux_function (
    input  wire a, b, c,
    output wire y
);
    mux4to1 #(.WIDTH(1)) mux_inst (
        .sel({a, b}),
        .d0(1'b0),   // a=0,b=0 residual: f = 0
        .d1(c),      // a=0,b=1 residual: f = c
        .d2(c),      // a=1,b=0 residual: f = c
        .d3(1'b1),   // a=1,b=1 residual: f = 1
        .y(y)
    );
endmodule
```

* `{a, b}` packs `a` as the MSB and `b` as the LSB of the mux's 2-bit
  `sel`, matching `mux4to1`'s own convention (`sel=00→d0`, `01→d1`,
  `10→d2`, `11→d3`, as documented in program 033): `sel=00` corresponds to
  `a=0,b=0`, `sel=01` to `a=0,b=1`, and so on.
* Each `d`-port is wired to exactly the residual value derived in section
  6: `d0` and `d3` are tied to constants because those residuals do not
  depend on `c` at all, while `d1` and `d2` are wired directly to `c`
  because those residuals equal `c` exactly.
* No `assign`, `always`, or explicit gate appears anywhere in this module —
  every bit of the function's logic is expressed by the choice of what is
  connected to each mux input, which is the essence of "mux-based logic
  implementation."

## 10. Testbench Explanation

`tb_mux_function` is exhaustive: `{a,b,c}` is only 3 bits, so all 8
combinations are covered in one run.

1. `{a,b,c}` is driven from a `for` loop over `i = 0..7`.
2. After a `#1` settling delay, the bench computes
   `expected = (a&b) | (b&c) | (a&c)` — the majority function written as a
   direct sum-of-products, completely independently of the mux/Shannon
   structure used in the DUT — and compares it against `y`.
3. Every combination prints a truth-table row; any mismatch prints an
   `ERROR:` line with time, inputs, expected and actual values.

Because the reference model (`(a&b)|(b&c)|(a&c)`) and the DUT
(`mux4to1` wired per the Shannon expansion) compute the same function two
structurally unrelated ways, agreement across all 8 cases is strong
evidence that the expansion in section 6 was carried out correctly. The
final line is `TEST PASSED: 8 checks` or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | `a` | `b` | `c` | Expected `y` |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0 |
| 2 | 0 | 0 | 1 | 0 |
| 3 | 0 | 1 | 0 | 0 |
| 4 | 0 | 1 | 1 | 1 |
| 5 | 1 | 0 | 0 | 0 |
| 6 | 1 | 0 | 1 | 1 |
| 7 | 1 | 1 | 0 | 1 |
| 8 | 1 | 1 | 1 | 1 |

All 8 cases (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 044` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_mux_function` — **PASS**

```text
a b c | y (majority)
 0 0 0 | 0
 0 0 1 | 0
 0 1 0 | 0
 0 1 1 | 1
 1 0 0 | 0
 1 0 1 | 1
 1 1 0 | 1
 1 1 1 | 1
done: 8 checks
TEST PASSED: 8 checks
tb/tb_mux_function.v:39: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 3 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Yosys generic synthesis reduces the whole design to 3 cells — the same
  three 2:1 mux primitives that make up `mux4to1` — confirming that
  `mux_function` itself contributes no extra logic beyond the wiring
  described in section 6.
* This technique scales: expanding around more variables needs a wider mux
  (an 8:1 mux for a 3-variable expansion leaving only a constant per data
  input, or, as done here, a 4:1 mux for a 2-variable expansion leaving a
  1-variable residual per data input).
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Miscomputing a residual (e.g. writing `d1 = ~c` instead of `d1 = c`) —
  each data input must be re-derived carefully from the truth table for
  that specific `(a,b)` row, not guessed from the function's general shape.
* Swapping which variable is the select MSB vs. LSB (`{a,b}` vs. `{b,a}`)
  without correspondingly swapping the residuals — the mux's own `sel`
  convention (section 9) must match how the truth table was read.
* Confusing this technique with simply building a `case`-based lookup table
  (034) — the point here is that the *residual functions* are wired in as
  d-inputs, some of which are signals (like `c`) rather than constants,
  which a plain lookup mux does not exploit.

## 15. Possible Improvements

* Implement a second, different 3-input function with the same `mux4to1`
  hardware, changing only the four wired residuals, to emphasize that the
  mux is a *generic* logic fabric.
* Extend to a full LUT-4 style implementation using an 8:1 or 16:1 mux with
  more variables held in the select.

## 16. What This Program Teaches

* Shannon expansion as a systematic way to reduce an N-variable function to
  a smaller mux plus per-branch residual functions.
* That a multiplexer is a universal combinational logic element, not only a
  data-routing block.
* Verifying a structurally different implementation of a known function
  (majority) against an independent, textbook sum-of-products reference.

## 17. Industry Relevance

This is conceptually identical to how every FPGA LUT works: a small
multiplexer tree selecting among stored configuration bits (or, in this
program's case, wired-in residual signals) addressed by the LUT's inputs.
Understanding mux-based function implementation is foundational to
understanding FPGA technology mapping and logic synthesis internals.

## 18. How to Run

```bash
python3 scripts/run.py 044            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/044-mux-based-logic-implementation && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/mux2to1.v src/mux4to1.v src/mux_function.v tb/tb_mux_function.v
vvp build/sim.vvp +vcd
```
