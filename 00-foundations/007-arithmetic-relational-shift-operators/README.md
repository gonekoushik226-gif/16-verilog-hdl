# 007 — Arithmetic, Relational and Shift Operators

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `arith_ops` | `src/arith_ops.v` | `tb/tb_arith_ops.v` |

## 1. Objective

Use Verilog's arithmetic, relational and shift operators with correctly sized
results, and understand what each costs in hardware.

## 2. What the Design Does

For unsigned 4-bit `a` and `b`:

* `sum = a + b` (5 bits, includes the carry), `diff = a − b` (4 bits,
  wraps), `borrow = a < b`, `product = a × b` (8 bits),
* `quotient = a / b`, `remainder = a % b`, both 0 with `div_by_zero = 1`
  when `b = 0`,
* the six comparisons `lt le gt ge eq ne`,
* shifts of `a` by `b[1:0]` positions: `shl` (`<<`), `shr` (`>>`) and the
  arithmetic right shift `ashr` (`>>>`, fills with the sign bit `a[3]`).

## 3. Why It Is Useful

These operators are the building blocks of every datapath. Knowing their
result widths prevents lost carries and truncated products; knowing their
hardware cost (a divider is far larger than an adder) guides architecture
choices.

## 4. Interface

| Port | Dir | Width | Description |
|---|---|---|---|
| `a`, `b` | in | 4 | Unsigned operands |
| `sum` | out | 5 | `a + b` |
| `diff` | out | 4 | `a − b` modulo 16 |
| `borrow` | out | 1 | `a < b` |
| `product` | out | 8 | `a × b` |
| `quotient`, `remainder` | out | 4 | `a / b`, `a % b` (0 if `b = 0`) |
| `div_by_zero` | out | 1 | `b == 0` |
| `lt le gt ge eq ne` | out | 1 each | comparisons |
| `shl`, `shr`, `ashr` | out | 4 | shifts of `a` by `b[1:0]` |

## 5. Internal Signals

None.

## 6. Architecture

```
          +--> 5-bit adder ----------------------> sum
          +--> 4-bit subtractor ------------------> diff, (a<b) -> borrow
 a, b ----+--> 4x4 multiplier --------------------> product
          +--> 4/4 divider --+--> mux(b==0 ? 0) --> quotient, remainder
          +--> comparators ------------------------> lt le gt ge eq ne
          +--> barrel shifters (by b[1:0]) --------> shl shr ashr
```

The divider dominates the area (Yosys reports ~230 cells in total for this
tiny 4-bit module; an adder alone would be about a dozen).

## 7. Module Hierarchy and Connections

```
tb_arith_ops
└── dut : arith_ops
```

## 8. Verilog Concepts Used

* `+ - * / %` and their width rules.
* Relational `< <= > >=` and equality `== !=`.
* Logical shifts `<<`, `>>` and arithmetic shift `>>>`.
* `$signed()` to make `>>>` sign-fill.
* Conditional operator to define division by zero.

## 9. Source Code Explanation

```verilog
assign sum = {1'b0, a} + {1'b0, b};
```
Verilog sizes an expression to the widest of its operands **and** the target.
Because `sum` is 5 bits, `a + b` would also be evaluated in 5 bits here; the
explicit zero-extension documents the intent and stays correct if the code
is reused in a context-free expression (e.g. inside a comparison).

```verilog
assign diff   = a - b;
assign borrow = (a < b);
```
Unsigned subtraction wraps modulo 2^4: `3 − 9 = 10` (see the simulation
row `3 9 → 10`). `borrow` flags that the true result was negative.

```verilog
assign product = a * b;
```
An N×M multiply needs N+M bits; 15 × 15 = 225 fits in 8 bits.

```verilog
assign div_by_zero = (b == 4'd0);
assign quotient    = div_by_zero ? 4'd0 : a / b;
assign remainder   = div_by_zero ? 4'd0 : a % b;
```
In simulation `a / 0` is `x`. Hardware must produce *something*, so the design
defines it (here 0, with a flag). Processors define this too — RISC-V returns
all ones for the quotient (see 264).

```verilog
assign shl  = a << b[1:0];
assign shr  = a >> b[1:0];
assign ashr = $signed(a) >>> b[1:0];
```
`<<` and `>>` fill vacated positions with 0. `>>>` fills with the sign bit
**only when the operand is signed**; on an unsigned operand it behaves like
`>>`. `$signed(a)` reinterprets the bits, so `1101 >>> 2 = 1111`.

## 10. Testbench Explanation

All 256 operand pairs are applied. The reference uses 32-bit `integer`
arithmetic: `(i - j + 16) % 16` for the wrapped difference, `i * j`,
`i / j`, and, for the arithmetic shift, the 4-bit value is first converted to
a signed integer (`i >= 8 ? i − 16 : i`), shifted with `>>>` (integers are
signed) and masked back to 4 bits. Four rows are printed, including
`b = 0`.

## 11. Test Cases and Expected Results

| # | a | b | sum | diff | borrow | product | q | r | dz | shl | shr | ashr |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 13 | 6 | 19 | 7 | 0 | 78 | 2 | 1 | 0 | 0100 | 0011 | 1111 |
| 2 | 3 | 9 | 12 | 10 | 1 | 27 | 0 | 3 | 0 | 0110 | 0001 | 0001 |
| 3 | 15 | 15 | 30 | 0 | 0 | 225 | 1 | 0 | 0 | 1000 | 0001 | 1111 |
| 4 | 9 | 0 | 9 | 9 | 0 | 0 | 0 | 0 | 1 | 1001 | 1001 | 1001 |

(Shift amount is `b[1:0]`: 6→2, 9→1, 15→3, 0→0.) Plus the exhaustive sweep.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 007` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_arith_ops` — **PASS**

```text
a  b | sum diff brw prod  q  r dz | lt eq gt | shl  shr  ashr
 13  6 | 19   7   0   78  2  1  0 |  0  0  1 | 0100 0011 1111
  3  9 | 12  10   1   27  0  3  0 |  1  0  0 | 0110 0001 0001
 15 15 | 30   0   0  225  1  0  0 |  0  1  0 | 1000 0001 1111
  9  0 |  9   9   0    0  0  0  1 |  0  0  1 | 1001 1001 1001
TEST PASSED: 256 checks
tb/tb_arith_ops.v:65: $finish called at 260000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 232 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `/` and `%` by a variable synthesize to large, slow combinational dividers.
  Real designs divide by constants (shifts/multiplies), use sequential
  dividers (215, 216) or avoid division.
* Division/modulo by a power of two is free: `a / 4` is `a >> 2`.
* A comparator is essentially a subtractor; sharing one subtractor for
  `diff` and `lt` is a common optimisation (synthesis may do it).

## 14. Common Mistakes

* **Losing the carry**: `wire [3:0] s = a + b;` drops bit 4.
* **Undersized products**: 8×8 into 8 bits keeps only the low half.
* **`>>>` on unsigned data** does not sign-extend.
* **Unguarded division by zero** propagates `x` through the design in
  simulation.
* **Shifting by a wider amount than the data** — `a << 5` on 4 bits is 0.

## 15. Possible Improvements

* Signed versions of every operator (see 008).
* Replace the combinational divider with a sequential one (215).

## 16. What This Program Teaches

* Operator result widths and how to size targets.
* Defined behaviour for division by zero.
* Logical vs arithmetic shifts.
* The relative hardware cost of arithmetic operators.

## 17. Industry Relevance

Width mismatches (`WIDTH` lint warnings) are among the most common issues
found in code review. Division is avoided or made multi-cycle in nearly every
real datapath because a single-cycle divider limits clock frequency.

## 18. How to Run

```bash
python3 scripts/run.py 007
cd 00-foundations/007-arithmetic-relational-shift-operators && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/arith_ops.v tb/tb_arith_ops.v
vvp build/sim.vvp
```
