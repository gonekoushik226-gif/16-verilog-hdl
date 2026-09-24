# 009 — Conditional Statements

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Elementary | `conditional_demo` | `src/conditional_demo.v` | `tb/tb_conditional_demo.v` |

## 1. Objective

Describe decisions with the conditional operator, `if/else`, `case` and
`casez`, and understand which hardware each produces (parallel multiplexer or
priority chain).

## 2. What the Design Does

| Output | Written with | Function |
|---|---|---|
| `mux_out` | `sel ? a : b` | 2:1 multiplexer on 2-bit data |
| `prio_if`, `prio_valid` | `if / else if` chain | index of the highest set bit of `req` (bit 3 wins) |
| `prio_casez` | `casez` with `?` wildcards | the same priority function |
| `alu_out` | `case (op)` | `op`=0 AND, 1 OR, 2 XOR, 3 ADD (modulo 4) |

`prio_if` and `prio_casez` are two descriptions of the same logic; the
testbench proves they are identical for all inputs.

## 3. Why It Is Useful

Every controller, decoder, arbiter and ALU is a set of conditional
statements. Choosing between priority (`if` chain) and parallel (`case`)
structures affects timing, and writing them without gaps avoids latches.

## 4. Interface

| Port | Dir | Width | Description |
|---|---|---|---|
| `a`, `b` | in | 2 | Data operands |
| `sel` | in | 1 | Mux select |
| `req` | in | 4 | Request vector, bit 3 highest priority |
| `op` | in | 2 | ALU operation select |
| `mux_out` | out | 2 | `sel ? a : b` |
| `prio_if` | out | 2 | Highest active request (if/else) |
| `prio_casez` | out | 2 | Highest active request (casez) |
| `prio_valid` | out | 1 | Any request active |
| `alu_out` | out | 2 | Result of `op` |

## 5. Internal Signals

None.

## 6. Architecture

```
sel ──► 2:1 mux ────────────────────────────► mux_out
req ──► priority chain (req3 > req2 > req1 > req0) ──► prio_if, prio_valid
req ──► same chain written as casez ─────────► prio_casez
op  ──► 4:1 mux of {a&b, a|b, a^b, a+b} ─────► alu_out
```

## 7. Module Hierarchy and Connections

```
tb_conditional_demo
└── dut : conditional_demo
```

## 8. Verilog Concepts Used

* Conditional operator `?:` in a continuous assignment.
* `if / else if / else` chains inside `always @(*)` — evaluated in order.
* `case` with `default`.
* `casez` — `?` (or `z`) in a case item is a don't-care bit.
* Default assignment at the top of a combinational block (`prio_valid = 1`)
  overridden in one branch.

## 9. Source Code Explanation

```verilog
assign mux_out = sel ? a : b;
```
If `sel` is 1 the result is `a`, otherwise `b`. If `sel` is `x` in simulation,
the operator merges `a` and `b` bit by bit (equal bits pass, different bits
become `x`).

```verilog
always @(*) begin
    prio_valid = 1'b1;
    if (req[3])      prio_if = 2'd3;
    else if (req[2]) prio_if = 2'd2;
    else if (req[1]) prio_if = 2'd1;
    else if (req[0]) prio_if = 2'd0;
    else begin
        prio_if    = 2'd0;
        prio_valid = 1'b0;
    end
end
```
The first true condition wins, so `req[3]` has the highest priority — this
chain *is* the specification of a priority encoder. `prio_valid` gets a
default value at the top and is overridden only in the "no request" branch;
because both outputs are assigned on every path, no latch is inferred. The
final `else` also distinguishes "request 0 active" from "nothing active",
which share `prio_if = 0`.

```verilog
casez (req)
    4'b1???: prio_casez = 2'd3;
    4'b01??: prio_casez = 2'd2;
    4'b001?: prio_casez = 2'd1;
    default: prio_casez = 2'd0;
endcase
```
`?` matches any bit value. Case items are also checked **in order**, but here
they are written to be mutually exclusive (each item fixes the bits above the
leading 1), so the order does not matter.

```verilog
case (op)
    2'd0:    alu_out = a & b;
    2'd1:    alu_out = a | b;
    2'd2:    alu_out = a ^ b;
    default: alu_out = a + b;
endcase
```
A parallel selection: exactly one item matches each `op`. `default` covers
`2'd3`, and in simulation also catches `x`/`z` on `op`, which would otherwise
leave `alu_out` unchanged (a latch-like simulation behaviour).

## 10. Testbench Explanation

The 11 input bits `{a, b, sel, req, op}` are swept through all 2048
combinations by assigning a counter to the concatenation. The reference model
finds the priority by scanning `req` from bit 0 upward and keeping the last hit
(a different algorithm from the RTL), and computes the ALU result with
`(a + b) % 4`. Afterwards the bench prints the priority table for all 16
request patterns and the four ALU operations.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | exhaustive 2048 combinations | all five outputs match the model |
| 2 | `req = 0000` | `prio_valid = 0`, index 0 |
| 3 | `req = 0001` | `prio_valid = 1`, index 0 |
| 4 | `req = 1xxx` | index 3 regardless of lower bits |
| 5 | `a=10, b=11`, op 0..3 | 10, 11, 01, 01 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 009` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_conditional_demo` — **PASS**

```text
req  | prio_if prio_casez valid
 0000 |    0        0       0
 0001 |    0        0       1
 0010 |    1        1       1
 0011 |    1        1       1
 0100 |    2        2       1
 0101 |    2        2       1
 0110 |    2        2       1
 0111 |    2        2       1
 1000 |    3        3       1
 1001 |    3        3       1
 1010 |    3        3       1
 1011 |    3        3       1
 1100 |    3        3       1
 1101 |    3        3       1
 1110 |    3        3       1
 1111 |    3        3       1
 a  b  op | alu_out
 10 11 0  |  10
 10 11 1  |  11
 10 11 2  |  01
 10 11 3  |  01
TEST PASSED: 2048 checks
tb/tb_conditional_demo.v:68: $finish called at 2068000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 31 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* An `if/else if` chain describes priority. Synthesis may flatten it, but
  logically each condition depends on all previous ones failing.
* `case` on mutually exclusive values gives a balanced multiplexer.
* Every combinational block must assign every output on every path:
  default assignments at the top of the block are the simplest guarantee.
* Avoid `casex`: an `x` on the *selector* in simulation matches any item and
  hides bugs. `casez` is safer (only `z`/`?` are wildcards).

## 14. Common Mistakes

* **Missing `else` or `default`** → latch inferred (Yosys would report it and
  this repository's flow would fail the program).
* **Overlapping `casez` items** in the wrong order.
* **Using synthesis pragmas `full_case`/`parallel_case`** to silence warnings:
  they make synthesis and simulation disagree.
* **Nested ternaries without parentheses** — hard to read and easy to
  misgroup.

## 15. Possible Improvements

* Parameterized priority encoder (043).
* One-hot select multiplexers (`AND-OR` form) for wide datapaths.

## 16. What This Program Teaches

* The four conditional constructs and their hardware meaning.
* Priority vs parallel logic.
* Latch-free combinational coding.

## 17. Industry Relevance

Interrupt priority logic, arbiters and instruction decoders are written with
exactly these constructs. Lint tools in industrial flows check for missing
defaults, `casex` usage and incomplete assignments.

## 18. How to Run

```bash
python3 scripts/run.py 009
cd 00-foundations/009-conditional-statements && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/conditional_demo.v tb/tb_conditional_demo.v
vvp build/sim.vvp
```
