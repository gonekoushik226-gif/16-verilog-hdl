# 114 — Clock Divider (Even)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `clock_divider_even` | `src/clock_divider_even.v` | `tb/tb_clock_divider_even.v` |

## 1. Objective

Derive a slower, exactly-50%-duty clock from a faster one, for the
simple case where the division ratio is even.

## 2. What the Design Does

`clock_divider_even` toggles `clk_out` every `DIV/2` input clock cycles,
producing an output clock at `1/DIV` the input frequency with an exact
50% duty cycle.

## 3. Why It Is Useful

Many designs need a slower clock derived from a faster reference (a
timekeeping tick, a slower peripheral interface, a visible LED blink
rate) — dividing by an even number is the simple case, contrasted with
program 115's genuinely harder odd-division problem.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | input clock, asynchronous active-low reset |
| `clk_out` | output | 1 | divided clock, `1/DIV` the frequency |

Parameters: `DIV` (default 4, must be even, >= 2).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `cnt` | `$clog2(HALF)` | counts up to `HALF-1` before each toggle |
| `half_m1` | `$clog2(HALF)` | `HALF-1` as an explicitly-sized constant |

## 6. Architecture

```
cnt counts 0..HALF-1, HALF = DIV/2
on reaching HALF-1: cnt <= 0, clk_out <= ~clk_out
```
Both the high and low phases last exactly `HALF` input cycles, so the
duty cycle is automatically 50% with no extra correction.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* `$clog2` sizing the counter from a derived parameter (`HALF =
  DIV/2`), not `DIV` directly.
* An explicitly-sized comparison constant (`half_m1`, a `wire` of the
  exact counter width) rather than comparing directly against a wider
  default-width expression — see §13 for why.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 0; clk_out <= 0;
    end else if (cnt == half_m1) begin
        cnt <= 0; clk_out <= ~clk_out;
    end else begin
        cnt <= cnt + 1'b1;
    end
end
```
`clk_out` toggles exactly once every `HALF` cycles of `cnt` reaching its
terminal value — a direct application of program 091's toggle-flip-flop
idea, gated by a modulus-`HALF` counter instead of every single cycle.

## 10. Testbench Explanation

`tb_clock_divider_even` instantiates three DUTs at `DIV=4,6,8` and, for
each, measures the actual simulation-time period and high-duration
between real edges of `clk_out`, checking period `== DIV*Tclk` and
high-time `== DIV*Tclk/2` exactly.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | DIV=4 | measure period/duty | period=4*Tclk, duty=50% |
| 2 | DIV=6 | measure period/duty | period=6*Tclk, duty=50% |
| 3 | DIV=8 | measure period/duty | period=8*Tclk, duty=50% |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 114` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_clock_divider_even` — **PASS**

```text
TEST PASSED: 6 checks
tb/tb_clock_divider_even.v:69: $finish called at 275000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 4 cells
Lint (Verilator 5.020 `--lint-only`): warnings — WIDTHTRUNC
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Verilator's lint reports a `WIDTHTRUNC` warning on `half_m1`'s
  assignment: `HALF-1` is computed at a wider default integer width
  (32 bits) before being assigned into the exact `$clog2(HALF)`-bit
  target, and while this truncation is always safe by construction
  (`HALF-1` always fits, since `HALF <= 2^$clog2(HALF)`), plain
  Verilog-2005 has no explicit width-cast operator to silence the
  warning cleanly the way SystemVerilog's `N'(expr)` syntax could.
  Documented as an accepted, provably-benign warning rather than worked
  around with a `verilator lint_off` pragma.

## 14. Common Mistakes

* Toggling on `cnt == HALF` instead of `cnt == HALF-1` — off-by-one,
  giving a period of `DIV+2` cycles instead of `DIV`.
* Sizing the counter from `DIV` instead of `HALF` — wastes a bit and,
  more importantly, changes the wraparound point.

## 15. Possible Improvements

* Add a duty-cycle-adjustable variant (unequal high/low counts) for
  applications needing a non-50% derived clock.

## 16. What This Program Teaches

* The straightforward toggle-on-terminal-count technique for even clock
  division with guaranteed 50% duty.

## 17. Industry Relevance

Clock dividers are used throughout real designs to derive slower clock
domains from a single fast reference (though real ASIC/FPGA designs
increasingly prefer clock-enables on the fast clock, program 116, over
literal derived clocks, to avoid clock-tree and timing-closure
complexity).

## 18. How to Run

```bash
python3 scripts/run.py 114            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/114-clock-divider-even && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/clock_divider_even.v tb/tb_clock_divider_even.v
vvp build/sim.vvp +vcd
```
