# 082 — 8-bit Hierarchical ALU

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `alu8` | `src/alu8.v`, `src/arith_unit.v`, `src/logic_unit.v`, `src/shift_unit.v`, `src/flag_unit.v` | `tb/tb_alu8.v` |

## 1. Objective

Restructure program 081's single-`case` ALU into separate hierarchical
execution units (arithmetic, logic, shift) that all compute in parallel,
with a result mux and a dedicated flag unit — the way a real ALU is
actually organized.

## 2. What the Design Does

`alu8` selects one of 16 operations on two 8-bit operands via a 4-bit
`opcode`: `opcode[3:2]` chooses a unit (arithmetic, logic, or shift/
rotate), `opcode[1:0]` chooses the operation within that unit. All three
units compute every cycle regardless of which is selected; a mux picks
the right result (and, for the arithmetic unit only, the right
carry/overflow) before `flag_unit` derives the final `zero`/`negative`
flags.

## 3. Why It Is Useful

Program 081 put every operation in one `case` statement — simple, but it
doesn't scale, and it doesn't reflect how real ALUs are built: as
independent functional units (often with very different internal
structure and timing) feeding a common result path. This program shows
that decomposition directly, and adds rotate operations program 081
didn't have.

## 4. Interface

**`alu8`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 8 each | operands (`b[2:0]` doubles as shift/rotate amount) |
| `opcode` | input | 4 | `[3:2]`=unit select, `[1:0]`=op within unit |
| `result` | output | 8 | selected unit's result |
| `carry` | output | 1 | arithmetic unit's carry (0 for logic/shift) |
| `overflow` | output | 1 | arithmetic unit's overflow (0 for logic/shift) |
| `zero` | output | 1 | `result == 0` |
| `negative` | output | 1 | `result[7]` |

**`arith_unit`**: `a`,`b`,`sub` in; `result`,`carry`,`overflow` out.
**`logic_unit`**: `a`,`b`,`sel[1:0]` in; `result` out.
**`shift_unit`**: `a`,`amount[2:0]`,`sel[1:0]` in; `result` out.
**`flag_unit`**: `result`,`carry_in`,`overflow_in` in; `zero`,`negative`,`carry_out`,`overflow_out` out.

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `arith_result`, `logic_result`, `shift_result` | each unit's independently-computed result, valid every cycle |
| `arith_carry`, `arith_overflow` | the arithmetic unit's own flags |
| `mux_result`, `mux_carry`, `mux_overflow` | the opcode-selected result/flags fed to `flag_unit` |

## 6. Architecture

```
opcode[3:2]  unit     opcode[1:0] meaning
00           arith    [0]=sub (0=ADD,1=SUB)
01           logic    00=AND 01=OR 10=XOR 11=NOT(a)
10           shift    00=SHL 01=SHR 10=ROL 11=ROR   (amount = b[2:0])
11           reserved (result forced to 0)

a,b ---> arith_unit -----\
a,b ---> logic_unit ------>--[result mux on opcode[3:2]]--> flag_unit --> zero,negative
a,b ---> shift_unit ------/                                    ^
                                                   carry/overflow (arith only)
```

## 7. Module Hierarchy and Connections

```
alu8
├── u_arith : arith_unit (a, b, opcode[0])          -> arith_result, arith_carry, arith_overflow
├── u_logic : logic_unit (a, b, opcode[1:0])         -> logic_result
├── u_shift : shift_unit (a, b[2:0], opcode[1:0])    -> shift_result
└── u_flags : flag_unit (mux_result, mux_carry, mux_overflow) -> zero, negative, carry, overflow
```

## 8. Verilog Concepts Used

* Splitting one ALU into separate single-purpose modules connected
  through a top-level mux, rather than one large `case`.
* Rotate implemented as `(a << amount) | (a >> (8-amount))` (and its
  mirror for rotate-right) — a `<<`/`>>` pair that correctly handles
  `amount==0` because Verilog shifts by the full operand width evaluate
  to 0, leaving the un-rotated operand from the other half of the OR.
* A variable shift/rotate amount taken directly from operand bits
  (`b[2:0]`) instead of a fixed shift-by-1.

## 9. Source Code Explanation

`arith_unit` and its carry/overflow derivation are identical in
technique to programs 068/081. `logic_unit` and `shift_unit` are each a
simple `case` on their own 2-bit select. `alu8`'s always block computes
`mux_result`/`mux_carry`/`mux_overflow` from whichever unit `opcode[3:2]`
selects (defaulting all three to 0 for the reserved `2'b11` unit-select
value), and `flag_unit` derives `zero`/`negative` fresh from
`mux_result` while simply passing `carry`/`overflow` through unchanged.

## 10. Testbench Explanation

`tb_alu8` iterates all 16 opcodes; for each it runs 150 random `(a,b)`
pairs, 8 directed corner-operand pairs (`0x00`, `0xFF`, `0x80`, `0x7F`,
alternating-bit patterns), and — for the shift/rotate opcodes
specifically — every shift amount 0-7 against a fixed operand, so the
`amount==0` rotate edge case is always exercised. All checks compare
against a reference model that mirrors the RTL's own opcode decode.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | arithmetic, random+corners | opcode 0000/0001 | matches ADD/SUB with correct flags |
| 2 | logic, random+corners | opcode 0100-0111 | matches AND/OR/XOR/NOT |
| 3 | shift/rotate, all amounts | opcode 1000-1011, amount=0..7 | matches SHL/SHR/ROL/ROR, including amount=0 |
| 4 | reserved | opcode 1100-1111 | result=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 082` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_alu8` — **PASS**

```text
TEST PASSED: 2560 checks
tb/tb_alu8.v:107: $finish called at 2560000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 378 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* All three units compute unconditionally every cycle (not just the
  selected one) — simpler and matches how synthesis would map a
  combinational mux-based ALU anyway, at the cost of some switching
  activity a real low-power design might gate off.
* Purely combinational; no reset/clock. `opcode[3:2]==2'b11` is defined
  as reserved (`result=0`) rather than left undefined.

## 14. Common Mistakes

* Computing rotate without the `amount==0` special case in mind — a
  naive `(a << amount) | (a >> (8-amount))` happens to work correctly at
  `amount==0` only because Verilog defines a full-width shift as
  producing 0, which is easy to assume is "undefined" without checking.
* Forgetting default assignments in `alu8`'s mux `always` block, which
  would infer latches for the reserved opcode case.

## 15. Possible Improvements

* Add comparison operations (equal, less-than) as a fourth unit.
* Gate each unit's inputs with the opcode-decoded enable to reduce
  unnecessary switching in a power-aware variant.

## 16. What This Program Teaches

* Structuring a datapath as independent functional units plus a result
  mux, instead of one large conditional.
* A correct, edge-case-safe rotate implementation built from plain shift
  operators.

## 17. Industry Relevance

Real CPU ALUs are built exactly this way: separate adder, logic, and
shift/rotate hardware (often with genuinely different circuit styles and
latencies) feeding a shared result mux and flags register — this
program's structure, scaled up with more operations and pipelining, is
the ALU stage of an actual processor datapath (see category 13's
processor-component programs).

## 18. How to Run

```bash
python3 scripts/run.py 082            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/082-alu-8bit-hierarchical && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/arith_unit.v src/logic_unit.v src/shift_unit.v src/flag_unit.v src/alu8.v tb/tb_alu8.v
vvp build/sim.vvp +vcd
```
