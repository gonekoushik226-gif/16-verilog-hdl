# 089 — D Flip-Flop with Enable

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `dff_en` | `src/dff_en.v` | `tb/tb_dff_en.v` |

## 1. Objective

Add a clock-enable to program 087's D flip-flop and distinguish it
clearly from a synchronous reset (program 088): an enable *holds* the
current value, while a reset *forces* a specific one.

## 2. What the Design Does

`dff_en` samples `d` into `q` on a rising `clk` edge only when `en=1`.
When `en=0`, the clock edge still occurs but has no effect — `q` simply
keeps its previous value.

## 3. Why It Is Useful

Clock-enabled registers are how most real designs gate individual
registers without gating the clock itself (which has its own timing
hazards). Counters, FIFOs, and pipeline stages all commonly use exactly
this pattern instead of stopping their clock.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `en` | input | 1 | clock enable |
| `d` | input | 1 | data input |
| `q` | output | 1 | registered output |

## 5. Internal Signals

None — `q` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  q <= 0
    else if (en) q <= d
    else         q <= q     (implicit: hold)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Priority `if`/`else if` inside a clocked `always` block: reset first,
  then enable, with the implicit final "hold" case needing no explicit
  `else` branch (non-blocking assignment to `q` simply doesn't happen,
  which for a `reg` correctly means "keep the current value" — not a
  latch, since this is inside an edge-triggered block, not `always
  @(*)`).

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)   q <= 1'b0;
    else if (en)  q <= d;
    // else: en=0, hold -- q keeps its value across this edge
end
```
Reset takes priority over enable (checked first), matching real
flip-flop cells where a reset pin typically overrides a clock-enable
pin. When neither condition assigns `q`, its value simply persists
across the clock edge — this is safe (not a latch) specifically because
the assignment is already gated by an edge in the sensitivity list, not
a level.

## 10. Testbench Explanation

`tb_dff_en` alternates `en=1` and `en=0` across successive clock edges
while continuously changing `d`, checking that `q` only updates on the
enabled edges and holds through every disabled one, plus a check that
reset overrides an asserted enable.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | enabled edge | en=1 | q <= d |
| 2 | disabled edge(s) | en=0, d changing | q unchanged |
| 3 | re-enabled edge | en=1 again | q resumes tracking d |
| 4 | reset overrides enable | rst_n=0, en=1 | q forced to 0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 089` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_dff_en` — **PASS**

```text
TEST PASSED: 9 checks
tb/tb_dff_en.v:52: $finish called at 76000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* An enabled flip-flop is functionally equivalent to muxing `d` with the
  flip-flop's own current output ahead of a plain D flip-flop
  (`d_eff = en ? d : q`) — this program writes it directly as a priority
  `if` chain instead, which synthesizes to the same feedback-mux
  structure.

## 14. Common Mistakes

* Gating the clock itself (`clk & en`) instead of using a clock-enable
  input — works in simple simulation but creates real clock-tree timing
  problems in physical hardware, which is exactly why clock-enable
  registers like this one are preferred.
* Swapping the priority of reset and enable — if `en` were checked
  before `rst_n`, an enabled flip-flop with `rst_n=0` might load `d`
  instead of resetting.

## 15. Possible Improvements

* Add a separate synchronous clear input alongside the enable, showing
  three-way priority (reset > clear > enable > hold).

## 16. What This Program Teaches

* The clock-enable pattern as the standard alternative to clock gating.
* Priority ordering between multiple control signals in one always block.

## 17. Industry Relevance

Clock-enabled registers are pervasive in real RTL — anywhere a value
should only update under certain conditions (a valid pulse, a
configuration write, a countdown reaching zero) without stopping the
clock domain's actual clock.

## 18. How to Run

```bash
python3 scripts/run.py 089            # compile, simulate, synthesize, lint
cd 05-sequential-logic/089-d-flip-flop-with-enable && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/dff_en.v tb/tb_dff_en.v
vvp build/sim.vvp +vcd
```
