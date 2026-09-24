# 008 — Signed Numbers and Two's Complement

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Elementary | `signed_ops` | `src/signed_ops.v` | `tb/tb_signed_ops.v` |

## 1. Objective

Declare and use signed values, detect signed overflow, and understand when
Verilog sign-extends and when it silently treats data as unsigned.

## 2. What the Design Does

`a` and `b` are 4-bit two's complement numbers (−8 … +7). The module outputs:

* `sum_full` (5 bits) — the exact sum, which can never overflow,
* `sum_wrap` (4 bits) — the sum truncated to 4 bits, and `overflow`,
* `neg_a` (5 bits) — so that −(−8) = +8 is representable,
* `abs_a` — magnitude as an unsigned 0–8,
* `sext_a` / `zext_a` — `a` extended to 8 bits by sign / by zeros,
* `lt_signed` / `lt_unsigned` — the same bit patterns compared both ways,
* `product` — the signed 8-bit product.

Example: `a = 7, b = 3` → `sum_full = 10` but `sum_wrap = −6` and
`overflow = 1`.

## 3. Why It Is Useful

DSP filters, audio, control loops and CPU arithmetic operate on signed data.
Getting sign extension or overflow wrong produces results that are correct for
positive values and wildly wrong for negative ones — bugs that small positive
test vectors never reveal.

## 4. Interface

| Port | Dir | Type | Description |
|---|---|---|---|
| `a`, `b` | in | `signed [3:0]` | Operands, −8…+7 |
| `sum_full` | out | `signed [4:0]` | `a + b`, exact |
| `sum_wrap` | out | `signed [3:0]` | `a + b` modulo 16 |
| `overflow` | out | 1 | `sum_wrap` is incorrect |
| `neg_a` | out | `signed [4:0]` | `−a` |
| `abs_a` | out | `[3:0]` | `|a|` unsigned |
| `sext_a` | out | `signed [7:0]` | sign-extended `a` |
| `zext_a` | out | `[7:0]` | zero-extended `a` |
| `lt_signed` | out | 1 | `a < b` as signed |
| `lt_unsigned` | out | 1 | `a < b` as unsigned bit patterns |
| `product` | out | `signed [7:0]` | `a × b` |

## 5. Internal Signals

None.

## 6. Architecture

Two adders (5-bit and 4-bit, synthesis shares logic), a negator, a
conditional negator for `abs`, two comparators and a 4×4 signed multiplier.

## 7. Module Hierarchy and Connections

```
tb_signed_ops
└── dut : signed_ops
```

## 8. Verilog Concepts Used

* `signed` declarations on ports.
* Automatic sign extension of signed operands in expressions.
* `$unsigned()` / `$signed()` reinterpretation casts.
* Rule: **if any operand in an expression is unsigned, the whole expression
  is evaluated as unsigned.** Concatenations are always unsigned.
* Signed overflow detection from sign bits.

## 9. Source Code Explanation

```verilog
input wire signed [3:0] a,
```
The bits are the same as for an unsigned port; `signed` changes how they are
extended and compared.

```verilog
assign sum_full = a + b;
assign sum_wrap = a + b;
```
The expression width is the width of the target. For `sum_full` both 4-bit
signed operands are **sign-extended** to 5 bits before adding, so the result
is exact. For `sum_wrap` the addition is done in 4 bits and wraps.

```verilog
assign overflow = (a[3] == b[3]) && (sum_wrap[3] != a[3]);
```
Adding two numbers of opposite sign can never overflow. Overflow occurs only
when both have the same sign and the result's sign differs (7 + 3 = −6).

```verilog
assign neg_a = -a;
assign abs_a = a[3] ? -a : a;
```
Negating −8 in 4 bits gives −8 again; with a 5-bit target the sign-extended
operand negates correctly to +8. For `abs_a`, the 4-bit result `1000` read as
**unsigned** is 8, which is correct.

```verilog
assign sext_a = a;
assign zext_a = {4'b0000, a};
```
A signed source assigned to a wider target is sign-extended automatically:
−3 (`1101`) becomes `11111101`. A concatenation is always unsigned, so
`zext_a` is `00001101` = 13 — the same bits, a different number. (Verilator
reports `WIDTHEXPAND` on the implicit extension; see §12.)

```verilog
assign lt_signed   = (a < b);
assign lt_unsigned = ($unsigned(a) < $unsigned(b));
```
−3 < 2 is true as signed numbers, but as bit patterns 13 < 2 is false — the
simulation row `-3 2` shows `1 0`.

```verilog
assign product = a * b;
```
Both operands signed → signed multiply: −8 × −8 = +64.

## 10. Testbench Explanation

The testbench loops `i` and `j` over −8…7 (as signed `integer`s), drives them
into the signed `reg`s, and compares every output with integer arithmetic:
the exact sum, the wrapped sum (±16 correction), overflow as
"exact sum outside −8…7", and the unsigned comparison using `i + 16` for
negative values. All 256 combinations are checked, then four rows are printed.

## 11. Test Cases and Expected Results

| # | a | b | sum_full | sum_wrap | ovf | −a | \|a\| | a<b signed | a<b unsigned | a×b |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 7 | 3 | 10 | −6 | 1 | −7 | 7 | 0 | 0 | 21 |
| 2 | −8 | −1 | −9 | 7 | 1 | 8 | 8 | 1 | 1 | 8 |
| 3 | −3 | 2 | −1 | −1 | 0 | 3 | 3 | 1 | 0 | −6 |
| 4 | −8 | −8 | −16 | 0 | 1 | 8 | 8 | 0 | 0 | 64 |

Plus the exhaustive sweep.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 008` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_signed_ops` — **PASS**

```text
a  b | sum_full sum_wrap ovf | -a |a| | sext_a    zext_a   | a<b(s) a<b(u) | a*b
  7  3 |    10       -6     1  | -7  7  | 00000111 00000111 |   0      0    | 21
 -8 -1 |    -9        7     1  |  8  8  | 11111000 00001000 |   1      1    | 8
 -3  2 |    -1       -1     0  |  3  3  | 11111101 00001101 |   1      0    | -6
 -8 -8 |   -16        0     1  |  8  8  | 11111000 00001000 |   0      0    | 64
TEST PASSED: 256 checks
tb/tb_signed_ops.v:62: $finish called at 260000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 139 cells
Lint (Verilator 5.020 `--lint-only`): warnings — WIDTHEXPAND
<!-- SIM-RESULTS:END -->

**About the lint warning:** `WIDTHEXPAND` on `assign sext_a = a;` is
Verilator pointing out the implicit 4→8-bit extension — exactly the behaviour
this program demonstrates. Production code usually writes the extension
explicitly, `assign sext_a = {{4{a[3]}}, a};`, which is lint-clean and
independent of signedness rules.

## 13. Design Considerations

* Adders are identical for signed and unsigned numbers; only extension,
  comparison, multiplication and overflow detection differ.
* Keep one extra bit (`sum_full`) or add saturation (083) when overflow is
  possible.
* Explicit extension (`{{n{msb}}, x}`) is robust against the
  "one unsigned operand makes everything unsigned" rule.

## 14. Common Mistakes

* **Mixing signed and unsigned** — `signed_a + 4'd1` is evaluated unsigned,
  so `signed_a` is zero-extended in a wider context.
* **Part selects are unsigned** — `a[3:0]` loses signedness even if `a` is
  signed.
* **Forgetting `-(-8)` overflows** in the same width.
* **Detecting signed overflow from the carry-out** — the carry is the
  *unsigned* overflow indicator.

## 15. Possible Improvements

* Saturating add (clamp to −8/+7 on overflow) — see 083.
* Signed division and arithmetic right shift rounding.

## 16. What This Program Teaches

* Two's complement representation and range.
* Verilog signedness rules and sign extension.
* Signed overflow detection.

## 17. Industry Relevance

Fixed-point DSP datapaths are signed throughout; misuse of signedness is a
recurring source of silicon bugs, which is why many teams mandate explicit
extension and ban mixed-sign expressions in their coding guidelines.

## 18. How to Run

```bash
python3 scripts/run.py 008
cd 00-foundations/008-signed-numbers-and-twos-complement && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/signed_ops.v tb/tb_signed_ops.v
vvp build/sim.vvp
```
