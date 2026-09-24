# 118 — Moore Sequence Detector

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Elementary | `seq_detector_moore` | `src/seq_detector_moore.v` | `tb/tb_seq_detector_moore.v` |

## 1. Objective

Build a classic Moore-type finite state machine that scans a serial bit
stream and flags every (possibly overlapping) occurrence of the pattern
`1011`.

## 2. What the Design Does

Each clock cycle, `seq_detector_moore` consumes one bit on `in_bit` and
asserts `detected` for the entire cycle following the state that
completes a `1011` match. Because the FSM tracks the *longest matched
prefix* rather than resetting to "no match" after every detection,
overlapping occurrences are found: the stream `1011011011` is flagged
three times (after bits 4, 7 and 10), reusing the trailing `1` of one
match as the start of the next.

## 3. Why It Is Useful

Sequence detection over a serial bit stream is the core building block of
protocol framing (start-bit / preamble detection), simple pattern-based
triggers in test equipment, and an introductory example for the
general technique of encoding "how much of the pattern have I matched so
far" as FSM state.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `in_bit` | input | 1 | serial input bit, sampled on `posedge clk` |
| `detected` | output | 1 | Moore output, high for the cycle after a `1011` match completes |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 3 | current / next FSM state (`S0`..`S4`) |

## 6. Architecture

```
S0 --1--> S1 --0--> S2 --1--> S3 --1--> S4
 ^0        |1  ^--0--'         |0  ^-----'   (S4 --0--> S2, S4 --1--> S1)
 '---------'                   '---'
```
State meaning = longest suffix of the input seen so far that is also a
prefix of `1011`: `S0`="", `S1`="1", `S2`="10", `S3`="101", `S4`="1011".
`detected = (state == S4)` (Moore: output is a pure function of state).

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Classic two-`always`-block FSM: a clocked state register plus a
  combinational next-state block, kept separate per the repository's
  house style.
* Moore-style output: a third combinational block driven only by
  `state`, contrasted directly with program 119's Mealy version.
* Overlap-preserving transition design: instead of returning to `S0`
  after a match, `S4`'s transitions are derived the same way as every
  other state's — from the longest matching suffix — so a new match can
  begin using bits already consumed by the previous one.

## 9. Source Code Explanation

```verilog
S3: state_next = in_bit ? S4 : S2;
S4: state_next = in_bit ? S1 : S2;
```
`S3` ("101" matched) advances to the full-match state `S4` on a `1`, or
falls back to `S2` ("10") on a `0` (the trailing "10" of "1010" is still
a valid partial match). `S4` does **not** reset to `S0`: its outgoing
bits are computed exactly as for any other state — after matching
"1011", the last three bits are "011", so a further `1` yields "0111",
whose longest pattern-prefix suffix is "1" (state `S1`), and a further
`0` yields "0110", whose longest prefix suffix is "10" (state `S2`).
This is what makes overlapping detection work without special-casing.

```verilog
always @(*) begin
    detected = (state == S4);
end
```
Pure combinational function of `state` only — the defining property of a
Moore machine, and why `detected` stays high for a whole clock cycle
rather than pulsing mid-cycle the way a Mealy output driven by `in_bit`
directly could.

## 10. Testbench Explanation

`tb_seq_detector_moore` keeps a growing history register of every bit
fed since the last reset. After each `feed_bit`, it checks `detected`
against an independent reference computed purely from the last 4 bits of
that history (`1,0,1,1`) — not from any knowledge of the DUT's state
encoding. Test cases: an isolated single match, a back-to-back
overlapping triple match (`1011011011`), a partial match interrupted by
reset (proving the asynchronous reset clears in-progress state), all-0
and all-1 streams (never match), and four pseudo-random 60-bit streams
(fixed LCG seed, reproducible) each starting from a fresh reset.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | isolated match | `0010110...` | `detected` pulses once |
| 2 | overlapping matches | `1011011011` | `detected` pulses 3 times |
| 3 | reset clears partial match | `101` then reset then `1` | no false detect from stale state |
| 4 | never matches | all-0 / all-1, 20 bits each | `detected` stays low |
| 5 | random streams | 4×60 pseudo-random bits | matches reference model exactly |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 118` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_seq_detector_moore` — **PASS**

```text
TEST PASSED: 310 checks
tb/tb_seq_detector_moore.v:108: $finish called at 3206000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 29 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* 5 states fit in 3 bits with room to spare; binary encoding is used here
  deliberately so program 120 can contrast it against Gray and one-hot
  encodings of the *same* FSM.
* The output is combinational on `state`, not registered, so `detected`
  changes as soon as `state` updates (same edge), not one cycle later.

## 14. Common Mistakes

* Returning `S4` to `S0` on any input instead of computing its
  transitions from the longest matching suffix — this silently breaks
  overlap detection (`1011011011` would only be flagged once).
* Forgetting the `default` in the next-state `case`, which for a
  binary-encoded FSM with unused state codes can synthesize an
  unintended latch if a state value outside `S0`..`S4` is ever reached.

## 15. Possible Improvements

* Parameterize the target pattern instead of hard-coding `1011`.
* Add a `valid`/`start` handshake so the detector can be paused mid-stream.

## 16. What This Program Teaches

* Deriving FSM states as "longest matched prefix" for pattern matching.
* The Moore machine discipline: output depends on state alone.
* Designing overlap-correct sequence detectors without special-casing the
  match state.

## 17. Industry Relevance

Preamble/sync-word detectors in communication receivers (e.g. finding a
UART start condition, an HDLC flag, or a radio preamble) use exactly this
longest-matched-prefix FSM technique, usually followed by more complex
per-protocol state machines once the sync pattern is found.

## 18. How to Run

```bash
python3 scripts/run.py 118            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/118-moore-sequence-detector && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/seq_detector_moore.v tb/tb_seq_detector_moore.v
vvp build/sim.vvp +vcd
```
