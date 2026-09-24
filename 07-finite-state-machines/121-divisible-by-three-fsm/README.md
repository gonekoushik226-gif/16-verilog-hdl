# 121 — Divisible-by-Three FSM

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Elementary | `div_by_3_fsm` | `src/div_by_3_fsm.v` | `tb/tb_div_by_3_fsm.v` |

## 1. Objective

Build a 3-state FSM that determines whether a binary number, fed in
serially MSB-first, is divisible by 3 — without ever computing the full
numeric value.

## 2. What the Design Does

`div_by_3_fsm` maintains `remainder = (value read so far) mod 3` as its
entire state, updated one bit per clock. `div_by_3` (and `remainder`)
are valid after every bit, not just at the end of a number — reading a
longer number simply continues the same running remainder.

## 3. Why It Is Useful

This is the standard example of a **remainder-tracking FSM**: a whole
class of "recognize numbers with property P" problems (divisible by N,
same count of 0s and 1s modulo something, etc.) reduce to a small FSM
over the possible remainders instead of needing the full value in a
register. It is also a classic formal-methods / automata-theory teaching
example (a DFA over the alphabet `{0,1}` recognizing multiples of 3).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset (clears remainder to 0, matching value 0) |
| `bit_in` | input | 1 | next bit of the number, MSB first |
| `remainder` | output | 2 | running `(value so far) mod 3` (0, 1, or 2) |
| `div_by_3` | output | 1 | `remainder == 0` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 2 | current / next remainder state (`R0`, `R1`, `R2`) |

## 6. Architecture

```
        0        1                0        1
   .--------.--------.       R0 --0--> R0   R0 --1--> R1
   v        v        |       R1 --1--> R0   R1 --0--> R2
  R0 <--1-- R1 <--0-- R2      R2 --0--> R1   R2 --1--> R2
              ^--1---'
```
Derivation: reading bit `b` after remainder `r` means the new value is
`old_value*2 + b`, so the new remainder is `(2*r + b) mod 3`. Since
`2*0=0`, `2*1=2`, `2*2=4≡1 (mod 3)`, this gives exactly the 6
transitions above.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Deriving a minimal FSM directly from a modular-arithmetic recurrence
  (`(2*r + b) mod 3`) rather than an ad hoc state diagram.
* Both outputs (`remainder`, `div_by_3`) are plain `assign`s of the
  state register — no separate output-decode `always` block is needed
  since the state itself *is* the remainder.

## 9. Source Code Explanation

```verilog
R1: state_next = bit_in ? R0 : R2;   // 1*2+1=3->0, 1*2+0=2
```
Each `case` arm is annotated with the exact arithmetic it implements:
from remainder 1, reading a `1` gives `2*1+1=3`, and `3 mod 3 = 0`, so
the next state is `R0`; reading a `0` gives `2*1+0=2`, so the next state
is `R2`. All six transitions in the module follow the same pattern.

```verilog
assign remainder = state;
assign div_by_3  = (state == R0);
```
Because the 2-bit state register is already encoded as the literal
remainder value (`R0=0, R1=1, R2=2`), `remainder` is a direct wire of
`state` with no decode logic at all.

## 10. Testbench Explanation

`tb_div_by_3_fsm` resets before every test number, then feeds it
serially MSB-first. After *every* bit (not just the last), it
accumulates the true value so far in a plain `integer` and compares
`remainder` and `div_by_3` against `acc % 3` computed independently by
Verilog's `%` operator — checking every intermediate prefix, not only
final results. Coverage: all 256 possible 8-bit values (exhaustive), plus
300 pseudo-random 20-bit values (fixed seed, reproducible) to confirm the
FSM continues working correctly for numbers too large to enumerate
exhaustively.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive 8-bit | every value 0..255 | `remainder`/`div_by_3` match `%3` after every bit |
| 2 | random 20-bit | 300 pseudo-random values | `remainder`/`div_by_3` match `%3` after every bit |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 121` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_div_by_3_fsm` — **PASS**

```text
TEST PASSED: 16096 checks
tb/tb_div_by_3_fsm.v:80: $finish called at 86046000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 10 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Only 3 states are ever needed, regardless of how many bits the input
  number has — a direct consequence of divisibility by 3 depending only
  on the running remainder, not the full value.
* `remainder` and `div_by_3` are valid combinationally from the
  registered state, so they update on the same edge that consumes each
  bit, not one cycle later.

## 14. Common Mistakes

* Trying to accumulate the full binary value in a wide register and
  compute `% 3` combinationally on it — functionally equivalent but
  wastes area/timing that scales with the number's bit width, defeating
  the point of the FSM formulation.
* Getting the `(2*r+b) mod 3` transition table wrong by hand — deriving
  it algebraically (as done in §9) avoids the classic off-by-one mistake
  of confusing `r*2` with `r+2`.

## 15. Possible Improvements

* Parameterize the divisor `N` and generalize the transition table with
  a `for`/`generate` construction (`(2*r+b) mod N` for arbitrary `N`).
* Add a `valid_in`/`done` handshake to mark number boundaries explicitly
  instead of relying on external reset framing.

## 16. What This Program Teaches

* Building an FSM directly from a modular-arithmetic recurrence rather
  than an intuited state diagram.
* Why FSM state count can be independent of input word width for a
  whole class of streaming-recognizer problems.

## 17. Industry Relevance

Remainder/checksum-style streaming FSMs are the same structural idea
behind serial checksum and CRC computation (see program 183/184) — a
small amount of state updated per input symbol, without ever holding the
full message in a register.

## 18. How to Run

```bash
python3 scripts/run.py 121            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/121-divisible-by-three-fsm && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/div_by_3_fsm.v tb/tb_div_by_3_fsm.v
vvp build/sim.vvp +vcd
```
