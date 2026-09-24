# 071 — Carry-Select Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `csla` | `src/full_adder.v`, `src/rca_n.v`, `src/csla.v` | `tb/tb_csla.v` |

## 1. Objective

Trade duplicated hardware for lower carry-propagation delay: compute a
segment's result twice (once per possible incoming carry) in parallel
with the segment before it, then simply select the correct one once the
real carry is known.

## 2. What the Design Does

`csla` adds two 8-bit numbers and `cin`. The low nibble is computed once
with its known carry-in. The high nibble is computed *twice*,
speculatively, in parallel with the low nibble — once assuming its
carry-in is 0, once assuming it is 1. A 2:1 mux, controlled by the low
nibble's actual `carry_low`, then picks whichever speculative high-nibble
result turned out to be correct.

## 3. Why It Is Useful

In a ripple-carry adder, the high half cannot even start its correct
computation until the low half's carry arrives. Carry-select removes that
serial dependency for the high half's *computation* (only the final mux
selection remains serial), which is why this architecture historically
gave a good delay/area tradeoff versus pure ripple-carry.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 8 | first operand |
| `b` | input | 8 | second operand |
| `cin` | input | 1 | carry in |
| `sum` | output | 8 | `a + b + cin`, low 8 bits |
| `carry_out` | output | 1 | final carry out |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `sum_low`, `carry_low` | 4, 1 | low-nibble result (single computation) |
| `sum_high0`, `carry_high0` | 4, 1 | high-nibble result assuming carry-in = 0 |
| `sum_high1`, `carry_high1` | 4, 1 | high-nibble result assuming carry-in = 1 |

## 6. Architecture

```
a[3:0],b[3:0],cin --[rca_n WIDTH=4]-- sum_low, carry_low

a[7:4],b[7:4],0   --[rca_n WIDTH=4]-- sum_high0, carry_high0   } computed
a[7:4],b[7:4],1   --[rca_n WIDTH=4]-- sum_high1, carry_high1   } in parallel

sum[7:4]  = carry_low ? sum_high1  : sum_high0
carry_out = carry_low ? carry_high1 : carry_high0
```
Both high-nibble adders run concurrently with the low-nibble adder, not
after it — the mux at the end is the only stage that actually waits on
`carry_low`.

## 7. Module Hierarchy and Connections

```
csla
├── low   : rca_n #(WIDTH=4) (a[3:0], b[3:0], cin) -> sum_low, carry_low
├── high0 : rca_n #(WIDTH=4) (a[7:4], b[7:4], 0)    -> sum_high0, carry_high0
└── high1 : rca_n #(WIDTH=4) (a[7:4], b[7:4], 1)    -> sum_high1, carry_high1
      (each rca_n instantiates 4x full_adder internally)
```

## 8. Verilog Concepts Used

* Reusing the same parameterized module (`rca_n` from program 065) three
  times with different static `cin` values (`1'b0`, `1'b1`) to build
  speculative parallel paths.
* Ternary-operator 2:1 muxing of both a data bus and a single carry bit
  from the same select signal.

## 9. Source Code Explanation

```verilog
rca_n #(.WIDTH(4)) high0 (.a(a[7:4]), .b(b[7:4]), .cin(1'b0), ...);
rca_n #(.WIDTH(4)) high1 (.a(a[7:4]), .b(b[7:4]), .cin(1'b1), ...);
assign sum[7:4]  = carry_low ? sum_high1  : sum_high0;
assign carry_out = carry_low ? carry_high1 : carry_high0;
```
Both `high0` and `high1` add the same operand bits, differing only in
their assumed carry-in — exactly the two possibilities `carry_low` can
take. Once `carry_low` resolves, the correct pre-computed pair is simply
routed to the output.

## 10. Testbench Explanation

`tb_csla` drives 3000 random `(a,b,cin)` triples plus six directed cases
chosen to force `carry_low` to 0 in one case and to 1 in others (so both
mux paths are actually exercised, not just whichever happens to appear in
random data), plus full-width propagate/generate corners. All are checked
against a 9-bit Verilog reference `a+b+cin`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | random | 3000 random `(a,b,cin)` | matches `a+b+cin` |
| 2 | carry_low=0 forced | a=0x01,b=0x01,cin=0 | high nibble takes the cin=0 path |
| 3 | carry_low=1 forced | a=0x0F,b=0x01,cin=0 | high nibble takes the cin=1 path |
| 4 | full-width corners | 0xFF+0xFF+1, 0x00+0x00+0 | correct wrap/carry |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 071` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_csla` — **PASS**

```text
TEST PASSED: 3006 checks
tb/tb_csla.v:57: $finish called at 3006000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 89 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Costs roughly 1.5x the adder hardware of a plain ripple-carry adder (an
  extra speculative high-nibble adder) to shorten the critical path — a
  classic area/speed tradeoff.
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Muxing only `sum_high` but forgetting `carry_out` also needs the same
  select — an easy bug since the carry mux is easy to overlook next to
  the wider data mux.
* Using the same `cin` for both speculative high-nibble adders (defeats
  the entire technique — they must assume opposite carry-in values).

## 15. Possible Improvements

* Generalize to more/narrower segments and compare mux count vs. segment
  width, or extend recursively (carry-select adders can themselves be
  built from smaller carry-select adders).

## 16. What This Program Teaches

* The speculate-then-select technique for hiding carry-propagation delay
  behind parallel computation.
* Reusing a parameterized module multiple times with different static
  arguments to build alternative parallel paths.

## 17. Industry Relevance

Carry-select was a standard fast-adder architecture in real ALUs before
parallel-prefix (Kogge-Stone, Brent-Kung) adders became more common at
very wide widths; the speculate/select idea itself remains a general
technique for removing a dependency from a critical path whenever both
possible outcomes can be computed cheaply.

## 18. How to Run

```bash
python3 scripts/run.py 071            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/071-carry-select-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/full_adder.v src/rca_n.v src/csla.v tb/tb_csla.v
vvp build/sim.vvp +vcd
```
