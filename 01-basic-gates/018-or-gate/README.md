# 018 — OR Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `or_gate` | `src/or_gate.v` | `tb/tb_or_gate.v` |

## 1. Objective

Implement and exhaustively verify a 2-input OR gate using the dataflow
`assign` style.

## 2. What the Design Does

`or_gate` drives `y = a | b`. `y` is 1 when at least one input is 1.

| `a` | `b` | `y` |
|---|---|---|
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 1 |

## 3. Why It Is Useful

OR is the other half (with AND) of sum-of-products logic, and is used
everywhere a signal must be asserted when *any* of several conditions holds
— combining interrupt sources, forming "any error" flags, merging enable
paths.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | First operand |
| `b` | input | 1 | Second operand |
| `y` | output | 1 | `a OR b` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a ──┐
     ├──[ >=1 ]── y
 b ──┘
```

A single two-input OR gate; no internal state or hierarchy.

## 7. Module Hierarchy and Connections

```
tb_or_gate
└── dut : or_gate
```

## 8. Verilog Concepts Used

* Continuous assignment (`assign`) with the bitwise-OR operator `|`.
* ANSI-style port list.

## 9. Source Code Explanation

```verilog
module or_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = a | b;
endmodule
```

`assign y = a | b;` continuously drives `y` to the bitwise OR of the two
1-bit inputs. As with `and_gate`, `|` (not `||`) is used deliberately
because this is the bitwise operator that generalizes to buses.

## 10. Testbench Explanation

`tb_or_gate` exhaustively drives all 4 input combinations through a `for`
loop, computes `expected = a | b` independently, waits `#1` for the
combinational path to settle, and compares. Every row is printed; mismatches
print an `ERROR:` line and increment `errors`. The final line follows the
repository's pass/fail contract.

## 11. Test Cases and Expected Results

| # | `a` | `b` | Expected `y` |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 2 | 0 | 1 | 1 |
| 3 | 1 | 0 | 1 |
| 4 | 1 | 1 | 1 |

All 4 cases (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 018` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_or_gate` — **PASS**

```text
a b | y
 0 0 | 0
 0 1 | 1
 1 0 | 1
 1 1 | 1
TEST PASSED: 4 checks
tb/tb_or_gate.v:37: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Maps to a single library OR cell; no timing/area concern at this scale.
* Purely combinational — no clock or reset.

## 14. Common Mistakes

* Confusing bitwise `|` with logical `||` (identical on 1-bit operands, but
  different on buses).
* Assuming OR "cancels" like XOR when both inputs are 1 — OR simply stays
  asserted, it does not toggle back to 0.

## 15. Possible Improvements

* Widen to an N-bit bitwise OR (see the general reduction/gate pattern in
  029).
* Compare against the gate-level primitive `or (y, a, b);` (see 026).

## 16. What This Program Teaches

* The dataflow style for the second basic logic primitive.
* Exhaustive verification methodology, reused unchanged from 017.

## 17. Industry Relevance

`|` compiles directly to a technology OR cell and is the standard way to
combine independent "something happened" conditions in RTL (error flags,
interrupt requests, request-any signals).

## 18. How to Run

```bash
python3 scripts/run.py 018
cd 01-basic-gates/018-or-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/or_gate.v tb/tb_or_gate.v
vvp build/sim.vvp +vcd
```
