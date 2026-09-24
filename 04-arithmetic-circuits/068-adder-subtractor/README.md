# 068 — Adder/Subtractor with Flags

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Elementary | `add_sub` | `src/full_adder.v`, `src/add_sub.v` | `tb/tb_add_sub.v` |

## 1. Objective

Show how the same adder hardware computes both `a+b` and `a-b` using
two's-complement negation, and derive the standard carry/overflow/
zero/negative flag set from it.

## 2. What the Design Does

`add_sub` is a 4-bit adder whose `b` operand is conditionally
one's-complemented (`b XOR sub`) with `sub` also fed in as the chain's
`cin`, which together implement two's-complement negation of `b` exactly
when `sub=1`. It reports `result`, plus `carry_out`, `overflow`, `zero`
and `negative` flags.

## 3. Why It Is Useful

Every general-purpose ALU computes add and subtract with one adder,
never two — this is the standard technique. The four flags produced here
are exactly the ones a condition-code register (as in a real CPU) uses
for conditional branches and comparisons.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 4 | first operand |
| `b` | input | 4 | second operand |
| `sub` | input | 1 | 0 = add, 1 = subtract |
| `result` | output | 4 | `a+b` or `a-b`, wrapped to 4 bits |
| `carry_out` | output | 1 | unsigned carry (add) / NOT borrow (subtract) |
| `overflow` | output | 1 | signed two's-complement overflow |
| `zero` | output | 1 | `result == 0` |
| `negative` | output | 1 | `result[3]` (sign bit if operands are signed) |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `b_mux` | 4 | `b` unchanged (add) or bitwise-inverted (subtract) |
| `carry[3:0]` | 4 | per-stage carry chain, same role as program 064 |

## 6. Architecture

```
b_mux = b ^ {4{sub}}          // ~b when sub=1, b when sub=0
result = a + b_mux + sub      // sub also supplies cin (the "+1")
```
When `sub=0`: `b_mux=b`, `cin=0` → ordinary addition.
When `sub=1`: `b_mux=~b`, `cin=1` → `a + (~b + 1) = a + (-b) = a - b`,
the standard two's-complement identity.

```
overflow = carry[3] ^ carry[2]   // carry into vs out of the sign bit
zero     = (result == 0)
negative = result[3]
```

## 7. Module Hierarchy and Connections

```
add_sub
├── fa0 : full_adder (a[0], b_mux[0], sub)      -> result[0], carry[0]
├── fa1 : full_adder (a[1], b_mux[1], carry[0]) -> result[1], carry[1]
├── fa2 : full_adder (a[2], b_mux[2], carry[1]) -> result[2], carry[2]
└── fa3 : full_adder (a[3], b_mux[3], carry[2]) -> result[3], carry[3]
```

## 8. Verilog Concepts Used

* Bit-vector replication (`{4{sub}}`) to XOR every bit of `b` with a
  single control bit.
* Deriving standard ALU flags (carry/overflow/zero/negative) from raw
  adder signals rather than recomputing them separately.

## 9. Source Code Explanation

```verilog
wire [3:0] b_mux = b ^ {4{sub}};
full_adder fa0 (.a(a[0]), .b(b_mux[0]), .cin(sub), ...);
...
assign carry_out = carry[3];
assign overflow  = carry[3] ^ carry[2];
assign zero      = (result == 4'b0000);
assign negative  = result[3];
```
`b_mux` and feeding `sub` as `cin` together implement the "invert and add
one" two's-complement negation trick, reusing the same four full adders
for both operations. `overflow` uses the classic test: the carry
*into* the sign bit must equal the carry *out of* it, or a signed
overflow occurred (this is undefined/misleading for unsigned use —
`carry_out` is the correct flag there).

## 10. Testbench Explanation

`tb_add_sub` exhaustively drives all `16 × 16 × 2 = 512` combinations of
`{a,b,sub}`. For unsigned checking it widens `a` with a leading 1 before
subtracting `b` (`{1'b1,a} - b`) so bit 4 of the result reads back as "no
borrow" (matching `carry_out`'s add/subtract-agnostic meaning) instead of
Verilog's own 4-bit-wrapped subtraction, which would not expose a borrow
bit. For overflow/negative it computes a genuinely signed 5-bit reference
(`signed_a +/- signed_b`) and checks it against the ±8..7 representable
range.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | addition, no overflow | e.g. a=3,b=4,sub=0 | result=7, overflow=0 |
| 2 | addition, signed overflow | e.g. a=7,b=1,sub=0 | result=8 (=-8 signed), overflow=1 |
| 3 | subtraction, a≥b | e.g. a=10,b=3,sub=1 | result=7, carry_out=1 (no borrow) |
| 4 | subtraction, a<b | e.g. a=3,b=10,sub=1 | result=9 (wrap), carry_out=0 (borrow) |
| 5 | a==b subtraction | any a=b,sub=1 | result=0, zero=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 068` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_add_sub` — **PASS**

```text
TEST PASSED: 512 checks
tb/tb_add_sub.v:68: $finish called at 512000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 36 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `carry_out` and `overflow` answer different questions: `carry_out` is
  the correct flag for *unsigned* arithmetic, `overflow` for *signed*
  arithmetic on the same bits — a real ALU/condition-code register
  exposes both because software may be operating on either interpretation.
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Forgetting to also invert `cin` semantics — feeding `sub` as `cin` is
  required, not optional, for the two's-complement trick to work.
* Computing `overflow` as `carry_out` — they agree only sometimes and
  diverge exactly at the interesting overflow cases (this bug was caught
  and fixed in this program's own testbench during development: the
  original expected-value formula for subtraction used Verilog's 4-bit
  wrapped `a-b`, which silently drops the borrow bit that `carry_out`
  correctly reports).

## 15. Possible Improvements

* Parameterize the width and promote this into a minimal ALU (see
  program 081).

## 16. What This Program Teaches

* The invert-and-add-one two's-complement subtraction trick.
* How to derive carry/overflow/zero/negative flags from raw adder
  signals, and why carry and overflow are not the same flag.

## 17. Industry Relevance

Every general-purpose CPU ALU adds and subtracts with shared hardware
using exactly this technique, and exposes the same four flags (often
named C, V/O, Z, N) in its condition-code/status register for branches
and comparisons.

## 18. How to Run

```bash
python3 scripts/run.py 068            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/068-adder-subtractor && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/full_adder.v src/add_sub.v tb/tb_add_sub.v
vvp build/sim.vvp +vcd
```
