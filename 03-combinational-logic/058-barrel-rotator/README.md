# 058 — Barrel Rotator (Double-Width Trick)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Intermediate | `barrel_rotator` | `src/barrel_rotator.v` | `tb/tb_barrel_rotator.v` |

## 1. Objective

Implement left/right circular rotation using the "double-width" technique
— concatenating the data with itself and reading out a plain windowed
part-select — instead of explicit wrap-around logic, and verify the
technique against both a reference formula and a round-trip property.

## 2. What the Design Does

`barrel_rotator` rotates `data` by `shamt` positions, left or right
(selected by `left`), with bits that fall off one end reappearing at the
other (unlike `barrel_shifter`, which zero-fills). It builds a
`2*WIDTH`-bit value by concatenating `data` with itself, then reads out a
`WIDTH`-bit window at an offset determined by `shamt` and direction — since
both halves of the doubled value are identical copies of `data`, any
in-bounds window is automatically the correctly wrapped rotation.

## 3. Why It Is Useful

Rotation appears in cryptographic primitives (many hash and cipher
constructions use fixed or data-dependent rotate operations), CRC/LFSR
implementations, and circular buffer index management. The double-width
trick is a standard technique for turning a "circular" operation into a
"linear" one that ordinary part-select hardware can express directly.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | value to rotate |
| `shamt` | input | `$clog2(WIDTH)` | rotation amount, `0`–`WIDTH-1` |
| `left` | input | 1 | 1 = rotate left, 0 = rotate right |
| `result` | output | `WIDTH` | rotated value (no bits lost) |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | data width |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `doubled` | `2*WIDTH` | `{data, data}` — the source for the windowed read |

## 6. Architecture

```
data ──► doubled = {data, data}   (2*WIDTH bits, both halves identical)

rotate left by n:  result = doubled[(2*WIDTH-1-n) -: WIDTH]   (window starts n bits below the top copy)
rotate right by n: result = doubled[(WIDTH-1+n)   -: WIDTH]   (window starts n bits above the bottom copy)
```

## 7. Module Hierarchy and Connections

```
tb_barrel_rotator
└── dut : barrel_rotator #(.WIDTH(8))
```

## 8. Verilog Concepts Used

* Self-concatenation (`{data, data}`) to convert a circular operation into
  a linear window read.
* Indexed part-select with a **variable base** (`doubled[(2*WIDTH-1-shamt)
  -: WIDTH]`) — the base expression depends on `shamt`, while the width
  (`WIDTH`) stays a compile-time constant, exactly the form the `-:`
  operator requires.
* Contrast with `barrel_shifter`'s explicit multi-stage mux structure: this
  design reaches any rotation amount in one part-select instead of
  `log2(WIDTH)` stages, at the cost of a `2×`-wide intermediate signal.

## 9. Source Code Explanation

```verilog
wire [2*WIDTH-1:0] doubled = {data, data};

assign result = left ? doubled[(2*WIDTH-1-shamt) -: WIDTH]
                      : doubled[(WIDTH-1+shamt)   -: WIDTH];
```
* `doubled`'s upper `WIDTH` bits and lower `WIDTH` bits are both exactly
  `data`, so scanning a `WIDTH`-bit window across the boundary between them
  naturally produces every rotation of `data` as `shamt` varies from `0` to
  `WIDTH-1`.
* For `left=1`, `shamt=0` selects `doubled[2W-1 -: W]` — the upper copy,
  i.e. `data` unrotated; increasing `shamt` slides the window down,
  pulling in bits from the lower copy exactly where wrap-around should
  occur.
* For `left=0`, `shamt=0` selects `doubled[W-1 -: W]` — the lower copy,
  again `data` unrotated; increasing `shamt` slides the window up into the
  upper copy for the same reason, mirrored for the opposite direction.

## 10. Testbench Explanation

`tb_barrel_rotator` combines three kinds of checks:

1. **Directed patterns**: all-zero, all-ones, and all 8 walking-one
   patterns at every shift amount in both directions, checked against a
   shift-and-OR reference model (`(d<<n)|(d>>(WIDTH-n))` for left,
   mirrored for right) — a different computational technique from the
   RTL's double-width window, so the two cannot share a common mistake.
2. **Random data**: 500 random values at every shift amount in both
   directions, same reference model, seed `1` by default (`+seed=<n>` to
   override).
3. **Round-trip property**: `check_roundtrip` rotates a random value left
   by a random amount `k`, then rotates the result right by the same `k`,
   and checks the original value is exactly recovered — a property test
   independent of any reference formula, since a rotation and its inverse
   must always cancel regardless of which direction convention a formula
   might get backwards.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Directed patterns | 10 patterns × 8 shift amounts × 2 directions | matches shift-and-OR reference model |
| 2 | Random data | 500 values × 8 shift amounts × 2 directions, seed=1 | matches shift-and-OR reference model |
| 3 | Round-trip | 500 random `(data, k)` pairs | `rotate_right(rotate_left(data, k), k) == data` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 058` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_barrel_rotator` — **PASS**

```text
directed all-zero/all-one/walking-one patterns x all shift amounts x both directions...
  done: 160 checks, errors so far: 0
random data x all shift amounts x both directions, seed=1...
  done: 8160 checks total, errors so far: 0
round-trip property: rotate left by k then right by k...
  done: 8660 checks total, errors so far: 0
TEST PASSED: 8660 checks
tb/tb_barrel_rotator.v:100: $finish called at 9160000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 57 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The double-width trick costs one `2×`-wide concatenation signal but
  needs no explicit modulo or wrap-around conditional logic; a
  multi-stage barrel-rotator (mirroring `barrel_shifter`'s structure, with
  each stage rotating by `2^k` instead of shifting) would trade that extra
  width for `log2(WIDTH)` stages instead.
* No bits are ever lost in a rotation (unlike a shift), so there is no
  zero-fill or sign-extend decision to make — only the direction.
* Purely combinational, no reset or clock.

## 14. Common Mistakes

* Getting the window's base expression backwards between left and right
  rotation — since both directions read from the same `doubled` signal,
  swapping the two formulas produces a design that still "does something"
  but rotates the wrong way, which the round-trip property test in §10 is
  specifically designed to catch even without a known-correct reference
  formula.
* Forgetting that the `-:` operator's width must be a compile-time
  constant even though its base can be a runtime expression — `doubled[x
  -: WIDTH]` is legal, but `doubled[x -: y]` with a variable `y` is not.
* Confusing rotation with shifting — a rotation must never lose bits (only
  reorder them), unlike `barrel_shifter`'s zero-filled shift.

## 15. Possible Improvements

* Implement the same rotation with `log2(WIDTH)` generate stages (mirroring
  `barrel_shifter`) and compare synthesized area between the two
  approaches.
* Add a rotate-by-arbitrary-runtime-amount variant that supports amounts
  ≥ `WIDTH` via an internal modulo reduction.

## 16. What This Program Teaches

* The double-width windowing technique for circular operations.
* Variable-base indexed part-select (`-:` with a runtime base, constant
  width).
* Using a round-trip property test to catch a directional bug that a
  single reference formula, if written with the same directional mistake,
  might not catch.

## 17. Industry Relevance

Rotate operations are fundamental to cryptographic hash and cipher
datapaths (SHA-family rotations, ChaCha's rotate-XOR-add rounds) and CRC/
LFSR-adjacent bit manipulation; the double-width windowing technique used
here is a standard, synthesis-friendly way to implement them.

## 18. How to Run

```bash
python3 scripts/run.py 058            # compile, simulate, synthesize, lint
cd 03-combinational-logic/058-barrel-rotator && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/barrel_rotator.v tb/tb_barrel_rotator.v
vvp build/sim.vvp +vcd +seed=42
```
