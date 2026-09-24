# 108 — BCD Decade Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `bcd_counter` | `src/bcd_counter.v` | `tb/tb_bcd_counter.v` |

## 1. Objective

Specialize program 107's general modulo-N counter to the single most
common non-power-of-two case: one decimal digit, 0-9, with a carry
output shaped specifically for cascading into more digits (program 109).

## 2. What the Design Does

`bcd_counter` counts `0..9` and wraps back to 0. `carry_out` is
combinational: 1 throughout the cycle the counter sits at 9 while
enabled.

## 3. Why It Is Useful

Every multi-digit decimal display or counter (a stopwatch, program 161;
a digital clock, program 162; a frequency counter, program 163) is built
from cascaded single-BCD-digit counters exactly like this one.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | count enable |
| `count` | output | 4 | current digit, 0-9 |
| `carry_out` | output | 1 | 1 while `count=9` and enabled |

## 5. Internal Signals

None — `count` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  count <= 0
    else if (en) count <= (count==9) ? 0 : count+1

carry_out = en & (count == 9)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* The same explicit-modulus pattern as program 107, specialized to a
  fixed `MOD=10` with a 4-bit register (matching BCD digit width
  exactly, unlike `$clog2(10)=4` which happens to coincide here but
  would not for every modulus).

## 9. Source Code Explanation

```verilog
assign carry_out = en & (count == 4'd9);
```
`carry_out` is deliberately combinational (not a registered pulse) so
that, when wired into a next digit's `en` input (program 109), the next
digit can increment on the *same* clock edge this digit wraps — a
genuine synchronous cascade, not a one-cycle-delayed ripple.

## 10. Testbench Explanation

`tb_bcd_counter` runs a full decade (10 values) plus 5 more to confirm
wraparound, checking both `count` and `carry_out` every cycle against a
software 0-9 reference.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full decade + wrap | en=1 for 15 cycles | counts 0-9, wraps, continues |
| 2 | carry_out timing | count reaches 9 | carry_out=1 exactly that cycle |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 108` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_bcd_counter` — **PASS**

```text
TEST PASSED: 16 checks
tb/tb_bcd_counter.v:53: $finish called at 156000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This is functionally a fixed-modulus specialization of program 107;
  it is kept as its own program specifically because BCD counters are
  common enough, and cascading them (program 109) common enough, to
  merit a dedicated, directly-reusable design.

## 14. Common Mistakes

* Registering `carry_out` — breaks the same-edge cascade timing program
  109 relies on (see program 106 §13/14 for the identical
  consideration).

## 15. Possible Improvements

* Add a synchronous or asynchronous digit-preset input.

## 16. What This Program Teaches

* The single-digit BCD counter as the standard cascadable building
  block for multi-digit decimal counting.

## 17. Industry Relevance

BCD counters are the standard building block for any decimal (as
opposed to pure binary) display or counting logic — digital clocks,
stopwatches, odometers, and frequency counters all cascade digit
counters exactly like this one.

## 18. How to Run

```bash
python3 scripts/run.py 108            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/108-bcd-decade-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bcd_counter.v tb/tb_bcd_counter.v
vvp build/sim.vvp +vcd
```
