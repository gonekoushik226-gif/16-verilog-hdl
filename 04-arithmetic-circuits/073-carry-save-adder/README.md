# 073 — Carry-Save Adder (Three-Operand)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `three_operand_adder` | `src/full_adder.v`, `src/csa_layer.v`, `src/three_operand_adder.v` | `tb/tb_three_operand_adder.v` |

## 1. Objective

Add three numbers using only one ripple-carry delay total, by "saving"
rather than immediately resolving the carries from a first reduction
pass — the technique multi-operand reduction trees like Wallace
multipliers (program 078) build on.

## 2. What the Design Does

`three_operand_adder` adds three 8-bit operands `a`, `b`, `c`. A
`csa_layer` first reduces them, bit by bit and independently at each bit
position, to a `sum` vector (`x^y^z` per bit) and a `carry` vector
(majority(`x,y,z`) per bit) — no carry propagates between bit positions
in this stage. The carry vector is then shifted left one position (each
saved carry belongs to the next-higher bit weight) and added to the sum
vector with one ordinary ripple-carry adder to produce the final 10-bit
total.

## 3. Why It Is Useful

Adding N numbers by chaining N-1 ordinary adders costs N-1 ripple delays.
A carry-save layer reduces *any* number of same-weight bits at one
position to two outputs (sum, carry) in a single full-adder delay,
independent of how many bits went in — this is a "3:2 compressor" applied
once here for three operands, and repeatedly in larger reduction trees.
Only the very last combination step needs a real carry-propagate adder.

## 4. Interface

**`three_operand_adder`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b`, `c` | input | 8 each | operands to add |
| `sum` | output | 10 | `a + b + c`, wide enough for no overflow |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | operand width |

**`csa_layer`**: `x`, `y`, `z` (`WIDTH` bits each) in; `sum`, `carry`
(`WIDTH` bits each) out.

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `csum` | 8 | bitwise `a^b^c` from the carry-save layer |
| `ccarry` | 8 | bitwise majority(`a,b,c`) from the carry-save layer, still at its own bit weight |
| `op1`, `op2` | 10 each | `csum` and `ccarry<<1`, widened and aligned for the final add |

## 6. Architecture

```
a,b,c (8 bits each)
      |
  [csa_layer] -- 8 independent full adders, one per bit position
      |
  csum[7:0], ccarry[7:0]
      |
  op1 = {2'b00, csum}
  op2 = {1'b0, ccarry, 1'b0}   <- ccarry shifted left 1 (its bits are one weight higher)
      |
  [ripple add via full_adder chain] -- one more pass, WIDTH+2 bits wide
      |
  sum[9:0]
```

## 7. Module Hierarchy and Connections

```
three_operand_adder
├── csa : csa_layer #(WIDTH=8) (a, b, c) -> csum, ccarry
│           └── bitslice[0..7] : full_adder (generate loop, no inter-bit link)
└── final_stage[0..9] : full_adder (generate loop, ripples op1+op2)
```

## 8. Verilog Concepts Used

* A "3:2 compressor" realized as a bit-sliced array of independent
  `full_adder`s (no carry chain within the array itself).
* Bit-vector concatenation/padding (`{2'b00, csum}`, `{1'b0, ccarry,
  1'b0}`) to align the carry-save outputs to the correct bit weight
  before the final add.
* Two separate `generate for` loops in the same module for two distinct
  purposes (compression, then final ripple).

## 9. Source Code Explanation

`csa_layer` instantiates `WIDTH` independent full adders where each
adder's three inputs are the same-weight bit from each of the three
operands (`x[i]`, `y[i]`, `z[i]`) — not a chain, since `cin` of each
adder is simply `z[i]`, unrelated to any neighboring bit. Its `sum[i]`
and `carry[i]` outputs are therefore both still at bit-weight `i`, except
`carry[i]` actually represents a value that *belongs* one bit higher
(a carry out of position `i` has weight `2^(i+1)`). `three_operand_adder`
corrects for that by left-shifting `ccarry` before the final ripple-carry
add (built inline from another `full_adder` generate loop) combines
`csum` and the shifted `ccarry` into the true sum.

## 10. Testbench Explanation

`tb_three_operand_adder` drives 3000 random 8-bit `(a,b,c)` triples plus
the all-maximum (`0xFF,0xFF,0xFF`), all-zero, and single-operand corner
cases, comparing the 10-bit `sum` against a wide Verilog reference
`a+b+c`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | random | 3000 random `(a,b,c)` | matches `a+b+c` |
| 2 | maximum | a=b=c=0xFF | sum=765 |
| 3 | zero | a=b=c=0x00 | sum=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 073` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_three_operand_adder` — **PASS**

```text
TEST PASSED: 3003 checks
tb/tb_three_operand_adder.v:48: $finish called at 3003000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 126 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Only two sequential addition delays total (one compress, one final
  ripple), regardless of how many operands were being reduced by the
  compression stage — here just three, but the same csa_layer pattern
  scales to more operands by cascading additional layers before the
  final add.
* `sum` is deliberately 10 bits (`WIDTH+2`) so the maximum possible total
  (`3 x 255 = 765`) never overflows.

## 14. Common Mistakes

* Forgetting to shift `ccarry` left before the final add — each carry-out
  bit belongs one position higher than the bit it came from.
* Confusing this with a normal 3-input ripple chain — a carry-save layer
  deliberately does *not* propagate carries between bit positions in its
  own stage; that is the entire point.

## 15. Possible Improvements

* Cascade a second `csa_layer` to reduce four operands to two in one more
  compression pass before the final add, generalizing toward a full
  Wallace-tree-style reduction (see program 078).

## 16. What This Program Teaches

* The carry-save principle: reducing three numbers to two (sum, carry)
  in one full-adder delay, independent of width.
* Why only the final combining step needs a real (carry-propagating)
  adder.

## 17. Industry Relevance

Carry-save addition is the foundation of every fast multi-operand
reduction structure — array and Wallace-tree multipliers (076, 078), MAC
units (218), and FIR filter accumulation (219) all use carry-save
reduction internally to avoid paying a full ripple-carry delay at every
intermediate addition.

## 18. How to Run

```bash
python3 scripts/run.py 073            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/073-carry-save-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/full_adder.v src/csa_layer.v src/three_operand_adder.v tb/tb_three_operand_adder.v
vvp build/sim.vvp +vcd
```
