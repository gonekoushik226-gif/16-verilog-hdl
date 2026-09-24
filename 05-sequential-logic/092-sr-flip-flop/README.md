# 092 — SR Flip-Flop

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `sr_ff` | `src/sr_ff.v` | `tb/tb_sr_ff.v` |

## 1. Objective

Build the clocked (edge-triggered) counterpart to program 085's SR
latch, and confront the same S=R=1 ambiguity again — clocking alone
does not resolve it the way JK's toggle definition does (program 090).

## 2. What the Design Does

`sr_ff` samples `{s,r}` on each rising `clk` edge: `00`=hold, `01`=reset,
`10`=set. For `11`, this design's documented policy is to treat it as
invalid — `q` holds its previous value (rather than updating to an
arbitrary or don't-care result) and a dedicated `invalid` flag reports
the condition combinationally.

## 3. Why It Is Useful

Being edge-triggered removes SR's *level-sensitive oscillation* risk
(the concern that dominates the SR latch's forbidden state), but it does
not give S=R=1 a meaningful *interpretation* — "set and reset at the
same instant" is still not a well-defined request. This program shows a
concrete, honest way to handle that: report it rather than silently pick
an arbitrary behavior.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `s` | input | 1 | set |
| `r` | input | 1 | reset |
| `q` | output | 1 | registered output |
| `invalid` | output | 1 | combinational `s & r` |

## 5. Internal Signals

None — `q` is the only state element; `invalid` is a direct combinational
function of the inputs.

## 6. Architecture

```
invalid = s & r                     (combinational, always available)

posedge clk or negedge rst_n:
    if (!rst_n)        q <= 0
    else case ({s,r})
        00: q <= q        (hold)
        01: q <= 0         (reset)
        10: q <= 1         (set)
        11: q <= q        (invalid: policy is to hold, not guess)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A combinational `assign` (`invalid`) alongside a clocked `always`
  block in the same module, each updating on its own natural timing
  (immediately vs. at the next edge).
* An explicit design *policy* (hold on invalid input) encoded directly
  in a `case` statement, documented in both the source comment and this
  README rather than left as an implicit assumption.

## 9. Source Code Explanation

```verilog
assign invalid = s & r;
...
case ({s, r})
    2'b00: q <= q;
    2'b01: q <= 1'b0;
    2'b10: q <= 1'b1;
    2'b11: q <= q;      // invalid: policy is to hold, not guess
endcase
```
`invalid` is available the instant `s` and `r` are both 1, independent
of the clock — useful for a caller who wants to detect the condition as
soon as it occurs, not just after the flip-flop has (not) acted on it.

## 10. Testbench Explanation

`tb_sr_ff` exhaustively drives all 4 `(s,r)` combinations from both
starting states of `q`, checking both the registered `q` after each
clock edge and the combinational `invalid` flag, including immediately
after `s`/`r` change (before any clock edge) to confirm it truly is
combinational.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | hold | s=0,r=0 | q unchanged, invalid=0 |
| 2 | reset | s=0,r=1 | q <= 0, invalid=0 |
| 3 | set | s=1,r=0 | q <= 1, invalid=0 |
| 4 | invalid from q=0 | s=1,r=1 | q holds at 0, invalid=1 |
| 5 | invalid from q=1 | s=1,r=1 | q holds at 1, invalid=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 092` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_sr_ff` — **PASS**

```text
TEST PASSED: 20 checks
tb/tb_sr_ff.v:77: $finish called at 126000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 4 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* "Hold on invalid" is a design choice, not the only reasonable one — a
  different design might instead prioritize `r` (reset-dominant) or `s`
  (set-dominant); this program's choice is documented explicitly rather
  than left implicit, exactly because there is no universally "correct"
  answer.

## 14. Common Mistakes

* Assuming clocking alone resolves SR's ambiguity — it changes *when*
  the ambiguous input is sampled, not *what it means*.
* Silently picking an arbitrary result for `s=r=1` instead of either
  documenting a clear policy (as here) or flagging the condition for the
  caller to handle.
* In the testbench itself: reading a combinational signal (`invalid`)
  immediately after changing one of its inputs in the same zero-delay
  simulation step can race the continuous assignment's update — this
  program's testbench originally left `s`/`r` uninitialized before its
  first check (reading `x`) and, separately, changed `s`/`r` and
  immediately called `@(posedge clk)` in the same time step, racing
  against the flip-flop's own edge-triggered sampling of those same
  signals. Both were fixed by adding a small explicit settling delay
  (`#1`) after every `s`/`r` change before either checking or waiting on
  the next clock edge.

## 15. Possible Improvements

* Add a `program.conf`-selectable reset-dominant or set-dominant policy
  variant, contrasting with the hold policy implemented here.

## 16. What This Program Teaches

* That resolving an ambiguous input combination is a genuine design
  decision requiring an explicit, documented policy — not something
  "clocking" or "more logic" automatically fixes.
* Exposing a combinational status flag alongside registered state.

## 17. Industry Relevance

Real control logic frequently needs to detect and report invalid or
unexpected input combinations rather than silently produce undefined
behavior — the same principle behind parity/protocol error flags
elsewhere in this repository (e.g. program 048's parity checker, program
176's UART framing-error detection).

## 18. How to Run

```bash
python3 scripts/run.py 092            # compile, simulate, synthesize, lint
cd 05-sequential-logic/092-sr-flip-flop && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/sr_ff.v tb/tb_sr_ff.v
vvp build/sim.vvp +vcd
```
