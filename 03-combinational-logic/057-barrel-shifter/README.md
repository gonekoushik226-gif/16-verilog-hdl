# 057 — Barrel Shifter (Logarithmic Mux Stages)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Intermediate | `barrel_shifter` | `src/barrel_shifter.v` | `tb/tb_barrel_shifter.v` |

## 1. Objective

Build a shifter explicitly as `log2(WIDTH)` cascaded mux/shift stages using
`generate`, instead of relying on a single wide `<<`/`>>` operator — the
same structure real hardware barrel shifters use, and typically what
synthesis tools build internally from `shifter`'s single-operator RTL in
program 056.

## 2. What the Design Does

`barrel_shifter` shifts `data` by `shamt` bit positions (left or right,
zero-filled either way) using `$clog2(WIDTH)` stages. Stage `k` either
passes its input straight through or shifts it by exactly `2^k` positions,
selected by bit `k` of `shamt`. Chaining all stages together reaches any
shift amount from `0` to `WIDTH-1` in `log2(WIDTH)` steps.

## 3. Why It Is Useful

A barrel shifter is the standard way to build a shift-by-any-amount circuit
with logarithmic (not linear) depth, and this structure — power-of-two
stages gated by successive control bits — reappears throughout this
curriculum wherever a "select one of many fixed shifts" decision is made
in `log2(N)` steps rather than `N` steps (e.g. multiplier partial-product
alignment, floating-point mantissa alignment).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | value to shift |
| `shamt` | input | `$clog2(WIDTH)` | shift amount, `0`–`WIDTH-1` |
| `left` | input | 1 | 1 = shift left, 0 = shift right |
| `result` | output | `WIDTH` | shifted value, zero-filled |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | data width (power of two) |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `stage[0..STAGES]` | `WIDTH` each | value after each of the `log2(WIDTH)` mux stages; `stage[0]=data`, `stage[STAGES]=result` |
| `shifted_left`, `shifted_right` (per stage) | `WIDTH` | this stage's candidate output if its shift is applied |

## 6. Architecture

```
data ──►[stage0: shamt[0]? shift by 1 : pass]──►[stage1: shamt[1]? shift by 2 : pass]──►...──► result
                                                            (STAGES = log2(WIDTH) stages total)
```

For `WIDTH=8`, `STAGES=3`: shift amounts of `1`, `2`, `4` are each
independently applied or skipped, and any combination reaches every value
from `0` to `7`.

## 7. Module Hierarchy and Connections

```
tb_barrel_shifter
└── dut : barrel_shifter #(.WIDTH(8))
    └── stage_gen[0..2] : generate block, one 2-way mux/shift stage each
```

## 8. Verilog Concepts Used

* `generate for` with a `genvar` building a fixed number of structurally
  identical stages, each parameterized by its own shift amount
  (`localparam SH = 1 << k`) computed from the loop index.
* An unpacked array of nets (`wire [WIDTH-1:0] stage [0:STAGES]`) used as
  the inter-stage chain, with each stage's continuous assignment written
  inside the generate loop.
* A documented Verilator false-positive and its recommended fix: `stage`
  is a genuinely acyclic forward chain (`stage[k+1]` depends only on
  `stage[k]`), but Verilator's flattener treats the whole array as one
  signal and reports `UNOPTFLAT`; a narrowly-scoped
  `/* verilator lint_off UNOPTFLAT */` around just the array declaration
  is Verilator's own documented remedy for this pattern.

## 9. Source Code Explanation

```verilog
wire [WIDTH-1:0] stage [0:STAGES];
assign stage[0] = data;

generate
    for (k = 0; k < STAGES; k = k + 1) begin : stage_gen
        localparam integer SH = (1 << k);
        wire [WIDTH-1:0] shifted_left  = stage[k] << SH;
        wire [WIDTH-1:0] shifted_right = stage[k] >> SH;
        assign stage[k+1] = shamt[k] ? (left ? shifted_left : shifted_right) : stage[k];
    end
endgenerate

assign result = stage[STAGES];
```
* `stage[0]` seeds the chain with the raw input; each iteration of the
  generate loop both computes stage `k`'s two candidate outputs
  (`shifted_left`/`shifted_right`, each a fixed shift of `2^k`) and selects
  between them (or passes `stage[k]` through unchanged) based on `shamt[k]`
  and `left`.
* `result` is simply the last stage's output, `stage[STAGES]`.
* An earlier version of this design used a hierarchical hierarchical
  reference (`stage_gen[k-1].stage_out`) between named per-instance wires
  instead of the array, intended to sidestep the Verilator warning
  structurally; Icarus Verilog rejected that specific self-referencing
  generate pattern during elaboration, so the array form with a scoped
  lint pragma was kept instead — a reminder that a "cleaner-looking"
  restructuring is only worth it if every tool in the flow actually
  accepts it.

## 10. Testbench Explanation

`tb_barrel_shifter` checks the DUT against Verilog's own `<<`/`>>`
operators as the reference ("operator model"), for:

1. **Directed patterns**: all-zero, all-ones, and all 8 walking-one
   patterns, each at every shift amount `0`–`7` in both directions.
2. **Random data**: 500 random 8-bit values from `$random(seed)` (default
   seed `1`, overridable with `+seed=<n>`), each at every shift amount in
   both directions — 8000 additional checks.

Because the reference model uses the plain shift operators directly (the
same computation `shifter`, program 056, performs with a single operator)
while the DUT computes the same result through `log2(WIDTH)` explicit
stages, agreement between the two confirms the staged structure is
behaviourally equivalent to the direct operator, not just superficially
similar.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Directed, all-zero/all-ones | 2 patterns × 8 shift amounts × 2 directions | matches `<<`/`>>` |
| 2 | Directed, walking-one | 8 patterns × 8 shift amounts × 2 directions | matches `<<`/`>>`, confirms bit tracks through every stage correctly |
| 3 | Random | 500 values × 8 shift amounts × 2 directions, seed=1 | matches `<<`/`>>` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 057` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_barrel_shifter` — **PASS**

```text
directed all-zero/all-one/walking-one patterns x all shift amounts x both directions...
  done: 160 checks, errors so far: 0
random data x all shift amounts x both directions, seed=1...
  done: 8160 checks total, errors so far: 0
TEST PASSED: 8160 checks
tb/tb_barrel_shifter.v:70: $finish called at 8160000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 49 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `STAGES = $clog2(WIDTH)` mux/shift stages gives `O(log WIDTH)` gate
  depth, versus a naive `WIDTH`-way mux selecting among every possible
  shifted value, which would need `WIDTH` wide muxes each `WIDTH` bits
  wide.
* Requires `WIDTH` to be a power of two for `shamt` to exactly cover every
  representable shift amount with one bit per stage.
* Purely combinational, no reset or clock; `result` settles after
  `STAGES` levels of logic.

## 14. Common Mistakes

* Ordering the stages from smallest to largest shift versus largest to
  smallest — both orders are mathematically equivalent here (each stage
  independently contributes its own power-of-two shift or nothing), but
  getting the loop's `SH` calculation wrong (e.g. using `k` directly
  instead of `1 << k`) silently produces a completely different, incorrect
  set of achievable shift amounts.
* Treating the Verilator `UNOPTFLAT` warning on a genuinely acyclic net
  array as if it indicated a real combinational loop — worth verifying
  (as done here, by checking the chain really is forward-only) before
  reaching for a lint suppression.
* Assuming a hierarchical generate self-reference (`block[k-1].signal`)
  works identically across simulators — the pattern that failed to
  elaborate in Icarus Verilog here is accepted by some other tools.

## 15. Possible Improvements

* Add an arithmetic (sign-extending) right-shift mode, mirroring
  `shifter`'s `arith` control.
* Parameterize non-power-of-two widths with a final narrower stage.

## 16. What This Program Teaches

* Building a logarithmic-depth structure explicitly with `generate`,
  rather than trusting a single wide operator to synthesize well.
* Diagnosing a lint warning by checking whether the flagged signal is
  genuinely cyclic before suppressing it, and using a narrowly-scoped
  pragma when it is not.
* That not every syntactically-legal-looking Verilog construct (here, a
  same-loop hierarchical generate self-reference) is portable across
  tools, and a working, well-understood alternative is preferable to a
  fragile "cleaner" one.

## 17. Industry Relevance

Barrel shifters built from `log2(N)` mux stages are standard in real ALUs,
floating-point alignment/normalization units, and any datapath needing a
shift-by-any-amount operation without paying `O(N)` depth; the
lint-warning-vs-real-bug judgment call made here is a routine part of
real RTL sign-off.

## 18. How to Run

```bash
python3 scripts/run.py 057            # compile, simulate, synthesize, lint
cd 03-combinational-logic/057-barrel-shifter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/barrel_shifter.v tb/tb_barrel_shifter.v
vvp build/sim.vvp +vcd +seed=42
```
