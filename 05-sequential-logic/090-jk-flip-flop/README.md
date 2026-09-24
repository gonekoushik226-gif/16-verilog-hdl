# 090 — JK Flip-Flop

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `jk_ff` | `src/jk_ff.v` | `tb/tb_jk_ff.v` |

## 1. Objective

Add a fourth, well-defined behavior — toggle — to the SR flip-flop's
three cases, resolving the "both asserted" ambiguity that made the SR
latch's S=R=1 forbidden.

## 2. What the Design Does

`jk_ff` is a clocked flip-flop with four cases selected by `{j,k}`:
`00`=hold, `01`=reset, `10`=set, `11`=toggle (`q <= ~q`).

## 3. Why It Is Useful

JK flip-flops give a designer set/reset/hold *and* toggle from one
2-input control, useful directly for counters (T flip-flops, program
091, are just a JK flip-flop with `j` and `k` tied together) and as the
classic textbook example of resolving an SR latch's ambiguous case by
adding state (an edge-triggered sample) rather than more logic.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `j` | input | 1 | set control |
| `k` | input | 1 | reset control |
| `q` | output | 1 | registered output |

## 5. Internal Signals

None — `q` is the only state element.

## 6. Architecture

```
{j,k}  action
00     hold        q <= q
01     reset       q <= 0
10     set         q <= 1
11     toggle      q <= ~q
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* `case` on a concatenated 2-bit selector (`{j,k}`) inside a clocked
  `always` block, the standard way to implement a small state-transition
  table.

## 9. Source Code Explanation

```verilog
case ({j, k})
    2'b00: q <= q;
    2'b01: q <= 1'b0;
    2'b10: q <= 1'b1;
    2'b11: q <= ~q;
endcase
```
Each case corresponds directly to the JK characteristic table; the
`2'b11` (toggle) case is what an SR latch cannot define safely, since a
JK flip-flop only samples once per clock edge, there is no possibility
of oscillation the way there could be for level-sensitive cross-coupled
gates continuously re-evaluating S=R=1.

## 10. Testbench Explanation

`tb_jk_ff` exhaustively drives all 4 `(j,k)` combinations from *both*
possible starting states of `q` (0 and 1, established via a helper
task), confirming the result matches the JK characteristic table in
every case — including that `11` (toggle) genuinely depends on the
starting state, unlike the other three cases.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | hold | j=0,k=0 | q unchanged |
| 2 | reset | j=0,k=1 | q <= 0 |
| 3 | set | j=1,k=0 | q <= 1 |
| 4 | toggle from 0 | j=1,k=1, q=0 | q <= 1 |
| 5 | toggle from 1 | j=1,k=1, q=1 | q <= 0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 090` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_jk_ff` — **PASS**

```text
TEST PASSED: 16 checks
tb/tb_jk_ff.v:73: $finish called at 126000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 8 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely synchronous behavior driven by `case`; no combinational
  feedback loop is needed (unlike program 085's SR latch), since the
  toggle case reads `q` only as a registered value at the clock edge.

## 14. Common Mistakes

* Implementing toggle with combinational feedback (`q = ~q` outside a
  clocked block) instead of as one case of a synchronous `case`
  statement — the latter is what makes toggle well-defined and glitch-free.
* Confusing JK's `11` (toggle) with SR's `11` (forbidden) — they look
  similar syntactically but are fundamentally different because JK is
  edge-sampled exactly once per cycle.

## 15. Possible Improvements

* Derive a T flip-flop (program 091) and other conversions (program 094)
  directly from this JK core as an exercise, alongside their own
  from-scratch implementations.

## 16. What This Program Teaches

* How adding an edge-triggered sample resolves an ambiguity that a
  level-sensitive circuit (the SR latch) cannot.
* The JK characteristic table as a `case`-statement state machine.

## 17. Industry Relevance

JK flip-flops were historically common in TTL logic families (74LS series)
and remain a standard textbook building block for counters and control
logic, even though most modern RTL is written directly in terms of D
flip-flops with explicit next-state logic.

## 18. How to Run

```bash
python3 scripts/run.py 090            # compile, simulate, synthesize, lint
cd 05-sequential-logic/090-jk-flip-flop && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/jk_ff.v tb/tb_jk_ff.v
vvp build/sim.vvp +vcd
```
