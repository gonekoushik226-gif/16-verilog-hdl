# 109 — Cascaded BCD Counter (3-Digit)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Intermediate | `bcd_counter_3digit` | `src/bcd_counter.v`, `src/bcd_counter_3digit.v` | `tb/tb_bcd_counter_3digit.v` |

## 1. Objective

Chain three of program 108's single-digit BCD counters into a full
000-999 decimal counter, cascaded by enable exactly the way a real
multi-digit counter or display works.

## 2. What the Design Does

`bcd_counter_3digit` cascades three `bcd_counter` instances: `ones`
counts every enabled cycle; `tens` is enabled by `ones`'s `carry_out`
(so it only advances when `ones` is about to wrap); `hundreds` is
similarly enabled by `tens`'s carry. The overall `carry_out` pulses the
cycle the whole count wraps `999 -> 000`.

## 3. Why It Is Useful

This is exactly how a real multi-digit decimal counter or display
works — each digit only advances when the digit below it rolls over,
same as a car odometer or a digital clock's seconds-to-minutes carry.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | count enable |
| `ones`, `tens`, `hundreds` | output | 4 each | each decimal digit, 0-9 |
| `carry_out` | output | 1 | 1 the cycle the full count wraps 999->000 |

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `c_ones` | `ones` digit's carry, enabling `tens` |
| `c_tens` | `tens` digit's carry, enabling `hundreds` |

## 6. Architecture

```
en --[bcd_counter ones]-- c_ones --[bcd_counter tens]-- c_tens --[bcd_counter hundreds]-- carry_out
```
Because each stage's `carry_out` is combinational (program 108 §9), it
is valid *before* the clock edge that would use it — so `tens` correctly
sees "ones is about to wrap" in time to increment on that very same
edge, and likewise for `hundreds`. This is a genuine one-clock-edge
synchronous cascade, not a multi-edge ripple delay.

## 7. Module Hierarchy and Connections

```
bcd_counter_3digit
├── u_ones : bcd_counter (en)     -> ones,     c_ones
├── u_tens : bcd_counter (c_ones) -> tens,     c_tens
└── u_hund : bcd_counter (c_tens) -> hundreds, carry_out
```

## 8. Verilog Concepts Used

* Cascading identical module instances via a combinational carry chain,
  the same structural pattern as program 065's `rca_n` (there, an
  arithmetic carry; here, a decimal-digit carry).

## 9. Source Code Explanation

Each `bcd_counter` instance is wired exactly as in program 108, with the
only design decision being *what drives each stage's `en`*: the top
digit's `en` is the module's own input; every other digit's `en` is the
digit below it's `carry_out`. No additional logic is needed because
`bcd_counter` already produces exactly the right combinational carry
signal.

## 10. Testbench Explanation

`tb_bcd_counter_3digit` runs the full 1000-count cycle (`000`-`999`)
plus 5 more cycles to confirm wraparound back to `000`, checking all
three digits and `carry_out` every single cycle against a software
decimal reference counter (`0..999`), decomposed into digits with `%`
and `/`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full 1000-count cycle | en=1 for 1005 cycles | digits match 000-999 decimal count exactly |
| 2 | carry_out timing | count reaches 999 | carry_out=1 exactly that cycle |
| 3 | wraparound | one more count past 999 | all digits reset to 000 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 109` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_bcd_counter_3digit` — **PASS**

```text
TEST PASSED: 1006 checks
tb/tb_bcd_counter_3digit.v:56: $finish called at 10056000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 51 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This cascade scales to any number of digits by repeating the same
  wiring pattern — the design is not specific to exactly 3 stages beyond
  this program's chosen scope.
* Relies entirely on `bcd_counter`'s `carry_out` being combinational
  (program 108 §13/14) — a registered carry would require one extra
  clock edge of latency per digit, turning this into a slow ripple
  cascade instead of a same-edge synchronous one.

## 14. Common Mistakes

* Wiring a digit's own `carry_out` into its own `en` (instead of the
  digit below's) — would make every digit advance independently rather
  than cascading.
* Assuming the cascade needs extra synchronization logic between
  stages — it does not, precisely because of the combinational carry
  design in program 108.

## 15. Possible Improvements

* Parameterize the number of cascaded digits with a `generate for`
  loop, rather than three fixed instances.

## 16. What This Program Teaches

* Cascading identical counter stages via a combinational carry chain to
  build a wider counter from narrow ones.
* The concrete difference this makes for cascade timing (same-edge vs.
  rippled).

## 17. Industry Relevance

This exact cascade pattern — carry-out from one digit enabling the
next — is how real multi-digit decimal displays, odometers, and BCD
counter ICs (e.g. the 74160/74162 series) are built and chained
together.

## 18. How to Run

```bash
python3 scripts/run.py 109            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/109-cascaded-bcd-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bcd_counter.v src/bcd_counter_3digit.v tb/tb_bcd_counter_3digit.v
vvp build/sim.vvp +vcd
```
