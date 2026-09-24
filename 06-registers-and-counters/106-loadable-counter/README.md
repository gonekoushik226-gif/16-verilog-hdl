# 106 — Loadable Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `loadable_counter` | `src/loadable_counter.v` | `tb/tb_loadable_counter.v` |

## 1. Objective

Add a presettable start value and a terminal-count status flag to
program 104's up counter — the building block program 109's cascaded
BCD counter and many timer designs use to chain or trigger from.

## 2. What the Design Does

`loadable_counter` counts up when `en=1`, can be preset to any value via
`load` (which takes priority over counting), and asserts `tc` (terminal
count) whenever `count` is at its maximum representable value.

## 3. Why It Is Useful

A plain free-running counter cannot start from anywhere but 0 after
reset, or signal when it is about to wrap — both are needed constantly:
starting a countdown from a configured value, or triggering a reload/
cascade exactly when a counter is about to roll over (see program 109).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `load` | input | 1 | preset `count` to `load_val` this cycle |
| `en` | input | 1 | count enable (ignored while `load=1`) |
| `load_val` | input | `WIDTH` | value to preset |
| `count` | output | `WIDTH` | current count |
| `tc` | output | 1 | 1 when `count` is at its maximum value |

Parameters: `WIDTH` (default 4).

## 5. Internal Signals

None — `count` is the only state element; `tc` is a direct combinational
function of it.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)    count <= 0
    else if (load) count <= load_val
    else if (en)   count <= count + 1

tc = (count == max value)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Priority `if`/`else if` (load beats count), the same pattern as
  program 101's PISO load/shift priority.
* A combinational status flag (`tc`) derived from registered state, the
  same pattern as program 092's `invalid` flag.

## 9. Source Code Explanation

```verilog
assign tc = (count == {WIDTH{1'b1}});
```
`{WIDTH{1'b1}}` is the width-generic maximum value — comparing directly
against it (rather than a hardcoded constant) keeps `tc` correct
regardless of `WIDTH`.

## 10. Testbench Explanation

`tb_loadable_counter` loads a value near the top of the range, counts up
to confirm `tc` asserts exactly at the maximum and clears on wraparound,
then checks `load` overriding a simultaneously-asserted `en`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | load | load=1, load_val=13 | count <= 13 |
| 2 | count to terminal | en=1, counting from 13 | tc=1 exactly at count=15 |
| 3 | wraparound | one more count past tc | count=0, tc=0 |
| 4 | load overrides enable | load=1, en=1 simultaneously | count <= load_val, not count+1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 106` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_loadable_counter` — **PASS**

```text
TEST PASSED: 7 checks
tb/tb_loadable_counter.v:60: $finish called at 66000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `tc` is combinational, so it is visible the entire cycle `count` sits
  at its maximum value (not just a single delta-cycle pulse) — this is
  what makes it safe to use directly as another module's enable in a
  synchronous cascade (program 109 uses this exact BCD-digit pattern).

## 14. Common Mistakes

* Registering `tc` instead of leaving it combinational — would delay it
  by a cycle relative to the `count` value it describes, breaking a
  same-cycle cascade.
* Letting `en` override `load` — should always be the other way around,
  matching how most real counter ICs prioritize a preset input.

## 15. Possible Improvements

* Add a down-counting mode with its own terminal-count-at-zero flag.

## 16. What This Program Teaches

* Presettable counters and combinational terminal-count flags as the
  standard mechanism for cascading or triggering from a counter.

## 17. Industry Relevance

Loadable counters with terminal-count outputs are standard in real
timer/counter peripherals (e.g. classic 8253/8254-style programmable
interval timers) and are exactly what enables clean multi-digit or
multi-stage counter cascades.

## 18. How to Run

```bash
python3 scripts/run.py 106            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/106-loadable-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/loadable_counter.v tb/tb_loadable_counter.v
vvp build/sim.vvp +vcd
```
