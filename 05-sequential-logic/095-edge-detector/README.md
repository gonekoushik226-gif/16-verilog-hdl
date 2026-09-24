# 095 — Edge Detector

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Elementary | `edge_detector` | `src/edge_detector.v` | `tb/tb_edge_detector.v` |

## 1. Objective

Turn a level signal's transitions into clean, single-cycle pulses —
"this signal just went high," "this signal just went low" — the pattern
behind virtually every button-press or handshake-request detector in
this repository from here on.

## 2. What the Design Does

`edge_detector` registers `sig_in` twice in series (`sig_sync`, then
`sig_prev`) and compares the two registered stages combinationally:
`rising = sig_sync & ~sig_prev`, `falling = ~sig_sync & sig_prev`,
`any_edge = sig_sync ^ sig_prev`. Each pulse is exactly one `clk` cycle
wide.

## 3. Why It Is Useful

Level signals (a button, a request line, a protocol strobe) often need
to trigger an action exactly once per transition, not continuously while
held. Converting a level into a one-cycle pulse is the standard way to
do that safely in synchronous logic.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `sig_in` | input | 1 | the signal to watch |
| `rising` | output | 1 | 1 for one cycle on a 0->1 transition |
| `falling` | output | 1 | 1 for one cycle on a 1->0 transition |
| `any_edge` | output | 1 | 1 for one cycle on either transition |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `sig_sync` | 1 | `sig_in` registered one cycle |
| `sig_prev` | 1 | `sig_sync` registered one more cycle (two cycles behind `sig_in`) |

## 6. Architecture

```
sig_in -[FF]-> sig_sync -[FF]-> sig_prev

rising   = sig_sync & ~sig_prev
falling  = ~sig_sync & sig_prev
any_edge = sig_sync ^ sig_prev
```
Both signals feeding the comparison are registered, so they are stable
for an entire clock period each — the comparison is never racing a value
that is itself still settling from the very same clock edge.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Two chained registers producing a one-cycle-delayed pair, compared
  combinationally — the standard synchronous edge-detection idiom.
* XOR (`^`) as a compact "differs from" comparison for `any_edge`.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sig_sync <= 1'b0;
        sig_prev <= 1'b0;
    end else begin
        sig_sync <= sig_in;
        sig_prev <= sig_sync;
    end
end
assign rising = sig_sync & ~sig_prev;
```
`sig_sync` lags `sig_in` by one cycle; `sig_prev` lags `sig_sync` by one
more. The instant `sig_sync` (the newer of the two) differs from
`sig_prev` (the older) is exactly the cycle after `sig_in` actually
changed — and because both compared signals are registered, that
difference is present for a full, stable clock period, not a
delta-cycle glitch.

## 10. Testbench Explanation

`tb_edge_detector` drives `sig_in` through a 16-bit pattern covering
every kind of transition (rising, falling, held stretches, back-to-back
changes), maintaining its own two-stage shadow model (`ref_sync`,
`ref_prev`) updated the same way as the DUT's internal registers, and
compares all three pulse outputs against that shadow model every cycle.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | rising edges | 0->1 transitions in the pattern | rising=1 for exactly one cycle each |
| 2 | falling edges | 1->0 transitions in the pattern | falling=1 for exactly one cycle each |
| 3 | held levels | repeated 0s or 1s | no pulses |
| 4 | any_edge | every transition | any_edge=1 exactly when rising or falling is |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 095` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_edge_detector` — **PASS**

```text
TEST PASSED: 16 checks
tb/tb_edge_detector.v:63: $finish called at 166000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 5 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* An earlier version of this module used only **one** register
  (comparing the live, unregistered `sig_in` against a single delayed
  copy) instead of two. That design produces a *correct-looking*
  equation but the pulse it generates exists only for a zero-time
  delta-cycle within the very clock edge that is supposed to detect the
  transition — by the time any external logic (or this program's
  testbench, sampling a moment after the edge) observes it, the delayed
  copy has already caught up and the pulse has vanished. This was caught
  directly by the testbench (every expected pulse read back as 0) and
  fixed by adding the second register stage, which is also the more
  standard, correct design (comparing two stable registered values,
  never a live signal against a same-edge register).
* Using two register stages also has the beneficial side effect of
  synchronizing a genuinely asynchronous external `sig_in` (see programs
  226-227 for dedicated synchronizer designs) rather than assuming it is
  already clock-aligned.

## 14. Common Mistakes

* Comparing a live (combinational) signal against a single delayed
  register — looks reasonable on paper but produces only a
  simulation-invisible delta-cycle glitch, not a usable pulse (see §13).
* Forgetting the pulse is exactly one cycle wide — code that expects a
  held pulse (like a level) rather than a strobe will miss it if it
  isn't sampled on the correct cycle.

## 15. Possible Improvements

* Add a proper two-flop synchronizer explicitly for a truly asynchronous
  input, distinguishing "detecting an edge" from "synchronizing an
  async signal" as two composed but separate concerns.

## 16. What This Program Teaches

* The standard registered-compare technique for one-cycle pulse
  generation.
* Why comparing two *registered* values, not a live signal against one
  register, is essential for a stable, observable result — illustrated
  by a genuine bug this program's own development hit and fixed.

## 17. Industry Relevance

Edge detection is everywhere in real RTL: button/switch handling,
protocol strobe detection, interrupt edge sensing, and converting level
status signals into one-shot trigger pulses for state machines.

## 18. How to Run

```bash
python3 scripts/run.py 095            # compile, simulate, synthesize, lint
cd 05-sequential-logic/095-edge-detector && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/edge_detector.v tb/tb_edge_detector.v
vvp build/sim.vvp +vcd
```
