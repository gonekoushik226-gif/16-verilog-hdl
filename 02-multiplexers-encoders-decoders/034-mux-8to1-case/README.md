# 034 — 8-to-1 Multiplexer (Case-Based)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `mux8to1` | `src/mux8to1.v` | `tb/tb_mux8to1.v` |

## 1. Objective

Implement an 8-to-1 multiplexer using a behavioral `always @(*)` block with
a `case` statement, contrasting this "table lookup" coding style with the
structural mux tree of program 033.

## 2. What the Design Does

`mux8to1` routes one of eight `WIDTH`-bit inputs, `d0`..`d7`, to `y`
according to the 3-bit `sel`:

| `sel` | `y` |
|---|---|
| `000` | `d0` |
| `001` | `d1` |
| `010` | `d2` |
| `011` | `d3` |
| `100` | `d4` |
| `101` | `d5` |
| `110` | `d6` |
| `111` | `d7` |

`sel` is 3 bits wide, so every possible value is listed explicitly; the
`default` branch is unreachable but present because every `case` in this
project must have one.

## 3. Why It Is Useful

`case`-based muxes read directly as a truth table and are the natural style
when the number of inputs is fixed and moderate (register file read select,
opcode-to-operation routing); it is more readable than a chain of nested
ternaries once there are more than two or three choices.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `sel` | input | 3 | Selects `d0`..`d7` (binary-encoded) |
| `d0`..`d7` | input | `WIDTH` | Eight data inputs |
| `y` | output | `WIDTH` | Selected data |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 1 | Bus width of every data port and `y` |

## 5. Internal Signals

None — `y` is declared `reg` only because it is assigned inside an
`always` block; it still represents pure combinational logic.

## 6. Architecture

```
        ┌─────────────────────────────┐
 d0..d7 │  always @(*) case (sel)     │
   ────►│    3'd0: y = d0             │──► y
  sel   │    ...                      │
   ────►│    3'd7: y = d7             │
        │    default: y = 0           │
        └─────────────────────────────┘
```

A single combinational lookup block; no internal state or hierarchy.

## 7. Module Hierarchy and Connections

```
tb_mux8to1
└── dut : mux8to1 #(.WIDTH(8))
```

The testbench drives `sel` and `d0..d7` and observes `y` directly; there is
no further hierarchy.

## 8. Verilog Concepts Used

* `always @(*)` combinational block with a **default assignment at the top**
  to prevent an inferred latch on any path the `case` might miss.
* `case` statement with an exhaustive set of value labels and a mandatory
  `default`.
* `reg` output driven from a procedural block instead of `assign`.
* Testbench-side arrays (`data[0:7]`) and a `task` to apply them to distinct
  ports.

## 9. Source Code Explanation

```verilog
always @(*) begin
    y = {WIDTH{1'b0}};      // default assignment: avoids an inferred latch
    case (sel)
        3'd0: y = d0;
        ...
        3'd7: y = d7;
        default: y = {WIDTH{1'b0}};
    endcase
end
```

* `y = {WIDTH{1'b0}};` at the top of the block gives `y` a value on every
  simulation pass before the `case` runs; without it, if any `case` branch
  were missing, `y` would hold its previous value — an unintended latch —
  instead of updating combinationally.
* Each `case` item matches one value of `sel` and assigns the corresponding
  data input to `y`; blocking assignment (`=`) is used throughout, as
  required for combinational logic in this repository.
* `default: y = {WIDTH{1'b0}};` is unreachable here because `sel` is exactly
  3 bits (all 8 values are already listed), but the coding standard requires
  every `case` to have one regardless, to guard against future widening of
  `sel` or 4-state inputs (`x`/`z`) reaching the case expression.

## 10. Testbench Explanation

`tb_mux8to1` (`WIDTH = 8`):

1. A directed pass loads eight easily-recognisable values (`8'hA0`..`8'hA7`)
   into `data[0..7]`, applies them to the DUT, sweeps `sel` over all 8
   values, and checks `y` against `data[sel]`.
2. A randomized pass repeats this 300 times with fresh random data on every
   iteration, still sweeping the full `sel` range each time — this is the
   "exhaustive select x random data" plan from the catalog.

Every check increments `checks`; a mismatch increments `errors` and prints
an `ERROR:` line with time, `sel`, expected and actual values. The final
line is `TEST PASSED: 2408 checks` (8 directed + 2400 randomized) or a
`TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Directed | `sel` = 0..7, distinct data on each input | `y` = the input matching `sel` |
| 2 | Random data, exhaustive select | 300 random data sets x `sel` = 0..7 | `y` = `data[sel]` for every combination |

All 8 values of `sel` (100% of the select space) are exercised against both
directed and 300 independent random data sets.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 034` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_mux8to1` — **PASS**

```text
sel=0 -> y=a0 (expected a0)
sel=1 -> y=a1 (expected a1)
sel=2 -> y=a2 (expected a2)
sel=3 -> y=a3 (expected a3)
sel=4 -> y=a4 (expected a4)
sel=5 -> y=a5 (expected a5)
sel=6 -> y=a6 (expected a6)
sel=7 -> y=a7 (expected a7)
done: 2408 checks
TEST PASSED: 2408 checks
tb/tb_mux8to1.v:69: $finish called at 2408000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 32 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The default assignment before the `case` is what keeps this design
  latch-free; Yosys's `check -assert` step in `run.py` would fail the build
  if a latch were inferred.
* At `WIDTH = 8`, Yosys generic synthesis maps this to 32 cells (an 8:1
  select per bit, 8 bits wide); there is no meaningful timing/area concern
  at this scale.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Leaving out the default assignment before the `case` and relying only on
  the `default:` case item — that still leaves a latch if `sel` were ever
  driven to `x`/`z`, since `case` (not `casez`/`casex`) requires an exact
  literal match and `x` matches nothing, falling through only to whatever
  branch handles it.
* Using `assign` with a `?:` chain for many inputs instead of `case`: it
  works but becomes hard to read past 3–4 choices, which is exactly the
  readability trade-off this program demonstrates.

## 15. Possible Improvements

* Add a `casez` variant to show priority-based selection with don't-cares.
* Generalize `sel` width and input count together as one parameter (done in
  program 035's fully parameterized N:1 mux).

## 16. What This Program Teaches

* Writing a combinational `always @(*)` block that is guaranteed latch-free.
* The `case` statement as a direct, readable encoding of a truth table.
* That different DUTs performing the same logical function (033's tree vs.
  034's case) can both be exhaustively verified with equal confidence.

## 17. Industry Relevance

`case`-based multiplexing is the standard way opcode decoders, ALU
operation selects and configuration-register read muxes are written in
production RTL; synthesis tools recognize this pattern and map it onto
efficient mux/LUT structures automatically.

## 18. How to Run

```bash
python3 scripts/run.py 034            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/034-mux-8to1-case && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/mux8to1.v tb/tb_mux8to1.v
vvp build/sim.vvp +vcd
```
