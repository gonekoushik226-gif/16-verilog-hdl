# 004 — Number Literals and Logic Values

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `literal_constants` | `src/literal_constants.v` | `tb/tb_literal_constants.v` |

## 1. Objective

Write numeric constants correctly (size, base, sign) and understand Verilog's
four logic values — `0`, `1`, `x` (unknown) and `z` (high impedance) — and how
`x` propagates through logic.

## 2. What the Design Does

* Drives the value 200 on four outputs, each written in a different base
  (decimal, hexadecimal, binary, octal), plus `-8'sd56`, which has the same
  8-bit pattern `1100_1000`.
* Shows zero extension (`zero_ext = 16'h00C8`) and replication
  (`replicated = {2{4'hA}} = 8'hAA`).
* Masks the 4-bit input `a`: `and_mask = a & 4'b1100` clears the low two bits,
  `or_mask = a | 4'b0011` sets them. The testbench drives `x` and `z` into `a`
  to observe how unknown values travel through AND/OR gates.

## 3. Why It Is Useful

Wrongly sized constants and misunderstood `x` values cause a large share of
beginner bugs: truncated constants, comparisons that are never true, and
testbenches that "pass" because an `x` was compared with `==`. Masking with
constants is everyday RTL (clearing flag bits, aligning addresses).

## 4. Interface

| Port | Direction | Width | Value / function |
|---|---|---|---|
| `a` | input | 4 | Operand for the mask outputs |
| `dec_val` | output | 8 | `8'd200` |
| `hex_val` | output | 8 | `8'hC8` |
| `bin_val` | output | 8 | `8'b1100_1000` |
| `oct_val` | output | 8 | `8'o310` |
| `neg_val` | output | 8 | `-8'sd56` (bit pattern of 200) |
| `zero_ext` | output | 16 | `{8'h00, 8'hC8}` |
| `replicated` | output | 8 | `{2{4'hA}}` |
| `and_mask` | output | 4 | `a & 4'b1100` |
| `or_mask` | output | 4 | `a \| 4'b0011` |

## 5. Internal Signals

None.

## 6. Architecture

All constant outputs are tie-offs (wires to logic 0 or 1). The masks are
two bits of pass-through and two bits of constant per output — a masking AND
with a 0 bit is simply a constant 0. Yosys therefore reports **zero** logic
cells.

## 7. Module Hierarchy and Connections

```
tb_literal_constants
└── dut : literal_constants
```

## 8. Verilog Concepts Used

* **Sized literal** `<size>'<base><digits>`: `8'd200`, `8'hC8`,
  `8'b1100_1000`, `8'o310`. The size is in **bits**.
* **Signed literal** `8'sd56`; unary minus produces the two's complement.
* **Underscore separators** for readability.
* **Concatenation** `{8'h00, 8'hC8}` and **replication** `{2{4'hA}}`.
* **Four-state logic**: `0`, `1`, `x`, `z`.
* **Equality** `==` (can return `x`) vs **case equality** `===` (always 0 or 1).

## 9. Source Code Explanation

```verilog
assign dec_val = 8'd200;
assign hex_val = 8'hC8;
assign bin_val = 8'b1100_1000;
assign oct_val = 8'o310;
```
Four spellings of the same bits. Hex groups 4 bits per digit (`C`=1100,
`8`=1000); octal groups 3 bits (`3 1 0` = 011 001 000, the leading 0 falls
off the 8-bit size).

```verilog
assign neg_val = -8'sd56;
```
`-56` in 8-bit two's complement is `256 − 56 = 200 = 8'hC8`. The bits are
identical to the other outputs; only the *interpretation* differs. The
testbench prints the same wire as unsigned (200) and with `$signed` (−56).

```verilog
assign zero_ext   = {8'h00, 8'hC8};
assign replicated = {2{4'hA}};
```
Explicit zero extension and the replication operator `{n{…}}`, which repeats
a pattern (used heavily for sign extension in 005 and 008).

```verilog
assign and_mask = a & 4'b1100;
assign or_mask  = a | 4'b0011;
```
Bitwise masking. For known inputs these clear/set bits. For unknown inputs
the Verilog truth tables apply:

| `&` | 0 | 1 | x | z |   | `\|` | 0 | 1 | x | z |
|---|---|---|---|---|---|---|---|---|---|---|
| **0** | 0 | 0 | 0 | 0 | | **0** | 0 | 1 | x | x |
| **1** | 0 | 1 | x | x | | **1** | 1 | 1 | 1 | 1 |
| **x** | 0 | x | x | x | | **x** | x | 1 | x | x |

A `z` entering a gate input is treated like `x`. A controlling value (0 for
AND, 1 for OR) wins even against `x`.

## 10. Testbench Explanation

* Two checker tasks (`check8`, `check4`) compare with `!==`, so an `x` where
  a 0 was expected is reported as an error.
* Constant checks: every base form must equal 200; `zero_ext` is checked in
  two halves; `replicated` must be `10101010`.
* Known-input masks with `a = 1010`.
* `a = 4'bxz01`: expected `and_mask = xx00`, `or_mask = xx11`.
* `a = 4'b00xz`: the constant bits dominate — `and_mask = 0000`,
  `or_mask = 0011` — no `x` escapes.
* Equality demo with `a = 4'b10x0`: `(a == 4'b1000)` must be `x` (the
  comparison is unknown), while `(a === 4'b10x0)` must be exactly 1.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | four bases | all equal 200 |
| 2 | `-8'sd56` | bits `11001000`, prints 200 unsigned, −56 signed |
| 3 | zero extension / replication | `00c8`, `aa` |
| 4 | masks with `a=1010` | `1000`, `1011` |
| 5 | masks with `a=xz01` | `xx00`, `xx11` |
| 6 | masks with `a=00xz` | `0000`, `0011` |
| 7 | `==` vs `===` with an `x` bit | `x` vs `1` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 004` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_literal_constants` — **PASS**

```text
dec_val=200 hex_val=c8 bin_val=11001000 oct_val=310
neg_val bits=11001000 unsigned=200 signed=-56
zero_ext=00c8 replicated=aa
a=xz01  a & 1100 = xx00   a | 0011 = xx11
a=00xz  a & 1100 = 0000   a | 0011 = 0011
a=10x0: (a == 4'b1000) -> x, (a === 4'b10x0) -> 1
TEST PASSED: 16 checks
tb/tb_literal_constants.v:99: $finish called at 31000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 0 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `x` exists only in simulation. Real hardware always resolves to 0 or 1, so
  an `x` in simulation means "this could be either in silicon" — usually a
  missing reset or an undriven signal.
* `z` is a real electrical state (a tri-stated driver, see 025), but inside
  logic it behaves like `x`.
* Constants cost no area; synthesis ties outputs to supply rails.

## 14. Common Mistakes

* **Unsized literals** like `'hC8` or `200` are 32 bits wide; they are
  silently truncated or extended when assigned, which hides mistakes.
* **Too few bits**: `4'd20` does not fit and is truncated to `4'd4`.
* **Confusing size with digits**: `8'h1` is `0000_0001`, not eight ones.
* **Checking outputs with `==` in testbenches**: `if (y == 1)` with `y = x`
  takes the *else* path, so errors pass silently. Use `===`/`!==`.
* **Using `===` in synthesizable RTL** — it cannot be built in hardware.

## 15. Possible Improvements

* Add `$bits()` checks of each constant's width (SystemVerilog).
* Explore `x`-optimism of `if` statements (an `x` condition takes the `else`).

## 16. What This Program Teaches

* Literal syntax: size, base, sign, separators.
* Two's complement bit patterns.
* Four-state logic and `x` propagation.
* `==` versus `===`.

## 17. Industry Relevance

Lint tools in every production flow flag width mismatches between constants
and targets. X-propagation analysis is a formal step in ASIC verification
(`x`-pessimism/optimism reviews) because unknown values hide reset and
initialization bugs.

## 18. How to Run

```bash
python3 scripts/run.py 004
cd 00-foundations/004-number-literals-and-logic-values && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/literal_constants.v tb/tb_literal_constants.v
vvp build/sim.vvp
```
