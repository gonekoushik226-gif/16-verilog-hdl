# 014 — Functions and Tasks

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Intermediate | `func_demo` | `src/func_demo.v` | `tb/tb_func_demo.v` |

## 1. Objective

Package reusable combinational computations as synthesizable functions, and
structure testbenches with tasks and automatic (recursive) functions.

## 2. What the Design Does

For an 8-bit `data` input:

| Output | Function used | Example `10110100` |
|---|---|---|
| `ones` | `count_ones` | 4 |
| `parity` | LSB of the count | 0 |
| `reversed` | `reverse_bits` | `00101101` |
| `lowest_one` | `find_lowest` | 2 |
| `any_one` | reduction OR | 1 |

## 3. Why It Is Useful

Functions remove duplicated expressions (a CRC step, an ECC syndrome, a
priority scan) and keep them testable. Tasks turn testbenches into readable
sequences of operations (`apply_and_check(x)` instead of repeated blocks of
assignments and comparisons).

## 4. Interface

| Port | Dir | Width | Description |
|---|---|---|---|
| `data` | in | 8 | Input word |
| `ones` | out | 4 | Number of 1 bits (0–8) |
| `parity` | out | 1 | Odd parity |
| `reversed` | out | 8 | Bit-reversed `data` |
| `lowest_one` | out | 3 | Index of the least significant 1 (0 when `data = 0`) |
| `any_one` | out | 1 | `data != 0`; qualifies `lowest_one` |

## 5. Internal Signals

None; functions have local variables (`integer i`) that exist only during
evaluation and generate no registers.

## 6. Architecture

Each function call expands into combinational logic: an adder tree for
`count_ones`, pure wiring for `reverse_bits`, a priority chain for
`find_lowest`.

## 7. Module Hierarchy and Connections

```
tb_func_demo
└── dut : func_demo
```

## 8. Verilog Concepts Used

* `function [N:0] name; input …; begin … end endfunction` (Verilog-1995
  style declarations inside a module).
* Loops with constant bounds inside functions (unrolled by synthesis).
* `function automatic` — re-entrant, allows recursion (testbench).
* `task` with inputs, local variables and timing (`#1`).
* A task calling another task.

## 9. Source Code Explanation

```verilog
function [3:0] count_ones;
    input [7:0] v;
    integer i;
    begin
        count_ones = 4'd0;
        for (i = 0; i < 8; i = i + 1)
            count_ones = count_ones + {3'b000, v[i]};
    end
endfunction
```
The function name acts as the return variable. The loop adds each bit; the
explicit `{3'b000, v[i]}` widens the 1-bit operand to the 4-bit accumulator
(Verilator flagged the implicit widening in the first version). Synthesis
unrolls the loop into an adder tree.

```verilog
function [7:0] reverse_bits;
    …
    for (i = 0; i < 8; i = i + 1)
        reverse_bits[i] = v[7 - i];
```
Only wires after synthesis.

```verilog
function [2:0] find_lowest;
    …
    find_lowest = 3'd0;
    for (i = 7; i >= 0; i = i - 1)
        if (v[i]) find_lowest = i[2:0];
```
Scanning from MSB to LSB, later (lower) matches overwrite earlier ones, so the
lowest set bit wins. The default `3'd0` avoids an undefined result for zero
input; `any_one` tells the user whether the index is meaningful.

```verilog
assign ones       = count_ones(data);
assign parity     = ones[0];
assign reversed   = reverse_bits(data);
assign lowest_one = find_lowest(data);
assign any_one    = |data;
```
Functions are called in continuous assignments like operators. Parity reuses
the count: an odd number of ones means the count's LSB is 1.

## 10. Testbench Explanation

* `ref_popcount` and `ref_lowest` are **recursive automatic functions** —
  a different algorithm from the RTL loops. Without `automatic`, all calls
  would share one set of variables and recursion would corrupt them.
* `apply_and_check(value)` drives `data`, waits 1 ns, builds the expected
  reversed word with a loop and compares all five outputs.
* `show(value)` calls `apply_and_check` and prints a table row.
* Five directed values are shown, then all 256 inputs are checked.

## 11. Test Cases and Expected Results

| # | data | ones | parity | reversed | lowest | any |
|---|---|---|---|---|---|---|
| 1 | 00000000 | 0 | 0 | 00000000 | 0 | 0 |
| 2 | 00000001 | 1 | 1 | 10000000 | 0 | 1 |
| 3 | 10000000 | 1 | 1 | 00000001 | 7 | 1 |
| 4 | 10110100 | 4 | 0 | 00101101 | 2 | 1 |
| 5 | 11111111 | 8 | 0 | 11111111 | 0 | 1 |

Plus all 256 values.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 014` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_func_demo` — **PASS**

```text
data   | ones par reversed lowest any
00000000 |  0     0    00000000     0     0
00000001 |  1     1    10000000     0     1
10000000 |  1     1    00000001     7     1
10110100 |  4     0    00101101     2     1
11111111 |  8     0    11111111     0     1
TEST PASSED: 261 checks
tb/tb_func_demo.v:81: $finish called at 261000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 55 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Synthesizable functions must be purely combinational: no delays, no event
  controls, no non-blocking assignments, and loops with constant bounds.
* Functions in RTL are static by default in Verilog-2005; recursion is only
  safe in `automatic` functions and is normally reserved for testbenches.
* Tasks may contain timing and are the natural unit for testbench stimulus
  and bus-functional models (see 281).

## 14. Common Mistakes

* Forgetting to assign the function's return value on every path → `x`.
* Using a data-dependent loop bound in RTL functions — not synthesizable.
* Calling a task from a continuous assignment (only functions can be used in
  expressions).
* Recursion in a non-automatic function.

## 15. Possible Improvements

* Parameterize the width with a constant function.
* Move common checks into a shared testbench include file for larger
  projects.

## 16. What This Program Teaches

* Writing synthesizable functions.
* Automatic functions and recursion.
* Task-based testbench structure.

## 17. Industry Relevance

CRC, ECC and hashing blocks are commonly written as functions that describe
one step of the algorithm; testbench tasks are the basis of bus functional
models and verification libraries.

## 18. How to Run

```bash
python3 scripts/run.py 014
cd 00-foundations/014-functions-and-tasks && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/func_demo.v tb/tb_func_demo.v
vvp build/sim.vvp
```
