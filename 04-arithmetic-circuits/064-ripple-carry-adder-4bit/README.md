# 064 — 4-bit Ripple-Carry Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Beginner | `rca4` | `src/full_adder.v`, `src/rca4.v` | `tb/tb_rca4.v` |

## 1. Objective

Chain four full adders into a fixed 4-bit adder with a carry-in and
carry-out, the structural pattern every wider adder in this category
builds on.

## 2. What the Design Does

`rca4` adds two 4-bit numbers `a`, `b` and an incoming `cin`, producing a
4-bit `sum` and a `carry_out`. Bit `i`'s full adder receives `a[i]`,
`b[i]` and the carry out of bit `i-1` (bit 0 receives `cin`); the carry
"ripples" from the least significant bit to the most significant one
stage at a time.

## 3. Why It Is Useful

A 4-bit adder is the smallest adder wide enough to be genuinely useful
(a BCD digit, a small counter increment, etc.), and its structure — a
chain of identical single-bit cells — is exactly the pattern every wider
or faster adder in this category (069–073) starts from or improves on.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 4 | first operand |
| `b` | input | 4 | second operand |
| `cin` | input | 1 | carry in |
| `sum` | output | 4 | `a + b + cin`, low 4 bits |
| `carry_out` | output | 1 | carry out of bit 3 |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `carry[3:0]` | 4 | per-stage carry; `carry[i]` = carry out of full adder `i` |

## 6. Architecture

```
        cin
         |
a[0],b[0]-[FA0]-carry[0]-+
              sum[0]      |
a[1],b[1]-[FA1]-carry[1]--+
              sum[1]      |
a[2],b[2]-[FA2]-carry[2]--+
              sum[2]      |
a[3],b[3]-[FA3]-carry[3]--+-- carry_out
              sum[3]
```
Each full adder's carry-out feeds the next stage's carry-in — hence
"ripple": bit 3's correct output isn't available until the carry has
propagated through all four stages, which is the fundamental latency
limitation motivating carry-lookahead (program 069) and carry-select
(program 071) adders later in this category.

## 7. Module Hierarchy and Connections

```
rca4
├── fa0 : full_adder (a[0], b[0], cin)      -> sum[0], carry[0]
├── fa1 : full_adder (a[1], b[1], carry[0]) -> sum[1], carry[1]
├── fa2 : full_adder (a[2], b[2], carry[1]) -> sum[2], carry[2]
└── fa3 : full_adder (a[3], b[3], carry[2]) -> sum[3], carry[3]
```

## 8. Verilog Concepts Used

* Structural instantiation of a repeated cell with explicit per-instance
  wiring (no `generate` yet — that's introduced in program 065's
  parameterized version).
* An internal 4-bit carry bus used purely for inter-stage wiring.

## 9. Source Code Explanation

`full_adder` here is a direct sum-of-products implementation
(`sum = a^b^cin`, `carry_out = (a&b)|(a&cin)|(b&cin)`) rather than the
two-half-adder structure from program 063 — logically identical, one
fewer level of hierarchy. `rca4` instantiates four copies, wiring
`carry[i-1]` into stage `i`'s `cin` (stage 0 uses the module's own `cin`)
and taking the final stage's `carry_out` as the module's `carry_out`.

## 10. Testbench Explanation

`tb_rca4` exhaustively drives every combination of 4-bit `a`, 4-bit `b`
and 1-bit `cin` — `16 × 16 × 2 = 512` cases — computing the reference
`a + b + cin` with a 5-bit reg and comparing its bits against
`{carry_out, sum}`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | all 512 `(a,b,cin)` combinations | `{carry_out,sum} == a+b+cin` |
| 2 | max + max + 1 (covered by exhaustive sweep) | a=15,b=15,cin=1 | sum=15, carry_out=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 064` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_rca4` — **PASS**

```text
TEST PASSED: 512 checks
tb/tb_rca4.v:47: $finish called at 512000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 28 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Ripple-carry delay is proportional to width — fine for 4 bits, a real
  concern at 32/64 bits (see programs 069–073 for faster architectures).
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Wiring `cin` into every stage instead of chaining `carry_out` —
  produces four independent 1-bit adders, not a 4-bit adder.
* Off-by-one in the carry index (using `carry[i]` as stage `i`'s own
  carry-in instead of `carry[i-1]`).

## 15. Possible Improvements

* Parameterize the width (done in program 065).
* Replace with carry-lookahead or carry-select for lower critical-path
  delay at larger widths (programs 069–072).

## 16. What This Program Teaches

* How single-bit adder cells compose into a fixed-width adder.
* Why ripple-carry propagation delay grows with operand width.

## 17. Industry Relevance

Ripple-carry adders are simple and area-efficient but rarely used
directly in wide, high-speed datapaths because of their linear delay;
they remain useful for narrow adders or as building blocks inside faster
architectures (e.g. each 4-bit block of a carry-lookahead adder is itself
a small ripple chain, as seen in program 070).

## 18. How to Run

```bash
python3 scripts/run.py 064            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/064-ripple-carry-adder-4bit && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/full_adder.v src/rca4.v tb/tb_rca4.v
vvp build/sim.vvp +vcd
```
