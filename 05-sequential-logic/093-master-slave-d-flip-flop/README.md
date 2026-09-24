# 093 — Master-Slave D Flip-Flop

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Elementary | `ms_dff` | `src/d_latch.v`, `src/ms_dff.v` | `tb/tb_ms_dff.v` |

## 1. Objective

Show that edge-triggered behavior is not a primitive Verilog concept but
something that can itself be *built* from two purely level-sensitive
latches — closing the loop from program 085's cross-coupled gates
through program 086's latch to program 087's `posedge`-based flip-flop.

## 2. What the Design Does

`ms_dff` chains two `d_latch` instances: the "master" is transparent
while `clk=0` and the "slave" is transparent while `clk=1` — never both
at once. Data can therefore only flow all the way from `d` to `q` at the
instant `clk` transitions from 0 to 1, which is exactly what makes the
pair behave as a positive-edge-triggered flip-flop, with no `posedge` or
`negedge` written anywhere in either latch.

## 3. Why It Is Useful

This is the classical way edge-triggered flip-flops are actually built
from transistors in real silicon (as two back-to-back latches, often
called "master-slave" or, in a related transmission-gate-based form,
part of a "pulse-triggered" or "edge-triggered latch pair"). Seeing it
built explicitly in Verilog — and verified against a plain behavioral
`posedge` model — makes concrete what `always @(posedge clk)` actually
abstracts over.

## 4. Interface

**`ms_dff`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `d` | input | 1 | data input |
| `q` | output | 1 | edge-triggered output |

**`d_latch`**: same as program 086 (`d`, `en` in; `q` out).

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `master_q` | the master latch's output, feeding the slave's data input |

## 6. Architecture

```
d --[master: d_latch, en=~clk]--> master_q --[slave: d_latch, en=clk]--> q

clk=0: master transparent (master_q follows d), slave frozen (q holds)
clk=1: master frozen (master_q holds), slave transparent (q follows master_q)
```
Because the master is only transparent while the slave is frozen and
vice versa, a change in `d` can propagate all the way to `q` only once
per `clk` cycle — right as `clk` rises, the master's last-held value
(captured the instant before the edge) flows through the now-transparent
slave.

## 7. Module Hierarchy and Connections

```
ms_dff
├── master : d_latch (d,        en=~clk) -> master_q
└── slave  : d_latch (master_q, en=clk)  -> q
```

## 8. Verilog Concepts Used

* Composing two instances of an already-verified module (program 086's
  `d_latch`) to build qualitatively different (edge- vs. level-sensitive)
  behavior — reuse at the level of *behavior*, not just code.
* `ALLOW_LATCH=yes` in `program.conf`, since both internal latches are
  intentional (this program's entire point), even though the module as
  a *whole* behaves as an edge-triggered flip-flop from the outside.

## 9. Source Code Explanation

```verilog
d_latch master (.d(d),        .en(~clk), .q(master_q));
d_latch slave  (.d(master_q), .en(clk),  .q(q));
```
The only wiring decision that matters is the complementary enable
(`~clk` for the master, `clk` for the slave) — everything else is
exactly program 086's `d_latch`, unmodified.

## 10. Testbench Explanation

`tb_ms_dff` maintains a plain behavioral `always @(posedge clk) ref_q <=
d;` reference alongside the DUT, comparing them after every stimulus.
It specifically drives `d` *between* edges in both the `clk=0` phase
(master transparent, checking the slave — and therefore `q` — stays
frozen) and the `clk=1` phase (slave transparent, checking the master
being frozen prevents any effect), then finishes with 10 random-`d`
clock cycles for broader confidence.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | normal edge sampling | d set before each posedge | q matches behavioral reference |
| 2 | d changes while clk=0 | master transparent phase | q (via frozen slave) does not change |
| 3 | d changes while clk=1 | slave transparent phase | q does not change (master is frozen) |
| 4 | random | 10 random d values, one per cycle | q matches behavioral reference every time |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 093` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_ms_dff` — **PASS**

```text
TEST PASSED: 19 checks
tb/tb_ms_dff.v:67: $finish called at 146000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 3 cells (1 intentional latch(es))
Lint (Verilator 5.020 `--lint-only`): warnings — LATCH
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* No reset is included, matching the catalog's minimal scope for this
  program — `q`'s power-up value is whatever the underlying latches'
  power-up value happens to be, same as `d_latch` alone (program 086).
* This construction only works because the two latches' enables are
  exact complements of each other; any overlap where both are
  simultaneously transparent would let data race straight through both
  latches in one `clk` phase, destroying the edge-triggered property.

## 14. Common Mistakes

* Using the *same* enable polarity for both latches (e.g. `en=clk` for
  both) — this makes both transparent and frozen at the same time,
  collapsing the pair into something that behaves like a single latch,
  not an edge-triggered flip-flop.
* Assuming the master-slave pair reacts the instant `d` changes — it
  only ever updates `q` at the `clk` rising edge, exactly like program
  087's behavioral flip-flop, which is the entire point being verified.

## 15. Possible Improvements

* Add an asynchronous reset by extending `d_latch` with a clear input,
  then propagating it through both stages.

## 16. What This Program Teaches

* That "edge-triggered" is an emergent property of two complementary
  level-sensitive latches, not a separate primitive concept.
* Cross-checking a structural implementation against an independent
  behavioral reference model within the same testbench.

## 17. Industry Relevance

Master-slave (and related transmission-gate-based edge-triggered latch)
constructions are literally how standard-cell flip-flops are built at
the transistor level in real ASIC libraries.

## 18. How to Run

```bash
python3 scripts/run.py 093            # compile, simulate, synthesize, lint
cd 05-sequential-logic/093-master-slave-d-flip-flop && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/d_latch.v src/ms_dff.v tb/tb_ms_dff.v
vvp build/sim.vvp +vcd
```
