# 113 — Ripple Counter (Asynchronous)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `ripple_counter` | `src/t_ff.v`, `src/ripple_counter.v` | `tb/tb_ripple_counter.v` |

## 1. Objective

Build a counter the "old" way — each bit toggling from the bit below it,
not from a shared clock — and understand concretely why this repository
defaults to fully synchronous design everywhere else.

## 2. What the Design Does

`ripple_counter` chains `WIDTH` toggle flip-flops (program 091's `t_ff`,
`t` tied permanently high). Bit 0 toggles on the real `clk`; every other
bit toggles on a falling edge of the bit below it. Because each stage's
clock is itself a *derived, delayed* signal rather than the shared
system clock, this is a genuinely **asynchronous** counter — a
deliberate, explicitly-flagged exception to this repository's default
fully-synchronous style (`CLAUDE.md` §4).

## 3. Why It Is Useful

Understanding *why* ripple counters are avoided in real synchronous
designs requires first understanding how they actually work: every bit
beyond the first has its clock-to-output delay stacked on top of every
earlier bit's delay, so a wide ripple counter's *worst-case* count-to-
valid delay grows with its width, not the single flip-flop delay a
synchronous counter (program 104) has regardless of width.

## 4. Interface

**`ripple_counter`**: `clk`, `rst_n` in; `q[WIDTH-1:0]` out. Parameters:
`WIDTH` (default 4).
**`t_ff`**: `clk`, `rst_n` in; `q` out (`t` is not a port here — it is
permanently 1, hardwired into the always block, matching program 091's
"tie t high for a divider" case).

## 5. Internal Signals

None beyond the chained `t_ff` instances' own `q` outputs.

## 6. Architecture

```
clk --[t_ff stage0]-- q[0]
q[0] --(inverted)--[t_ff stage1]-- q[1]
q[1] --(inverted)--[t_ff stage2]-- q[2]
q[2] --(inverted)--[t_ff stage3]-- q[3]
```
Each stage triggers on the **falling** edge of the previous stage's `q`
(`~q[i-1]` as the clock input, so a negedge of `q[i-1]` presents as a
posedge to `t_ff`). This is deliberate, not incidental: see §14 for why
triggering on the *rising* edge of a plain `Q` output instead produces a
**down** counter, a genuine bug this program's own development hit.

## 7. Module Hierarchy and Connections

```
ripple_counter #(.WIDTH(N))
└── stage[0..N-1] : t_ff
      stage[0].clk = clk (the real clock)
      stage[i>0].clk = ~stage[i-1].q
```

## 8. Verilog Concepts Used

* A `generate for` loop with a `generate if` selecting the clock source
  differently for the first stage vs. every later stage.
* A module instance's port connected to an *expression* (`~q[i-1]`)
  rather than a bare signal — Verilog implicitly creates the inverter as
  a continuous assignment feeding that port.

## 9. Source Code Explanation

```verilog
if (i == 0)
    t_ff u (.clk(clk),     .rst_n(rst_n), .q(q[i]));
else
    t_ff u (.clk(~q[i-1]), .rst_n(rst_n), .q(q[i]));
```
Stage 0 toggles on every real clock edge (dividing `clk` by 2). Stage 1
toggles on every falling edge of `q[0]` (dividing `q[0]`'s already-
divided frequency by 2 again), and so on — each stage further divides
the frequency of the stage before it, which is exactly how a binary
counter's bit pattern emerges from a chain of frequency dividers.

## 10. Testbench Explanation

`tb_ripple_counter` samples `q` a full 2 time units after each real clock
edge (extra margin for the ripple chain to settle through all its
cascaded delta-cycle events within the same simulation time step) and
checks the settled value against a standard binary count sequence over
more than one full cycle. Zero-delay simulation cannot show the
*transient* glitching a real ripple counter exhibits while each stage's
propagation delay is still active (see §13) — this testbench verifies
the functionally correct settled sequence.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full cycle + wrap | 20 clock edges (WIDTH=4) | settled q follows 0,1,2,...,15,0,1,... |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 113` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_ripple_counter` — **PASS**

```text
TEST PASSED: 21 checks
tb/tb_ripple_counter.v:57: $finish called at 207000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 11 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* **This is intentionally asynchronous** — every other sequential
  program in this repository uses one shared clock edge for every
  register; this one deliberately does not, specifically to make the
  ripple-delay problem concrete.
* Zero-delay Verilog simulation resolves an entire ripple chain within
  the same simulation time step (via cascaded delta cycles), so this
  testbench can only verify the final *settled* count value, not
  observe the transient glitching a real ripple counter with nonzero
  gate delays would exhibit while the chain is still propagating — that
  physical effect (and the resulting risk of a downstream circuit
  briefly sampling a nonsense intermediate value) is exactly what makes
  ripple counters unsuitable for high-speed or safety-relevant designs.

## 14. Common Mistakes

* **Triggering each cascaded stage on the rising edge of the previous
  stage's plain `Q` output** — this is a classic, easy-to-get-backwards
  fact: it produces a **down** counter, not an up counter. This was
  exactly the bug an earlier version of this program's RTL had (verified
  by its own testbench, which caught the settled sequence counting
  15,14,13,...,1,0,15,... instead of the intended 1,2,3,...,15,0,1,...),
  fixed by triggering on the *falling* edge of each previous stage
  instead (equivalently, the rising edge of its complement).
* Assuming a ripple counter's timing behaves like a synchronous one just
  because the settled values eventually match — the worst-case time
  *until* those values are valid is fundamentally different.

## 15. Possible Improvements

* Add a synchronous counter (program 104) side by side in the testbench
  and compare cumulative worst-case delay conceptually as width scales.

## 16. What This Program Teaches

* How a chain of toggle flip-flops, each clocked by the previous stage,
  produces binary counting — and why the *direction* (up vs. down)
  depends on which edge of which signal drives each stage.
* The concrete reason (delay accumulation) ripple counters are avoided
  in synchronous digital design, in contrast to every other counter in
  this category.

## 17. Industry Relevance

Ripple counters are mostly of historical and educational interest today
(early TTL counter ICs like the 7493 used this structure); essentially
all modern synchronous digital designs use fully-synchronous counters
(program 104) specifically to avoid the delay-accumulation and glitch
risks this program demonstrates.

## 18. How to Run

```bash
python3 scripts/run.py 113            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/113-ripple-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/t_ff.v src/ripple_counter.v tb/tb_ripple_counter.v
vvp build/sim.vvp +vcd
```
