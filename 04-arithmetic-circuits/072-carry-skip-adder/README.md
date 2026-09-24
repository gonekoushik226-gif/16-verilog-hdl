# 072 — Carry-Skip Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `cska` | `src/full_adder.v`, `src/skip_block.v`, `src/cska.v` | `tb/tb_cska.v` |

## 1. Objective

Show a third fast-adder technique alongside carry-lookahead (069/070) and
carry-select (071): let a carry "skip" past an entire block via a fast
mux whenever every bit in that block would propagate it through anyway.

## 2. What the Design Does

`cska` adds two 8-bit numbers using two 4-bit `skip_block`s. Each block
ripples internally through four full adders, but also computes its own
`block_p` (AND of every bit's propagate `a[i]^b[i]`): if `block_p=1`, the
block is guaranteed to pass its carry-in straight through unchanged, so
its `carry_out` is taken directly from `cin` via a mux instead of the
(value-identical, but structurally longer) ripple path.

## 3. Why It Is Useful

Whole blocks of an adder are often "fully propagating" for many real
operand values (e.g. adding 1, or any operand with long runs of
alternating bits against its partner). Carry-skip exploits that case
cheaply — one AND-reduction and one mux per block — without the extra
duplicated hardware carry-select needs.

## 4. Interface

**`cska`** (top level)

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 8 | first operand |
| `b` | input | 8 | second operand |
| `cin` | input | 1 | carry in |
| `sum` | output | 8 | `a + b + cin`, low 8 bits |
| `carry_out` | output | 1 | final carry out |

**`skip_block`**: `a[3:0]`, `b[3:0]`, `cin` in; `sum[3:0]`, `carry_out` out.

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `carry_mid` | 1 | carry between the low and high `skip_block`s |
| (inside `skip_block`) `p[3:0]` | 4 | per-bit propagate |
| (inside `skip_block`) `block_p` | 1 | AND-reduction of `p`: does the whole block propagate |
| (inside `skip_block`) `ripple_carry_out` | 1 | the block's actual ripple-computed carry |

## 6. Architecture

```
skip_block:
  ripple_carry_out = (ripple through 4 full adders, cin -> carry[4])
  block_p = p[3] & p[2] & p[1] & p[0]
  carry_out = block_p ? cin : ripple_carry_out    <- the "skip" mux

cska:
  a[3:0],b[3:0],cin -[skip_block low]-  sum[3:0], carry_mid
  a[7:4],b[7:4],carry_mid -[skip_block high]- sum[7:4], carry_out
```
`block_p ? cin : ripple_carry_out` is a mux between two paths that are
always *value*-equal when `block_p=1` (that is exactly what `block_p=1`
means); the mux exists to shorten the dependency chain a later block's
carry-in rides on, which plain functional simulation cannot show timing
for, but is the entire motivation for the architecture.

## 7. Module Hierarchy and Connections

```
cska
├── low  : skip_block (a[3:0], b[3:0], cin)       -> sum[3:0], carry_mid
│            └── fa[0..3] : full_adder (generate loop)
└── high : skip_block (a[7:4], b[7:4], carry_mid) -> sum[7:4], carry_out
             └── fa[0..3] : full_adder (generate loop)
```

## 8. Verilog Concepts Used

* AND-reduction (`&p`) to test "every bit of a vector is 1" in one
  expression.
* A mux (`? :`) selecting between a fast precomputed path and a slower
  structurally-computed path that are guaranteed equal under the mux's
  own selecting condition.

## 9. Source Code Explanation

```verilog
wire [3:0] p = a ^ b;
wire       block_p = &p;
wire       ripple_carry_out = carry[4];
assign carry_out = block_p ? cin : ripple_carry_out;
```
`p[i]=1` means bit `i` would pass an incoming carry straight through
(`a[i] XOR b[i] XOR carry_in` toggles with `carry_in` exactly when
`a[i]!=b[i]`). If every bit in the block has this property, the whole
block's `carry_out` must equal its `cin`, by induction — so `carry_out`
is read directly from `cin`, skipping the four-full-adder ripple path
whenever that shortcut is valid.

## 10. Testbench Explanation

`tb_cska` drives 3000 random `(a,b,cin)` combinations plus six directed
cases: both nibbles fully propagating (`a = ~b` within each nibble, for
both values of `cin`), a mixed propagate/non-propagate case, a
non-propagating case (`a=b` in each nibble, so `block_p=0` everywhere),
and full-width `0xFF`/`0x00` corners — exercising both the skip-mux path
and the ordinary ripple path in both blocks. All are checked against a
9-bit Verilog reference `a+b+cin`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | random | 3000 random `(a,b,cin)` | matches `a+b+cin` |
| 2 | both blocks skip | a=0x55,b=0xAA, cin=0/1 | skip-mux path exercised in both blocks |
| 3 | no block skips | a=0xF0,b=0xF0,cin=1 | ripple path used in both blocks |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 072` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_cska` — **PASS**

```text
TEST PASSED: 3006 checks
tb/tb_cska.v:59: $finish called at 3006000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 72 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The skip mux only ever selects between two functionally identical
  values, so it changes nothing about simulated *results* — only real
  gate-level timing, which this repository's flow (Icarus simulation,
  Yosys generic synthesis) does not model. The RTL and testbench
  demonstrate the structure and its correctness; the delay benefit is
  conceptual.
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Computing `block_p` as OR instead of AND of the per-bit propagates —
  the block only fully propagates if *every* bit does, not if any one
  does.
* Believing the skip mux changes the block's functional result — it does
  not; it only changes which path produces that (always identical) value.

## 15. Possible Improvements

* Extend to more, narrower blocks (finer-grained skipping) or add a
  second skip level across pairs of blocks, mirroring program 070's
  two-level carry-lookahead extension.

## 16. What This Program Teaches

* A third distinct fast-adder technique (after lookahead and select),
  and how to recognize when two computed values are provably equal under
  a condition, letting one substitute for the other on the critical path.

## 17. Industry Relevance

Carry-skip adders offer a good area/delay tradeoff for medium widths and
are a standard entry in the fast-adder architecture family taught
alongside carry-lookahead and carry-select in computer arithmetic.

## 18. How to Run

```bash
python3 scripts/run.py 072            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/072-carry-skip-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/full_adder.v src/skip_block.v src/cska.v tb/tb_cska.v
vvp build/sim.vvp +vcd
```
