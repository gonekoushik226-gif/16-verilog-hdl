# 104 — Binary Up Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Beginner | `up_counter` | `src/up_counter.v` | `tb/tb_up_counter.v` |

## 1. Objective

Build the simplest possible counter: an enabled register that adds 1 to
itself every cycle, wrapping naturally when it overflows.

## 2. What the Design Does

`up_counter` increments `count` by 1 every cycle that `en=1`, wrapping
from all-ones back to 0 with no special-case logic — unsigned addition
already does the right thing.

## 3. Why It Is Useful

Counters are everywhere: timers, address generators, loop indices,
sequence generators. This is the base case every other counter in this
category (down, loadable, modulo-N, BCD) specializes.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | count enable |
| `count` | output | `WIDTH` | current count |

Parameters: `WIDTH` (default 4).

## 5. Internal Signals

None — `count` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  count <= 0
    else if (en) count <= count + 1
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Unsigned overflow as free wraparound — `count + 1'b1` on a `WIDTH`-bit
  reg automatically wraps to 0 with no explicit modulus logic.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  count <= {WIDTH{1'b0}};
    else if (en) count <= count + 1'b1;
end
```
Adding `1'b1` to a `WIDTH`-bit reg holding its maximum value
(`{WIDTH{1'b1}}`) produces `{WIDTH{1'b0}}` by ordinary fixed-width
unsigned arithmetic — Verilog silently drops the carry out of the top
bit, which is exactly the wraparound behavior wanted here.

## 10. Testbench Explanation

`tb_up_counter` runs a full count cycle (`2^WIDTH` values) plus 4 more
to confirm the wrap back to 0, then checks hold behavior with `en=0`,
comparing against a software reference counter throughout.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full cycle + wrap | en=1 for 20 cycles (WIDTH=4) | counts 1..15, wraps to 0, continues |
| 2 | hold | en=0 | count unchanged |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 104` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_up_counter` — **PASS**

```text
TEST PASSED: 25 checks
tb/tb_up_counter.v:61: $finish called at 246000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 10 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* No terminal-count output here (see program 106's loadable counter for
  that) — this program is deliberately the minimal case.

## 14. Common Mistakes

* Adding explicit wraparound logic (`if (count == MAX) count <= 0`)
  when plain unsigned overflow already provides it for a power-of-two
  range — unnecessary here, though genuinely needed for a non-power-of-
  two modulus (program 107).

## 15. Possible Improvements

* Add direction control (program 105) or a loadable preset value
  (program 106).

## 16. What This Program Teaches

* The minimal counter pattern and why unsigned wraparound is "free."

## 17. Industry Relevance

Free-running up counters are the simplest timer/sequencer building
block in real RTL, used directly wherever a repeating count (a time
base, an address sequence, a simple event counter) is needed.

## 18. How to Run

```bash
python3 scripts/run.py 104            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/104-binary-up-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/up_counter.v tb/tb_up_counter.v
vvp build/sim.vvp +vcd
```
