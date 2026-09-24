# 022 — XOR Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `xor_gate` | `src/xor_gate.v` | `tb/tb_xor_gate.v` |

## 1. Objective

Implement a 2-input XOR gate and use it to introduce the "difference /
parity" reading of logic, as opposed to AND/OR's "both/either" reading.

## 2. What the Design Does

`xor_gate` drives `y = a ^ b`. `y` is 1 exactly when `a` and `b` differ.

| `a` | `b` | `y` |
|---|---|---|
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |

## 3. Why It Is Useful

XOR is the bit-difference operator: it is the core of a half-adder's sum
bit (see 062), of parity generation/checking (048), and of Gray-code
conversion (049). "XOR with 1 flips a bit" also makes it the standard
bit-toggle idiom.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | First operand |
| `b` | input | 1 | Second operand |
| `y` | output | 1 | `a XOR b` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a ──┐
     ├──[ =1 ]── y
 b ──┘
```

## 7. Module Hierarchy and Connections

```
tb_xor_gate
└── dut : xor_gate
```

## 8. Verilog Concepts Used

* Continuous assignment with the bitwise-XOR operator `^`.

## 9. Source Code Explanation

```verilog
module xor_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = a ^ b;
endmodule
```

`^` compares the two bits and outputs 1 when they differ — equivalently,
it computes addition modulo 2 without a carry.

## 10. Testbench Explanation

`tb_xor_gate` exhaustively drives all 4 combinations through a `for` loop,
computing `expected = a ^ b` independently, waiting `#1`, and comparing.
Mismatches print an `ERROR:` line; the run ends with the standard
pass/fail line.

## 11. Test Cases and Expected Results

| # | `a` | `b` | Expected `y` |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 2 | 0 | 1 | 1 |
| 3 | 1 | 0 | 1 |
| 4 | 1 | 1 | 0 |

All 4 cases (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 022` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_xor_gate` — **PASS**

```text
a b | y
 0 0 | 0
 0 1 | 1
 1 0 | 1
 1 1 | 0
TEST PASSED: 4 checks
tb/tb_xor_gate.v:37: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* XOR is more expensive in CMOS than AND/OR/NAND/NOR (it needs more
  transistors), which is why synthesis tools try to reuse XOR cells rather
  than rebuild them from smaller gates.
* Purely combinational — no clock or reset.

## 14. Common Mistakes

* Confusing XOR ("differ") with OR ("either") — they agree on 3 of 4 rows
  and are easy to swap by mistake, especially when reading truth tables
  quickly.
* Trying to implement XOR from a single NAND/NOR level — it genuinely needs
  more logic depth than AND/OR (see 027/028 for the multi-gate builds).

## 15. Possible Improvements

* Extend to an N-bit XOR (parity of a bus) — see the reduction-XOR shown in
  006 and used in 048.
* Build XOR from NAND-only or NOR-only gates and compare gate counts (027,
  028).

## 16. What This Program Teaches

* The "difference" logic primitive, distinct from AND/OR.
* Groundwork for adders, parity and Gray-code circuits used throughout the
  rest of the repository.

## 17. Industry Relevance

XOR is the sum-bit operator in every binary adder, the core of parity and
CRC checking, and the toggle operator in LFSRs and scramblers used in
communication links (see 010-communication).

## 18. How to Run

```bash
python3 scripts/run.py 022
cd 01-basic-gates/022-xor-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/xor_gate.v tb/tb_xor_gate.v
vvp build/sim.vvp +vcd
```
