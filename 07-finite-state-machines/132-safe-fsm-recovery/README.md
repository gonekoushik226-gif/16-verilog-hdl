# 132 — Safe FSM Recovery

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Advanced | `safe_fsm` | `src/safe_fsm.v` | `tb/tb_safe_fsm.v` |

## 1. Objective

Make illegal-state detection and recovery — normally an incidental
`default` branch in every FSM this repository has built so far — the
explicit, directly-tested subject of a program: a one-hot FSM that
reports corruption combinationally and recovers within exactly one
clock cycle, verified by forcing *every* possible illegal state value.

## 2. What the Design Does

`safe_fsm` is a 4-state one-hot sequencer (`S_A -> S_B -> S_C -> S_D ->
S_A` on `advance`). Its next-state `case` recognizes only the 4 legal
one-hot patterns; the other 12 possible 4-bit values fall into
`default`, which forces the next state to `S_A` regardless of
`advance`. `error` reports, combinationally, whenever the *current*
state is not one of the 4 legal patterns — valid the same cycle the
corruption appears, before the recovering clock edge even occurs.

## 3. Why It Is Useful

Every FSM in this repository already has a `default` case per CLAUDE.md
§4's house style — but that default's correctness is rarely tested
directly, because normal operation never reaches it. Real safety-
relevant hardware (and radiation-hardened designs, where single-event
upsets can flip a state bit) must be able to prove that recovery, not
just assume the `default` branch is dead code that happens to look
reasonable.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `advance` | input | 1 | advance to the next state in the normal cycle |
| `state_out` | output | 4 | current one-hot state register (observability) |
| `error` | output | 1 | combinational: current state is not a legal one-hot pattern |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 4 | one-hot state register / next-state |

## 6. Architecture

```
Legal cycle:  S_A --advance--> S_B --advance--> S_C --advance--> S_D --advance--> S_A ...
Any of the other 12 possible 4-bit values --> (default) --> S_A, unconditionally, next cycle
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* One-hot state encoding where "legal" has a precise, checkable
  definition (exactly one of the 4 defined constants) distinct from
  "any 4-bit value," making illegal-state detection a simple equality
  check rather than a population count.
* `default` in the next-state `case` used as the *primary safety
  mechanism* of the whole program, not an incidental completeness
  requirement — and tested as such.
* Hierarchical `force`/`release` (the same technique already used in
  this repository's `110-ring-counter` testbench) to directly corrupt
  internal, non-port state from the testbench — the only way to reach
  states the RTL itself can never produce through normal operation.

## 9. Source Code Explanation

```verilog
always @(*) begin
    state_next = S_A;   // default/safe recovery target
    case (state)
        S_A: state_next = advance ? S_B : S_A;
        ...
        default: state_next = S_A;   // illegal (non-one-hot) state: recover
    endcase
end
```
The top-of-block default assignment (`state_next = S_A`) and the
`case`'s own `default` arm say the same thing twice — deliberately: the
top assignment is the house-style latch-prevention default (CLAUDE.md
§4), and the explicit `default:` arm documents that this is not merely
defensive boilerplate but the actual recovery mechanism this program is
about.

```verilog
assign error = !(state == S_A || state == S_B || state == S_C || state == S_D);
```
A direct membership test against the 4 legal patterns — simpler and
clearer than a population-count/parity check for a state space this
small, and it reads as exactly what "illegal" means for this design.

## 10. Testbench Explanation

`tb_safe_fsm` first confirms normal cyclic operation over 8 `advance`
pulses. It then **exhaustively** forces `dut.state` (via hierarchical
`force`/`release`, matching program 110's established convention) to
**all 16** possible 4-bit values — the 4 legal ones and all 12 illegal
ones — checking `error` immediately (combinationally) for every value,
then releasing and checking the state one clock cycle later: a legal
starting value should self-loop (since `advance` is held low for this
sweep), and every illegal value should land on `S_A` with `error`
cleared. A second, smaller sweep repeats the illegal-value injection
with `advance` held *high*, confirming recovery is unconditional and
does not accidentally respect `advance`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | normal cycle | 8 `advance` pulses | `S_A→B→C→D→A→...` exactly |
| 2 | exhaustive legal check | force each of 4 legal states | `error=0`, self-loops with `advance=0` |
| 3 | exhaustive illegal check | force each of the 12 illegal states | `error=1` immediately, recovers to `S_A` next cycle |
| 4 | unconditional recovery | illegal states forced with `advance=1` | still recovers to `S_A` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 132` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_safe_fsm` — **PASS**

```text
TEST PASSED: 53 checks
tb/tb_safe_fsm.v:137: $finish called at 376000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 27 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Recovery always lands on `S_A` specifically (not "any legal state") —
  a deterministic, single well-defined safe state, which is what makes
  the recovery testable as a precise assertion rather than a vague
  "eventually becomes legal again" property.
* `error` is combinational, not registered, so external monitoring logic
  sees the corruption in the very same cycle it occurs, one full cycle
  before the FSM itself has recovered.

## 14. Common Mistakes

* Testing only a couple of illegal state values ("looks handled") rather
  than exhaustively — with a small one-hot state space like this one
  (16 total patterns), exhaustive coverage is cheap and removes any
  doubt about the other combinations.
* Forcing a hierarchical signal with a raw slice expression
  (`force dut.state = v[3:0];`) works functionally in Icarus Verilog but
  triggers a compiler advisory ("procedural continuous assignments are
  not yet fully supported... RHS... evaluated once") because `force`'s
  right-hand side is expected to be a plain variable reference; assigning
  the value to a dedicated `reg` first (`force_val = v[3:0]; force
  dut.state = force_val;`), matching program 110's convention, avoids the
  advisory entirely.

## 15. Possible Improvements

* Add a `recovery_count` output tallying how many times recovery has
  triggered, for a real fault-monitoring use case.
* Extend to a wider one-hot state space and parameterize `error`'s
  definition via a population-count check instead of explicit membership.

## 16. What This Program Teaches

* Treating illegal-state recovery as a first-class, directly tested
  requirement rather than incidental `default`-case boilerplate.
* Exhaustively testing a small state space using hierarchical
  `force`/`release` to reach states normal stimulus cannot produce.

## 17. Industry Relevance

Illegal-state detection and recovery is a real requirement in
safety-critical and radiation-hardened digital design (automotive,
aerospace, industrial safety systems), often mandated by functional
safety standards (e.g., ISO 26262) that specifically require
demonstrating an FSM's behavior under corrupted/unreachable state
values, not just its normal operation.

## 18. How to Run

```bash
python3 scripts/run.py 132            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/132-safe-fsm-recovery && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/safe_fsm.v tb/tb_safe_fsm.v
vvp build/sim.vvp +vcd
```
