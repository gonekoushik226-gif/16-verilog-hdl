# 006 — Bitwise, Logical and Reduction Operators

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `operator_unit` | `src/operator_unit.v` | `tb/tb_operator_unit.v` |

## 1. Objective

Distinguish the three operator families that use similar symbols — bitwise
(`&`), logical (`&&`) and reduction (unary `&`) — and know the result width of
each.

## 2. What the Design Does

For two 4-bit inputs `a` and `b` the module computes, in parallel:

| Family | Outputs | Result width |
|---|---|---|
| Bitwise | `a & b`, `a \| b`, `a ^ b`, `~a` | 4 bits (one result per bit position) |
| Logical | `a && b`, `a \|\| b`, `!a` | 1 bit (operand ≠ 0 means "true") |
| Reduction | `&a`, `\|a`, `^a`, `~&a`, `~\|a`, `~^a` | 1 bit (all bits of one operand combined) |

Example from the simulation: `a = 0101`, `b = 1010` gives `a & b = 0000` but
`a && b = 1`, because both operands are non-zero.

## 3. Why It Is Useful

Mixing these up is one of the most common Verilog bugs. Reduction operators
are used constantly: `|count` ("count is non-zero"), `&addr` ("address is all
ones"), `^data` (parity).

## 4. Interface

| Port | Direction | Width | Function |
|---|---|---|---|
| `a`, `b` | input | 4 | Operands |
| `and_bw`, `or_bw`, `xor_bw` | output | 4 | Bitwise AND, OR, XOR |
| `not_a` | output | 4 | Bitwise NOT of `a` |
| `and_log`, `or_log` | output | 1 | Logical AND, OR |
| `not_log` | output | 1 | Logical NOT of `a` |
| `red_and`, `red_or`, `red_xor` | output | 1 | Reductions of `a` |
| `red_nand`, `red_nor`, `red_xnor` | output | 1 | Inverted reductions of `a` |

## 5. Internal Signals

None.

## 6. Architecture

```
bitwise   : 4 independent 2-input gates per operator
logical   : (|a) AND/OR (|b)       — each operand first reduced to "non-zero"
reduction : one 4-input gate tree over a[3:0]
```

## 7. Module Hierarchy and Connections

```
tb_operator_unit
└── dut : operator_unit
```

## 8. Verilog Concepts Used

* Bitwise operators `& | ^ ~` (and `~^` XNOR).
* Logical operators `&& || !` — result is 1-bit true/false (or `x`).
* Unary reduction operators `& | ^ ~& ~| ~^`.

## 9. Source Code Explanation

```verilog
assign and_bw = a & b;   // and_bw[i] = a[i] & b[i]
assign or_bw  = a | b;
assign xor_bw = a ^ b;
assign not_a  = ~a;
```
Bitwise: the operation is applied position by position.

```verilog
assign and_log = a && b;
assign or_log  = a || b;
assign not_log = !a;
```
Logical: each vector is first converted to a truth value (non-zero = 1), then
combined. `!a` is 1 only when `a == 0`, whereas `~a` inverts every bit.
Hardware: `and_log = (|a) & (|b)`.

```verilog
assign red_and  = &a;    // a[3] & a[2] & a[1] & a[0]
assign red_or   = |a;
assign red_xor  = ^a;
assign red_nand = ~&a;
assign red_nor  = ~|a;
assign red_xnor = ~^a;
```
Reduction: a single operand, all of its bits combined into one. `^a` is 1 for
an odd number of ones (parity).

## 10. Testbench Explanation

All 256 `(a, b)` combinations are applied. The expected values are built bit
by bit with `if`-style comparisons (`a[k] == 1 && b[k] == 1`) and by counting
ones in `a` (`red_and` ⇔ 4 ones, `red_or` ⇔ at least one, `red_xor` ⇔ odd
count), so the reference does not reuse the operators under test. Four
illustrative rows are printed afterwards.

## 11. Test Cases and Expected Results

| # | `a` | `b` | `a&b` | `a&&b` | `~a` | `!a` | `&a` | `\|a` | `^a` |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 0101 | 1010 | 0000 | 1 | 1010 | 0 | 0 | 1 | 0 |
| 2 | 0000 | 1111 | 0000 | 0 | 1111 | 1 | 0 | 0 | 0 |
| 3 | 1111 | 0001 | 0001 | 1 | 0000 | 0 | 1 | 1 | 0 |
| 4 | 0111 | 1000 | 0000 | 1 | 1000 | 0 | 0 | 1 | 1 |

Plus the exhaustive sweep of all 256 pairs.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 006` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_operator_unit` — **PASS**

```text
a    b  | a&b  a&&b | a|b  a||b | ~a   !a | &a |a ^a
 0101 1010 | 0000   1  | 1111   1  | 1010  0 |  0  1  0
 0000 1111 | 0000   0  | 1111   1  | 1111  1 |  0  0  0
 1111 0001 | 0001   1  | 1111   1  | 0000  0 |  1  1  0
 0111 1000 | 0000   1  | 1111   1  | 1000  0 |  0  1  1
TEST PASSED: 256 checks
tb/tb_operator_unit.v:73: $finish called at 260000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 33 cells
Lint (Verilator 5.020 `--lint-only`): warnings — WIDTHTRUNC
<!-- SIM-RESULTS:END -->

**About the lint warnings:** Verilator reports `WIDTHTRUNC` on `a && b`,
`a || b` and `!a` because logical operators expect 1-bit operands. The code
is legal Verilog and is written this way on purpose to demonstrate the
operators. In production RTL the intent is stated explicitly, which is also
lint-clean:

```verilog
assign and_log = (a != 4'd0) && (b != 4'd0);   // or (|a) && (|b)
```

## 13. Design Considerations

* Logical operators on vectors hide an OR-reduction; making it explicit
  (`|a`) documents the intent.
* Reduction operators synthesize to balanced gate trees; a 64-bit `|v`
  is a few levels of OR gates, not 63 in series.

## 14. Common Mistakes

* `if (a & b)` when `a && b` was meant: `0101 & 1010 = 0000` is false even
  though both are non-zero.
* `~` vs `!`: `~4'b0001 = 4'b1110` (true), `!4'b0001 = 0` (false).
* Using `^` intending exponentiation (Verilog-2001 power is `**`).
* Forgetting that reduction is **unary**: `&a` is one bit; `a & b` is four.

## 15. Possible Improvements

* Parameterize the width.
* Add shift and conditional operators (see 007 and 009).

## 16. What This Program Teaches

* Result width and meaning of each operator family.
* Using reduction operators for "all/any/parity" tests.
* Writing an independent reference model in a testbench.

## 17. Industry Relevance

Linting rules in industrial flows (Verilator, SpyGlass, Ascent) specifically
flag logical operators on multi-bit vectors and bitwise operators in
conditions, because these mix-ups are frequent real bugs.

## 18. How to Run

```bash
python3 scripts/run.py 006
cd 00-foundations/006-bitwise-logical-reduction-operators && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/operator_unit.v tb/tb_operator_unit.v
vvp build/sim.vvp
```
