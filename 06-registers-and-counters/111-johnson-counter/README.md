# 111 — Johnson Counter (Twisted Ring)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `johnson_counter` | `src/johnson_counter.v` | `tb/tb_johnson_counter.v` |

## 1. Objective

Build a "twisted ring" counter — a small change to program 110's ring
counter (invert the feedback bit) that both self-starts naturally from
plain reset and doubles the useful state count from `WIDTH` to
`2*WIDTH`.

## 2. What the Design Does

`johnson_counter` shifts left every enabled cycle, feeding the
*inverted* MSB back into the LSB. Starting from `0000`, it visits
`0001, 0011, 0111, 1111, 1110, 1100, 1000` before returning to `0000` —
8 distinct states for a 4-bit register. `decoded` is a one-hot signal
naming which of those `2*WIDTH` states `q` currently holds.

## 3. Why It Is Useful

A Johnson counter gives `2*WIDTH` usable states from only `WIDTH`
flip-flops (twice a plain binary counter's state count per bit of
storage) and — unlike program 110's ring counter — needs no special
self-correction logic to start cleanly from an all-zero reset. It is a
classic building block for simple timing-sequence generators.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | shift enable |
| `q` | output | `WIDTH` | twisted-ring register state |
| `decoded` | output | `2*WIDTH` | one-hot: which of the 2*WIDTH states `q` holds |

Parameters: `WIDTH` (default 4).

## 5. Internal Signals

None beyond the two outputs themselves.

## 6. Architecture

```
q <= {q[WIDTH-2:0], ~q[WIDTH-1]}     (shift left, INVERTED MSB re-enters at LSB)
```
Worked trace from `0000`: `~q[3]=1` each step while the register is
still filling with 0s, producing `0001,0011,0111,1111` (the "filling"
phase); once full of 1s, `~q[3]=0` each step while draining, producing
`1110,1100,1000,0000` (the "draining" phase) — 8 states total for
`WIDTH=4`.

`decoded[i] = (q == 2^(i+1)-1)` for `i=0..WIDTH-1` names the filling-phase
states; `decoded[WIDTH+i] = (q == ~(2^(i+1)-1))` names the draining-phase
states — together covering all `2*WIDTH` states exactly once, including
the reset state `0000` itself, which is the *last* draining-phase
pattern (`decoded[2*WIDTH-1]`), not `decoded[0]`.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Inverted feedback (`~q[WIDTH-1]`) as the one-line change from program
  110's plain rotation that produces qualitatively different (self-
  starting, double-length) behavior.
* A procedural `for` loop inside a combinational `always` block building
  a one-hot decode from a parameterized number of comparisons.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  q <= {WIDTH{1'b0}};
    else if (en) q <= {q[WIDTH-2:0], ~q[WIDTH-1]};
end
```
See §6 for the decode logic; each loop iteration checks one filling-
phase and one draining-phase pattern against the current `q`.

## 10. Testbench Explanation

`tb_johnson_counter` checks two full 8-state cycles from reset against a
hand-traced sequence, and checks `decoded` is one-hot at exactly the bit
index the DUT's own decode formula assigns to each state — **not** the
order states are visited starting from reset, since the reset state
(`0000`) maps to `decoded[2*WIDTH-1]` (the last draining-phase slot), not
`decoded[0]`. An earlier version of this testbench assumed traversal
order matched decode-index order and failed on every check; it was
fixed by building an explicit `seq_idx[]` mapping from traversal
position to the DUT's actual decode index (documented in the testbench
itself).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | reset state | rst_n=0 | q=0000, decoded[7]=1 |
| 2 | full 8-state cycle, twice | 16 cycles total | q follows the traced sequence exactly |
| 3 | decode correctness | every state | decoded is one-hot at the DUT's own index for that state |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 111` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_johnson_counter` — **PASS**

```text
TEST PASSED: 17 checks
tb/tb_johnson_counter.v:77: $finish called at 166000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 21 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The decode index numbering (filling states get low indices, draining
  states get high indices, with the shared all-zero/all-ones boundary
  states appearing once each) is a natural consequence of writing the
  decode formula as a single parameterized loop — it does not match
  "distance from reset," which is a different, equally valid way one
  might have chosen to number the states. This program documents that
  the natural formula-based numbering was chosen, not renumbered to
  match traversal order.

## 14. Common Mistakes

* Assuming a decode's bit-index numbering matches stimulus/traversal
  order without checking — exactly the bug this program's own testbench
  had during development (see §10).
* Forgetting that reset's all-zero state is itself one of the `2*WIDTH`
  valid states, not a "state zero" outside the cycle — it must appear
  in the decode exactly once, like every other state.

## 15. Possible Improvements

* Renumber `decoded` to match reset/traversal order if that proves more
  convenient for a particular downstream use, with a small offset
  correction in the indexing formula.

## 16. What This Program Teaches

* How a single inverted-feedback change transforms a self-correcting
  ring counter into a naturally-self-starting, double-length twisted
  ring counter.
* The importance of verifying a decode's exact numbering against the
  actual formula, not an assumption about traversal order.

## 17. Industry Relevance

Johnson counters are a classic building block for simple sequential
timing generators and, because only one bit changes per transition (like
Gray code, program 112), for glitch-resistant decoded outputs in
asynchronous or noisy timing contexts.

## 18. How to Run

```bash
python3 scripts/run.py 111            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/111-johnson-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/johnson_counter.v tb/tb_johnson_counter.v
vvp build/sim.vvp +vcd
```
