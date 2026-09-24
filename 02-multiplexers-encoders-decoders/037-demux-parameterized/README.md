# 037 — Parameterized 1-to-N Demultiplexer

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Elementary | `demux_n` | `src/demux_n.v` | `tb/tb_demux_n.v` |

## 1. Objective

Generalize the fixed 1:4 demultiplexer of program 036 to an arbitrary
output count `N` using a `generate`-for loop, and verify it at two
independent `(N, WIDTH)` parameter sets.

## 2. What the Design Does

`demux_n` routes `d` onto output `i` of a flattened `N*WIDTH`-bit bus `y`
when `sel == i`, and drives every other output slot to zero:

```
y[i*WIDTH +: WIDTH] = (sel == i) ? d : 0,   for i = 0 .. N-1
```

This is the same behaviour as `demux1to4` (program 036) but written once
per output by a loop, and generalized to any `N`, instead of four
hand-written `assign` statements limited to `N = 4`.

## 3. Why It Is Useful

Once a demultiplexer needs more than a handful of outputs (an 8-way or
16-way peripheral chip-select bus, for example), hand-writing one `assign`
per output does not scale or stay maintainable. A `generate`-for loop
produces exactly the same hardware — one comparator and gate per output —
for any `N` without repeating source text.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `sel` | input | `$clog2(N)` | Index of the output to activate (0 .. N-1) |
| `d` | input | `WIDTH` | Data to route |
| `y` | output | `N*WIDTH` | `N` flattened `WIDTH`-bit outputs; output `i` at bits `[i*WIDTH +: WIDTH]` |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | Bits per output element |
| `N` | 4 | Number of outputs; must be a power of 2 so every `sel` code selects a real output |

## 5. Internal Signals

None — every output slot is a direct function of `sel` and `d`.

## 6. Architecture

```
              i = 0: y[0*WIDTH +: WIDTH] = (sel==0) ? d : 0
 d ───────┬── i = 1: y[1*WIDTH +: WIDTH] = (sel==1) ? d : 0
 sel ─────┤   ...
          └── i = N-1: y[(N-1)*WIDTH +: WIDTH] = (sel==N-1) ? d : 0
```

`N` identical comparator+gate slices, one per generate-loop iteration, all
driven by the same `sel` and `d`.

## 7. Module Hierarchy and Connections

```
tb_demux_n
├── dutA : demux_n #(.WIDTH(4), .N(4))
│   └── demux_out[0..3] : generate-block instances (not separate modules)
└── dutB : demux_n #(.WIDTH(2), .N(8))
    └── demux_out[0..7] : generate-block instances
```

`generate`-for produces named blocks (`demux_out[0]` .. `demux_out[N-1]`),
visible in waveform/hierarchy browsers as if they were instances, but they
are `assign` statements, not separate module instantiations.

## 8. Verilog Concepts Used

* `genvar` and `generate ... for` to replicate one `assign` statement `N`
  times at elaboration time.
* A named generate block (`begin : demux_out`) so each replicated statement
  has a distinct hierarchical name.
* `$clog2(N)` in a port declaration, continuing from program 035.
* Indexed part-select (`+:`) on the output side, writing into a flattened
  bus instead of reading from one.
* Two independently parameterized instances of the same module in one
  testbench.

## 9. Source Code Explanation

```verilog
genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : demux_out
        assign y[i*WIDTH +: WIDTH] = (sel == i) ? d : {WIDTH{1'b0}};
    end
endgenerate
```

* `genvar i` declares a generate-time loop variable — it exists only during
  elaboration, not in the final hardware.
* The `for` loop runs `N` times, each time creating one `assign` statement
  with `i` replaced by its current value (0, 1, ..., N-1); the result is
  exactly `N` independent continuous assignments, identical in structure to
  writing them out by hand for `N=4` as `demux1to4` does.
* `begin : demux_out` names the block so each generated instance gets a
  unique hierarchical path (`demux_out[0]`, `demux_out[1]`, ...), which is
  required whenever a generate block contains declarations or is
  cross-referenced (and is good practice even when, as here, it is not
  strictly required) for debug visibility.
* `sel == i` compares the runtime signal `sel` against the elaboration-time
  constant `i`; Verilog automatically sizes `i` for the comparison.

## 10. Testbench Explanation

`tb_demux_n` instantiates two parameter sets, chosen so both input spaces
stay small enough to test exhaustively:

1. `dutA` (`N=4, WIDTH=4`): `sel` (4 values) and `d` (16 values) are swept
   through every combination (64 total). For each combination, a nested
   loop reads every `WIDTH`-bit slot of `y` and checks it equals `d` when
   the slot index matches `sel`, and zero otherwise.
2. `dutB` (`N=8, WIDTH=2`): the same exhaustive strategy is applied with
   `sel` over 8 values and `d` over 4 values (32 total combinations).

Every combination increments `checks` once (regardless of how many of the
`N` output slots were internally examined); a mismatch anywhere in a
combination's outputs increments `errors` and prints an `ERROR:` line with
`sel`, `d` and the full output bus. The final line is `TEST PASSED: 96
checks` (64 + 32) or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive, `N=4, WIDTH=4` | `sel` x `d` = 4 x 16 | Slot `sel` = `d`, all others = 0 |
| 2 | Exhaustive, `N=8, WIDTH=2` | `sel` x `d` = 8 x 4 | Slot `sel` = `d`, all others = 0 |

Both parameter sets are exercised over 100% of their `{sel, d}` input space.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 037` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_demux_n` — **PASS**

```text
N=4 WIDTH=4 exhaustive (64 combinations):
N=8 WIDTH=2 exhaustive (32 combinations):
done: 96 checks
TEST PASSED: 96 checks
tb/tb_demux_n.v:87: $finish called at 96000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 36 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The `generate`-for loop produces identical hardware to N hand-written
  `assign` statements; Yosys reports 36 cells for `N=8, WIDTH=2` plus
  `N=4, WIDTH=4` combined, consistent with one comparator+gate group per
  output bit.
* Like `mux_n` (035), `N` is required to be a power of 2 so `$clog2(N)`
  produces no unused `sel` codes; a non-power-of-2 `N` would need an
  explicit `sel < N` catch-all before falling back to all-zero outputs.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Forgetting the generate block label (`begin : demux_out`) when the block
  contains more than one statement or local declarations — some tools
  require it, and it is always good practice for readability in hierarchy
  browsers.
* Off-by-one errors in the loop bound (`i < N` vs `i <= N`), which would
  either miss the last output or generate one output too many.
* Re-declaring `genvar i` in another generate loop in the same module
  scope without giving it a different name, which is illegal.

## 15. Possible Improvements

* Add a bounds guard for non-power-of-2 `N`.
* Combine with `mux_n` (035) into a matched encode/decode pair over the
  same flattened-bus convention.

## 16. What This Program Teaches

* Using `generate`-for to replicate combinational logic a parameterized
  number of times instead of hand-writing repetitive `assign` statements.
* Writing into (rather than reading from) a flattened bus with indexed
  part-select.
* Verifying generated hardware exhaustively at more than one parameter set
  in a single testbench run.

## 17. Industry Relevance

`generate`-for is the standard way real RTL scales a fixed piece of logic
to a parameterized width or fan-out — bus decoders, memory bank selectors
and register file write-enable trees in production designs are written
exactly this way so the same source supports many configurations.

## 18. How to Run

```bash
python3 scripts/run.py 037            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/037-demux-parameterized && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/demux_n.v tb/tb_demux_n.v
vvp build/sim.vvp +vcd
```
