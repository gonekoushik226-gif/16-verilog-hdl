# 081 — 4-bit ALU

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Elementary | `alu4` | `src/alu4.v` | `tb/tb_alu4.v` |

## 1. Objective

Combine several of this repository's earlier arithmetic and logic
operations behind a single opcode-decoded interface — the first genuine
"ALU" in this category, and the direct ancestor of program 082's
hierarchical 8-bit version.

## 2. What the Design Does

`alu4` selects one of eight operations on two 4-bit operands `a`, `b`
via a 3-bit `opcode`: ADD, SUB, AND, OR, XOR, NOT (of `a`), shift-left-1,
shift-right-1. It reports `result` plus `carry`/`overflow` (meaningful
only for ADD/SUB) and `zero`/`negative` (meaningful for every operation).

## 3. Why It Is Useful

An ALU is the arithmetic/logic core of every processor datapath. This
program shows the essential pattern — a `case` on an opcode selecting
between otherwise-independent operations, with a shared flag set derived
from the selected result — before program 082 splits that same pattern
into separate hierarchical sub-units.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 4 each | operands |
| `opcode` | input | 3 | operation select (see §6) |
| `result` | output | 4 | selected operation's result |
| `carry` | output | 1 | ADD/SUB carry (0 for other opcodes) |
| `overflow` | output | 1 | ADD/SUB signed overflow (0 for other opcodes) |
| `zero` | output | 1 | `result == 0` |
| `negative` | output | 1 | `result[3]` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `ext` | 5 | widened ADD/SUB intermediate, giving carry as its top bit |

## 6. Architecture

```
opcode  operation
000     ADD   result = a + b
001     SUB   result = a - b     (two's-complement, same technique as program 068)
010     AND   result = a & b
011     OR    result = a | b
100     XOR   result = a ^ b
101     NOT   result = ~a        (b unused)
110     SHL   result = a << 1
111     SHR   result = a >> 1
```
`carry`/`overflow` are only driven meaningfully inside the ADD/SUB cases;
they default to 0 otherwise, matching this program's documented
contract (not a claim that shifting "has no carry" in general).

## 7. Module Hierarchy and Connections

Single module; a `case` statement inside one combinational `always`
block selects the operation, with `zero`/`negative` computed by separate
continuous assignments from the final `result`.

## 8. Verilog Concepts Used

* `localparam` opcode encodings (`OP_ADD`, `OP_SUB`, ...) instead of bare
  numeric literals in the `case` statement, for readability.
* Reuse of program 068's widened-minuend two's-complement subtraction
  technique (`{1'b1,a} - {1'b0,b}`) inside a `case` branch.
* Default assignments for every output at the top of the combinational
  block, avoiding unintended latches for opcodes that don't explicitly
  drive every signal.

## 9. Source Code Explanation

```verilog
case (opcode)
    OP_ADD: begin
        ext = {1'b0, a} + {1'b0, b};
        result = ext[3:0]; carry = ext[4];
        overflow = (a[3]==b[3]) && (result[3]!=a[3]);
    end
    OP_SUB: begin
        ext = {1'b1, a} - {1'b0, b};
        result = ext[3:0]; carry = ext[4];
        overflow = (a[3]!=b[3]) && (result[3]!=a[3]);
    end
    ...
endcase
assign zero = (result == 4'b0000);
assign negative = result[3];
```
ADD/SUB reuse the exact flag derivation from program 068's `add_sub`
(carry via a widened intermediate, overflow via the sign-agreement
test). The remaining six opcodes are one-line logic/shift operations with
no carry/overflow meaning, so those two flags simply keep their
default-0 value from the top of the block.

## 10. Testbench Explanation

`tb_alu4` drives all 8 opcodes across the full exhaustive 4-bit `(a,b)`
space (`8 x 16 x 16 = 2048` checks), computing the same per-opcode
reference logic independently in the testbench and comparing `result`
always, plus `carry`/`overflow` only for the ADD/SUB opcodes (where they
are actually meaningful).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | ADD/SUB exhaustive | opcode=000/001, all `(a,b)` | matches program 068's add_sub semantics |
| 2 | logic ops exhaustive | opcode=010/011/100/101, all `(a,b)` | matches `&`/`|`/`^`/`~a` |
| 3 | shift ops exhaustive | opcode=110/111, all `(a,b)` | matches `<<1`/`>>1` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 081` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_alu4` — **PASS**

```text
TEST PASSED: 2048 checks
tb/tb_alu4.v:77: $finish called at 2048000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 127 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `carry`/`overflow` being "don't care" outside ADD/SUB is a documented
  simplification appropriate for a minimal ALU; a fuller design might
  instead define a carry-out for shifts (the bit shifted away).
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Forgetting the default assignments at the top of the `always` block —
  without them, opcodes that don't touch `carry`/`overflow` would infer
  a latch instead of holding a defined 0.
* Reusing the ADD overflow formula for SUB (or vice versa) — the sign
  conditions that indicate overflow are different for addition and
  subtraction (see program 068 §6/§9 for the derivation of both).

## 15. Possible Improvements

* Extend the opcode space to include comparisons (`<`, `==`) and
  wider shift amounts, moving toward program 082's more capable
  hierarchical design.

## 16. What This Program Teaches

* The standard "opcode selects one of several operations, shared flags
  derived from the result" ALU pattern.
* Reuse of a previously-verified arithmetic technique (program 068's
  subtraction/flags) inside a larger design.

## 17. Industry Relevance

Every CPU's ALU follows this same basic shape — arithmetic and logic
operations selected by a control signal, producing a result plus
condition-code flags — scaled up with many more operations, wider
datapaths, and additional flag semantics.

## 18. How to Run

```bash
python3 scripts/run.py 081            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/081-alu-4bit && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/alu4.v tb/tb_alu4.v
vvp build/sim.vvp +vcd
```
