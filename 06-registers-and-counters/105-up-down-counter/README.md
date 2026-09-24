# 105 — Up/Down Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Beginner | `up_down_counter` | `src/up_down_counter.v` | `tb/tb_up_down_counter.v` |

## 1. Objective

Add direction control to program 104's up counter, and see that
unsigned wraparound is symmetric — decrementing past 0 wraps to the
maximum value exactly as cleanly as incrementing past the maximum wraps
to 0.

## 2. What the Design Does

`up_down_counter` adds 1 (when `up=1`) or subtracts 1 (when `up=0`) from
`count` every enabled cycle.

## 3. Why It Is Useful

Bidirectional counters are needed anywhere a count can both grow and
shrink — a FIFO occupancy counter, a position tracker (quadrature
decoding, program 166), or a countdown timer that can also be
adjusted upward.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | count enable |
| `up` | input | 1 | 1 = count up, 0 = count down |
| `count` | output | `WIDTH` | current count |

Parameters: `WIDTH` (default 4).

## 5. Internal Signals

None — `count` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  count <= 0
    else if (en) count <= up ? count+1 : count-1
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A ternary-selected next-value expression (`up ? count+1 :
  count-1`) inside a clocked block — the same conditional-increment
  pattern program 075's `inc_dec` uses combinationally, here applied
  synchronously to build a free-running counter.

## 9. Source Code Explanation

```verilog
else if (en) count <= up ? (count + 1'b1) : (count - 1'b1);
```
`count - 1'b1` at `count=0` wraps to `{WIDTH{1'b1}}` by the same
fixed-width unsigned arithmetic rule that makes `count + 1'b1` wrap at
the top — Verilog's `-` on unsigned regs wraps modulo `2^WIDTH` exactly
like `+`.

## 10. Testbench Explanation

`tb_up_down_counter` counts up past a full wrap (18 cycles at `WIDTH=4`),
then switches direction and counts down past a wrap in the opposite
direction, checked against a software reference counter throughout,
plus a hold check.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | count up, wrap | up=1, 18 cycles | wraps 15->0 partway through |
| 2 | count down, wrap | up=0, 18 cycles | wraps 0->15 partway through |
| 3 | hold | en=0 | count unchanged |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 105` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_up_down_counter` — **PASS**

```text
TEST PASSED: 40 checks
tb/tb_up_down_counter.v:60: $finish called at 396000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* No terminal-count outputs for either direction here — see program 106
  for a loadable counter with a terminal-count flag, which the same
  technique could add for both directions.

## 14. Common Mistakes

* Assuming decrementing past 0 needs special-case wraparound logic —
  unsigned subtraction already wraps correctly, symmetric to increment
  overflow.

## 15. Possible Improvements

* Add a `load` input (program 106) so the counter can be preset before
  counting in either direction.

## 16. What This Program Teaches

* Symmetric unsigned wraparound in both count directions.
* Direction-selected next-state logic as a simple ternary expression.

## 17. Industry Relevance

Bidirectional counters appear throughout real RTL: FIFO read/write
pointer tracking, position counters fed by quadrature encoders, and any
countdown/count-up timer with adjustable direction.

## 18. How to Run

```bash
python3 scripts/run.py 105            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/105-up-down-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/up_down_counter.v tb/tb_up_down_counter.v
vvp build/sim.vvp +vcd
```
