# 091 — T Flip-Flop

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `t_ff` | `src/t_ff.v` | `tb/tb_t_ff.v` |

## 1. Objective

Reduce a flip-flop's control to a single toggle bit — the special case
of a JK flip-flop with `j` and `k` tied together — and see how tying
`t=1` permanently produces the simplest possible counter: a
divide-by-2.

## 2. What the Design Does

`t_ff` holds `q` when `t=0` and inverts it every clock edge when `t=1`.

## 3. Why It Is Useful

Tying `t` permanently high turns this into a clock/frequency divider —
every rising edge of `clk` produces one full toggle, so `q` itself is a
clean 50%-duty square wave at exactly half `clk`'s frequency, the
building block behind ripple counters (program 113).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `t` | input | 1 | toggle enable |
| `q` | output | 1 | registered output |

## 5. Internal Signals

None — `q` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  q <= 0
    else if (t)  q <= ~q
    else         q <= q     (implicit hold)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Conditional toggle (`q <= ~q`) inside a clocked `always` block — the
  degenerate case of program 090's JK flip-flop with `j` and `k` always
  equal.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= 1'b0;
    else if (t) q <= ~q;
end
```
Identical shape to program 089's enabled D flip-flop, but the "load"
value is `~q` (the flip-flop's own inverted current output) rather than
an external data input.

## 10. Testbench Explanation

`tb_t_ff` checks hold behavior over several clock edges with `t=0`, then
sets `t=1` and checks a clean alternating `1,0,1,0,...` pattern over 8
edges (confirming the divide-by-2 property), then returns to hold and
finally checks reset overriding an in-progress toggle.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | hold | t=0 | q unchanged across several edges |
| 2 | toggle | t=1, 8 edges | clean alternating pattern (divide-by-2) |
| 3 | hold again | t=0 | q unchanged at whatever value it reached |
| 4 | reset mid-toggle | rst_n=0 while t=1 | q forced to 0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 091` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_t_ff` — **PASS**

```text
TEST PASSED: 14 checks
tb/tb_t_ff.v:60: $finish called at 137000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 2 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* As a frequency divider, `t_ff` with `t` tied high produces an output
  whose edges are only as clean as `clk`'s — no additional jitter is
  introduced by the toggle logic itself.

## 14. Common Mistakes

* Expecting `t=1` to set a specific value — it toggles *relative to the
  current state*, so the resulting value after N toggles depends on
  where `q` started, not just on `t`.

## 15. Possible Improvements

* Chain several T flip-flops (each driven by the previous stage's `q`)
  to build a ripple counter, previewing program 113.

## 16. What This Program Teaches

* The toggle flip-flop as JK's degenerate single-input case.
* Frequency division as a direct consequence of toggle-every-edge
  behavior.

## 17. Industry Relevance

Toggle flip-flops (or their JK/D equivalent) are the core building block
of ripple counters and simple clock dividers, still used today in
contexts where a fully synchronous counter's extra logic isn't needed.

## 18. How to Run

```bash
python3 scripts/run.py 091            # compile, simulate, synthesize, lint
cd 05-sequential-logic/091-t-flip-flop && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/t_ff.v tb/tb_t_ff.v
vvp build/sim.vvp +vcd
```
