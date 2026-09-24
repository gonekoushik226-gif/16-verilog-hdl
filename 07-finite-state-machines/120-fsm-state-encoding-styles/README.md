# 120 — FSM State Encoding Styles

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | (3 independent) | `src/fsm_binary.v`, `src/fsm_gray.v`, `src/fsm_onehot.v` | `tb/tb_fsm_encoding.v` |

## 1. Objective

Implement the *same* FSM (the programs 118/119 "1011" Moore detector)
three times with three different state encodings — binary, Gray, and
one-hot — and prove, by lock-step simulation, that the encoding is a
pure implementation choice with zero effect on observable behavior.

## 2. What the Design Does

`fsm_binary`, `fsm_gray` and `fsm_onehot` all implement the identical
5-state "1011" overlapping-match Moore detector from program 118, with
identical port lists (`clk`, `rst_n`, `in_bit`, `detected`) and identical
transition tables. Only the bit pattern assigned to each symbolic state
name (`S0`..`S4`) differs between the three files.

| Style | Width | S0 | S1 | S2 | S3 | S4 |
|---|---|---|---|---|---|---|
| binary | 3 | 000 | 001 | 010 | 011 | 100 |
| gray | 3 | 000 | 001 | 011 | 010 | 110 |
| one-hot | 5 | 00001 | 00010 | 00100 | 01000 | 10000 |

## 3. Why It Is Useful

State encoding is a well-known area/speed/power trade-off in real RTL:
binary minimizes flip-flops, one-hot minimizes and flattens decode logic
(often faster on FPGAs, where LUTs are cheap and flip-flops are
plentiful), and Gray code limits multi-bit simultaneous transitions
(useful for reducing switching noise or for FSMs crossing clock domains
where only the state bits, not a re-encoded value, are synchronized).
Synthesis tools can often re-encode automatically, but understanding the
manual trade-off is foundational.

## 4. Interface

All three modules share the same port list:

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `in_bit` | input | 1 | serial input bit |
| `detected` | output | 1 | Moore output, high the cycle after a `1011` match |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 3 (binary/gray) or 5 (one-hot) | current / next FSM state |

## 6. Architecture

Identical state-transition graph in all three files (see program 118 §6);
only the numeric encoding of each state symbol changes. `fsm_onehot`
additionally replaces the equality-comparator output decode
(`state == S4`) with a single bit test (`state[4]`), which is the direct
benefit of one-hot encoding — decode logic becomes a wire, not a
comparator.

## 7. Module Hierarchy and Connections

Three independent modules, no instances of each other. The testbench
instantiates all three in parallel, driven by the same `clk`/`rst_n`/
`in_bit` signals.

## 8. Verilog Concepts Used

* `localparam` vectors of different widths encoding the same abstract
  state set — demonstrating that state *names* in a `case` statement are
  independent of their underlying bit pattern.
* One-hot's characteristic simplification: `assign detected = state[4]`
  replacing an equality comparison, shown directly against the other two
  files' `(state == S4)`.

## 9. Source Code Explanation

```verilog
// fsm_gray.v
localparam [2:0] S0 = 3'b000, S1 = 3'b001, S2 = 3'b011,
                  S3 = 3'b010, S4 = 3'b110;
```
Standard reflected Gray sequence `gray(n) = n ^ (n>>1)` for `n = 0..4`.
The `case` statement in the next-state block is byte-for-byte identical
to `fsm_binary.v`'s — only these six constant lines differ.

```verilog
// fsm_onehot.v
assign detected = state[4];
```
With one-hot encoding, "is the FSM in state S4" is directly readable off
a single bit of the state register, with no comparator needed — the
concrete payoff of the encoding choice, visible in the Yosys cell count
(see §12).

## 10. Testbench Explanation

`tb_fsm_encoding` instantiates all three encodings side by side and
drives each with the exact same serial stream every cycle. After each
bit, it checks: (a) each encoding's `detected` against an independent
"last 4 bits == 1011" reference, and (b) that all three encodings' outputs
are pairwise equal to each other — a direct, cycle-by-cycle proof that
encoding does not change behavior. Streams: isolated match, overlapping
back-to-back matches, never-match all-0/all-1, and four pseudo-random
60-bit streams.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | isolated match | `0010110...` | all three agree, `detected` pulses once |
| 2 | overlapping matches | `1011011011` | all three agree, 3 pulses |
| 3 | never matches | all-0 / all-1, 20 bits each | all three stay low |
| 4 | random streams | 4×60 pseudo-random bits | all three agree with reference every cycle |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 120` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_fsm_encoding` — **PASS**

```text
TEST PASSED: 1224 checks
tb/tb_fsm_encoding.v:112: $finish called at 3146000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 97 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `fsm_onehot` costs more flip-flops (5 vs. 3) but its output and, in
  larger FSMs, its next-state decode logic tend to be simpler and faster
  — visible directly in the Yosys generic cell counts for the three
  modules in this program's synthesis log.
* Gray encoding here is illustrative only — this FSM's transition graph
  is not a simple linear/ring sequence, so not every real transition is
  single-bit; only the *S0→S1→S2→S3→S4 numbering* is Gray-adjacent by
  construction, documented explicitly rather than overclaimed.

## 14. Common Mistakes

* Assuming an encoding change requires touching the next-state `case`
  logic — it does not; only the `localparam` values change, exactly as
  shown by the byte-identical `case` bodies in all three files here.
* Forgetting that one-hot needs `default` recovery too: an unreachable
  multi-hot or all-zero state must still fall back to `S0` for safety
  (illegal-state recovery is the subject of program 132).

## 15. Possible Improvements

* Add a 4th file using a synthesis-tool `(* fsm_encoding = "..." *)`
  attribute to compare automatic tool re-encoding against these manual
  ones.
* Extend the comparison to resource usage after a real vendor synthesis
  flow (Yosys generic synthesis here is not a target-specific measure).

## 16. What This Program Teaches

* The concrete area/logic trade-offs between binary, Gray, and one-hot
  FSM state encodings.
* That encoding choice is orthogonal to functional correctness — proven
  here by simulation, not just asserted.

## 17. Industry Relevance

Real synthesis tools (and RTL style guides) routinely let designers pick
or override FSM encoding (`(* fsm_encoding = "one_hot" *)` in several
commercial tools); understanding why one-hot is often preferred on
FPGAs while binary is often preferred for area-constrained ASIC flows is
a standard interview and code-review topic.

## 18. How to Run

```bash
python3 scripts/run.py 120            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/120-fsm-state-encoding-styles && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_fsm_encoding.v
vvp build/sim.vvp +vcd
```
