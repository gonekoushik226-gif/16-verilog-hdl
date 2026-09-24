# 065 — Parameterized Ripple-Carry Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Elementary | `rca_n` | `src/full_adder.v`, `src/rca_n.v` | `tb/tb_rca_n.v` |

## 1. Objective

Generalize program 064's fixed 4-bit ripple-carry adder to any width
using a `generate for` loop, and verify it at two very different widths
(4 and 32) with the same source.

## 2. What the Design Does

`rca_n #(.WIDTH(N))` adds two `N`-bit operands plus a carry-in, producing
an `N`-bit sum and carry-out, using the same per-bit ripple topology as
program 064 but instantiated `WIDTH` times by a `generate` loop instead of
being written out by hand.

## 3. Why It Is Useful

Real designs need adders of many different widths (8, 16, 32, 64 bits);
writing out each width by hand does not scale. A parameterized module
compiled once per instantiation is the standard way to reuse the same
verified logic at any width.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | `WIDTH` | first operand |
| `b` | input | `WIDTH` | second operand |
| `cin` | input | 1 | carry in |
| `sum` | output | `WIDTH` | `a + b + cin`, low `WIDTH` bits |
| `carry_out` | output | 1 | carry out of the top bit |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 4 | operand/result width in bits |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `carry[WIDTH:0]` | `WIDTH+1` | per-stage carry chain; `carry[0]=cin`, `carry[WIDTH]=carry_out` |

## 6. Architecture

Identical ripple topology to program 064, generalized to `WIDTH` stages:
```
carry[0] = cin
for i in 0..WIDTH-1:
    {sum[i], carry[i+1]} = full_adder(a[i], b[i], carry[i])
carry_out = carry[WIDTH]
```

## 7. Module Hierarchy and Connections

```
rca_n #(.WIDTH(N))
└── stage[i] (generate block, i = 0..N-1)
    └── fa : full_adder (a[i], b[i], carry[i]) -> sum[i], carry[i+1]
```

## 8. Verilog Concepts Used

* `parameter WIDTH` with a default, overridden per instance with `#(...)`.
* `genvar` and `generate for` to instantiate a variable number of cells,
  each wrapped in a named generate block (`stage[i]`) for readable
  hierarchical names in waveforms.
* A `[WIDTH:0]` carry bus sized from the parameter itself.

## 9. Source Code Explanation

```verilog
wire [WIDTH:0] carry;
assign carry[0] = cin;
genvar i;
generate
    for (i = 0; i < WIDTH; i = i + 1) begin : stage
        full_adder fa (.a(a[i]), .b(b[i]), .cin(carry[i]),
                        .sum(sum[i]), .carry_out(carry[i+1]));
    end
endgenerate
assign carry_out = carry[WIDTH];
```
The loop is elaborated at compile time into `WIDTH` separate `full_adder`
instances, each named `stage[i].fa`; the carry bus is exactly one bit
wider than the operands so `carry[0]` can hold `cin` and `carry[WIDTH]`
can hold the final carry-out without a special case.

## 10. Testbench Explanation

Two DUT instances run side by side: `dut4` (`WIDTH=4`) is checked
exhaustively over all 512 `(a,b,cin)` combinations exactly as in program
064; `dut32` (`WIDTH=32`) is checked with 2000 `$random`-generated operand
pairs plus three explicit corner cases (all-ones + 1, all-ones + all-ones
+ 1, zero + zero). Both are compared against Verilog integer arithmetic
widened enough to hold the carry bit.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | WIDTH=4 exhaustive | all 512 combinations | matches `a+b+cin` |
| 2 | WIDTH=32 random | 2000 random operand/cin triples | matches `a+b+cin` |
| 3 | WIDTH=32 corners | all-ones+1, all-ones+all-ones+1, 0+0 | correct wrap and carry |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 065` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_rca_n` — **PASS**

```text
TEST PASSED: 2515 checks
tb/tb_rca_n.v:80: $finish called at 2515000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 28 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* At `WIDTH=32` the ripple critical path is 32 full-adder delays — this
  program demonstrates correctness, not speed; see programs 069–072 for
  faster architectures at scale.
* `$clog2` is not needed here since no index/width is derived from
  `WIDTH` beyond the carry bus size, which is simply `WIDTH+1`.

## 14. Common Mistakes

* Forgetting the named generate block label (`: stage`), which makes
  waveform hierarchy far harder to read for wide instances.
* Sizing the carry bus as `[WIDTH-1:0]` instead of `[WIDTH:0]`, losing a
  bit needed for `carry_out`.

## 15. Possible Improvements

* Add a `generate if` to special-case `WIDTH==1` (a single full adder)
  versus the general chained case, purely as an exercise in conditional
  generate blocks — functionally unnecessary here since the loop already
  handles `WIDTH==1` correctly.

## 16. What This Program Teaches

* Writing width-generic structural RTL with `generate for`.
* Verifying the same RTL at multiple parameter values in one testbench.

## 17. Industry Relevance

Parameterized generate-based instantiation is the standard way IP blocks
(adders, FIFOs, register files, ...) are made reusable across many
projects and bus widths without duplicating source code.

## 18. How to Run

```bash
python3 scripts/run.py 065            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/065-ripple-carry-adder-parameterized && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/full_adder.v src/rca_n.v tb/tb_rca_n.v
vvp build/sim.vvp +vcd
```
