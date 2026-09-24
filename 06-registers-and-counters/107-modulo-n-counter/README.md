# 107 — Modulo-N Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `mod_n_counter` | `src/mod_n_counter.v` | `tb/tb_mod_n_counter.v` |

## 1. Objective

Generalize wraparound beyond the "free" power-of-two case (programs
104-106) to an arbitrary modulus, using `$clog2` to size the register
from the parameter itself.

## 2. What the Design Does

`mod_n_counter` counts `0..MOD-1` and wraps back to 0, for any `MOD`
(not just a power of two).

## 3. Why It Is Useful

Real counters very often need a non-power-of-two range — a 0-9 decade
digit is a modulus-10 counter (program 108), a 60-second/minute counter
is modulus-60, and so on. This program isolates the general technique
before those specific cases.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | count enable |
| `count` | output | `$clog2(MOD)` | current count, `0..MOD-1` |
| `tc` | output | 1 | 1 when `count == MOD-1` (about to wrap) |

Parameters: `MOD` (default 10).

## 5. Internal Signals

None — `count` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  count <= 0
    else if (en) count <= (count == MOD-1) ? 0 : count+1
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* `$clog2(MOD)` sizing the count register's width from the parameter,
  so `count` is always exactly wide enough to hold `0..MOD-1` regardless
  of `MOD`'s value.
* Explicit wraparound comparison (`count == MOD-1`), needed here because
  — unlike programs 104-106 — `MOD` is not generally a power of two, so
  plain unsigned overflow would wrap at the wrong point.

## 9. Source Code Explanation

```verilog
output reg [$clog2(MOD)-1:0] count,
...
if (count == MOD-1) count <= {$clog2(MOD){1'b0}};
else                count <= count + 1'b1;
```
Because `count`'s width is only just large enough for `MOD-1` (not
necessarily `2^WIDTH-1`), simply letting the register overflow would
wrap at the next power of two above `MOD`, not at `MOD` itself — the
explicit comparison is what enforces the correct modulus.

## 10. Testbench Explanation

`tb_mod_n_counter` instantiates three DUTs at different moduli — 5, 10,
and 13 (deliberately not a power of two) — running all three for more
than two full cycles of the largest modulus, checked against independent
software reference counters for each.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | MOD=5 | 30 cycles | counts 0-4 repeatedly |
| 2 | MOD=10 | 30 cycles | counts 0-9 repeatedly |
| 3 | MOD=13 | 30 cycles | counts 0-12 repeatedly (non-power-of-two modulus) |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 107` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_mod_n_counter` — **PASS**

```text
TEST PASSED: 31 checks
tb/tb_mod_n_counter.v:57: $finish called at 306000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `$clog2` correctly sizes `count` even for `MOD` values that aren't
  themselves powers of two (e.g. `$clog2(13)=4`, giving a 4-bit register
  that can hold 0-15 even though only 0-12 are ever used).

## 14. Common Mistakes

* Relying on unsigned overflow instead of an explicit `MOD-1` comparison
  — correct only when `MOD` happens to be exactly `2^WIDTH`, silently
  wrong (wrapping at the next power of two) for any other modulus.
* Off-by-one in the wrap comparison (`count == MOD` instead of `count ==
  MOD-1`) — the counter would briefly reach the invalid value `MOD`
  before wrapping.

## 15. Possible Improvements

* Add a loadable start value and terminal-count output, combining with
  program 106's design.

## 16. What This Program Teaches

* Sizing a register with `$clog2` from a parameter.
* Why non-power-of-two moduli need explicit wraparound logic, unlike the
  "free" wraparound of programs 104-106.

## 17. Industry Relevance

Arbitrary-modulus counters are everywhere real timing or sequencing
doesn't naturally land on a power of two — clock dividers for non-power-
of-two ratios, time-of-day counters (60 seconds, 24 hours), and
protocol-specific sequence counters.

## 18. How to Run

```bash
python3 scripts/run.py 107            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/107-modulo-n-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/mod_n_counter.v tb/tb_mod_n_counter.v
vvp build/sim.vvp +vcd
```
