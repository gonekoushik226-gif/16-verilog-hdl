# 116 — Tick Generator (Clock Enable, Not Derived Clock)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `tick_generator` | `src/tick_generator.v` | `tb/tb_tick_generator.v` |

## 1. Objective

Produce a periodic single-cycle pulse ("tick") on the *original* fast
clock, as the standard alternative to programs 114/115's approach of
deriving an entirely separate, slower clock.

## 2. What the Design Does

`tick_generator` counts `0..PERIOD-1` and asserts `tick` for exactly one
cycle every `PERIOD` cycles — used as a clock-enable by downstream logic
that should only act once every `PERIOD` cycles of the fast clock.

## 3. Why It Is Useful

Real designs increasingly avoid deriving actual separate clocks (as
programs 114/115 do) because every additional clock domain adds real
complexity: its own clock tree, its own timing-closure analysis, and its
own clock-domain-crossing concerns wherever it meets other clocks.
Using a clock-enable pulse on one shared fast clock avoids all of that —
this is the modern, generally preferred technique.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | generator enable |
| `tick` | output | 1 | 1 for exactly one cycle every `PERIOD` cycles |

Parameters: `PERIOD` (default 10).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `cnt` | `$clog2(PERIOD)` | counts `0..PERIOD-1` |

## 6. Architecture

```
cnt counts 0..PERIOD-1 while en=1, wrapping
tick = en & (cnt == PERIOD-1)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A combinational terminal-count-style flag (`tick`), the same technique
  as program 106's `tc` and program 108's `carry_out` — available the
  entire cycle the condition holds, not a delayed registered pulse.

## 9. Source Code Explanation

```verilog
assign tick = en & (cnt == PERIOD-1);
```
Because `tick` is combinational from `cnt`, it is high for exactly the
one cycle `cnt` sits at `PERIOD-1`, before `cnt` wraps back to 0 on the
following edge — a clean single-cycle pulse with no extra registration
delay.

## 10. Testbench Explanation

`tb_tick_generator` runs several periods, recording the cycle number of
every observed `tick` and checking consecutive ticks are always exactly
`PERIOD` cycles apart, plus a hold check confirming no ticks occur while
`en=0`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | tick spacing | 4 periods, en=1 | consecutive ticks exactly PERIOD cycles apart |
| 2 | hold | en=0 | no ticks |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 116` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_tick_generator` — **PASS**

```text
TEST PASSED: 26 checks
tb/tb_tick_generator.v:71: $finish called at 256000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Unlike programs 114/115, this module produces no derived clock at all
  — `tick` is meant to be consumed as a clock-enable on the *same* clock
  domain, not treated as a clock signal itself.

## 14. Common Mistakes

* Using `tick` as if it were a clock (e.g. `always @(posedge tick)`)
  instead of a clock-enable (`if (tick) ...` inside a block clocked by
  the original `clk`) — defeats the entire purpose of avoiding a derived
  clock domain.

## 15. Possible Improvements

* Add a runtime-programmable period (this is exactly program 117's
  prescaler).

## 16. What This Program Teaches

* The clock-enable-on-shared-clock pattern as the preferred modern
  alternative to deriving separate clock domains for simple periodic
  timing.

## 17. Industry Relevance

Real RTL overwhelmingly prefers clock-enable pulses like this one over
literal derived clocks wherever possible, specifically to keep timing
closure and clock-domain-crossing analysis simple — genuinely separate
clock domains (program 114/115-style) are reserved for cases that
actually need a different clock frequency for external interfacing.

## 18. How to Run

```bash
python3 scripts/run.py 116            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/116-tick-generator && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/tick_generator.v tb/tb_tick_generator.v
vvp build/sim.vvp +vcd
```
