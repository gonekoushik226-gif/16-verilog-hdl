# 074 — BCD Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `bcd_adder` | `src/bcd_digit_adder.v`, `src/bcd_adder.v` | `tb/tb_bcd_adder.v` |

## 1. Objective

Add decimal (BCD-encoded) numbers correctly, introducing the classic
add-6 decimal correction and cascading it across multiple digits.

## 2. What the Design Does

`bcd_digit_adder` adds two BCD digits (each 0-9) and a carry-in with
ordinary binary addition, then checks whether the 5-bit binary result
exceeds 9; if so it adds 6 and asserts a decimal carry-out. `bcd_adder`
cascades `DIGITS` (default 4) of these, chaining each digit's carry-out
into the next digit's carry-in, exactly like a ripple-carry adder but one
decimal digit at a time.

## 3. Why It Is Useful

Binary addition of two nibbles that each represent a decimal digit is not
itself decimally correct once the sum reaches 10 or more (`9+9=18` in
binary is `0b10010`, not a valid BCD digit). The +6 correction restores a
valid BCD result and a correct decimal carry, which is how packed-BCD
arithmetic (used in financial/decimal computing) is implemented in
hardware.

## 4. Interface

**`bcd_digit_adder`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 4 each | BCD digits, 0-9 |
| `cin` | input | 1 | carry in |
| `sum` | output | 4 | BCD digit result, 0-9 |
| `cout` | output | 1 | decimal carry out |

**`bcd_adder`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | `DIGITS*4` each | packed BCD digits, digit 0 = bits `[3:0]` |
| `cin` | input | 1 | carry in |
| `sum` | output | `DIGITS*4` | packed BCD digit result |
| `cout` | output | 1 | carry out of the most significant digit |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `DIGITS` | 4 | number of cascaded decimal digits |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| (digit adder) `bin_sum` | 5 | raw binary `a+b+cin` before decimal correction |
| (digit adder) `correct` | 1 | true when `bin_sum > 9`, i.e. correction is needed |
| (top) `carry[DIGITS:0]` | `DIGITS+1` | per-digit decimal carry chain |

## 6. Architecture

```
bcd_digit_adder:
  bin_sum = a + b + cin                 (5-bit binary sum)
  correct = (bin_sum > 9)
  sum  = correct ? bin_sum + 6 : bin_sum   (low 4 bits)
  cout = correct

bcd_adder (DIGITS=4):
  digit0: bcd_digit_adder(a[3:0], b[3:0], cin)        -> sum[3:0], carry[1]
  digit1: bcd_digit_adder(a[7:4], b[7:4], carry[1])   -> sum[7:4], carry[2]
  digit2: bcd_digit_adder(a[11:8], b[11:8], carry[2]) -> sum[11:8], carry[3]
  digit3: bcd_digit_adder(a[15:12], b[15:12], carry[3])-> sum[15:12], cout
```

## 7. Module Hierarchy and Connections

```
bcd_adder #(.DIGITS(N))
└── digit[0..N-1] : bcd_digit_adder (a[4i+3:4i], b[4i+3:4i], carry[i]) -> sum[4i+3:4i], carry[i+1]
```

## 8. Verilog Concepts Used

* Indexed part-select (`a[i*4 +: 4]`) to extract each packed BCD digit by
  loop index.
* A `generate for` cascade identical in shape to program 065's `rca_n`,
  but chaining decimal (not binary) carries.
* Explicit zero-extension of operands before addition
  (`{1'b0,a} + {1'b0,b} + {4'b0,cin}`) to keep result widths exact and
  avoid implicit-width-extension lint warnings.

## 9. Source Code Explanation

```verilog
wire [4:0] bin_sum = {1'b0, a} + {1'b0, b} + {4'b0, cin};
wire correct = (bin_sum > 5'd9);
wire [4:0] corrected = correct ? (bin_sum + 5'd6) : bin_sum;
assign sum = corrected[3:0];
assign cout = correct;
```
`bin_sum` is the ordinary binary sum of two digits plus carry (max value
`9+9+1=19`, fits in 5 bits). Whenever it exceeds 9, adding 6 pushes it
past the six unused nibble codes (`1010`-`1111`) and back onto a valid
BCD digit in the next decade, with `cout` correctly signalling the
decimal carry — this is the standard BCD correction identity.

## 10. Testbench Explanation

`tb_bcd_adder` runs two independent checks. `dut_digit` is driven
exhaustively over all 200 valid `(a,b,cin)` single-digit combinations
against a plain integer reference (`sum = (a+b+cin) % 10`, `cout =
(a+b+cin) >= 10`). `dut4` is driven with 2000 random 4-digit BCD numbers
(each nibble independently forced into 0-9 range) plus the `9999+9999+1`
and all-zero corners, decoded back to an integer with a `bcd_to_int`
function and compared against a full decimal reference.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | single digit, exhaustive | all 200 `(a,b,cin)` pairs | correct BCD digit + decimal carry |
| 2 | 4-digit, random | 2000 random valid BCD 4-digit pairs | correct 4-digit BCD sum + carry |
| 3 | 4-digit max | 9999+9999+1 | sum=9999 (wrapped), cout=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 074` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_bcd_adder` — **PASS**

```text
TEST PASSED: 2202 checks
tb/tb_bcd_adder.v:94: $finish called at 2202000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 136 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Each digit adder does its correction combinationally in one step; no
  additional pipeline stage is needed even though conceptually there are
  two additions (binary sum, then +6 correction) per digit.
* `bcd_adder` assumes both operands are always valid BCD (each nibble
  0-9); behavior for out-of-range nibble inputs (10-15) is not part of
  this program's contract.

## 14. Common Mistakes

* Comparing against `> 9` using a too-narrow reg (must be at least 5 bits
  to hold the max binary sum of 19 without wrapping before the compare).
* Forgetting the extra `cin` into the +6 correction check — a digit sum
  of exactly 9 plus a carry-in of 1 must also be corrected (`bin_sum=10`
  needs correcting even though `9+0=9` alone would not).

## 15. Possible Improvements

* Support BCD subtraction with a similar (-6) correction.
* Parameterize into a general N-digit packed-BCD ALU.

## 16. What This Program Teaches

* The classic decimal-correction (add-6) technique for BCD arithmetic.
* Cascading a digit-wise operation across multiple digits with a carry
  chain, structurally identical to binary ripple-carry addition.

## 17. Industry Relevance

Packed-BCD arithmetic remains relevant in financial and embedded systems
where exact decimal representation matters more than binary efficiency
(e.g. avoiding binary-fraction rounding errors in currency calculations);
some processor instruction sets still include dedicated decimal-adjust
instructions built on exactly this correction.

## 18. How to Run

```bash
python3 scripts/run.py 074            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/074-bcd-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bcd_digit_adder.v src/bcd_adder.v tb/tb_bcd_adder.v
vvp build/sim.vvp +vcd
```
