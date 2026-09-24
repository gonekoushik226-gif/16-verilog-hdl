# 053 — One-Hot to Binary Converter (OR-Tree)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | `onehot_to_bin` | `src/onehot_to_bin.v` | `tb/tb_onehot_to_bin.v` |

## 1. Objective

Implement a width-generic one-hot-to-binary converter using an OR-tree
construction instead of an enumerated `case` table (as `encoder8to3` in
category 02 did), and generate an explicit validity flag from a population
count rather than an implicit `default` arm.

## 2. What the Design Does

`onehot_to_bin` converts a `WIDTH`-bit one-hot input into the binary index
of its set bit. For every bit position `i` that is set in `onehot`, its
index `i` is OR-ed into the accumulating `bin` output; for a genuine
one-hot input only one bit is set, so only one term contributes and `bin`
comes out exactly right. `valid` is computed independently by counting how
many bits are actually set (`ones`) and asserting `valid = (ones == 1)`.

## 3. Why It Is Useful

One-hot signals are common as FSM state encodings, arbiter grant vectors,
and decoder outputs; converting them back to a compact binary index (for a
counter, a mux select line, or a log message) is a frequent companion
operation. The OR-tree technique generalizes cleanly to any width via a
`for` loop, unlike an enumerated `case` table which would need one line per
valid code.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `onehot` | input | `WIDTH` | one-hot (or possibly malformed) input code |
| `bin` | output | `$clog2(WIDTH)` | binary index of the set bit, valid only when `valid = 1` |
| `valid` | output | 1 | 1 only when exactly one bit of `onehot` is set |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | width of the one-hot input |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `i` | (loop var) | scans every bit position of `onehot` |
| `ones` | integer | running population count, used to derive `valid` |

## 6. Architecture

```
onehot[WIDTH-1:0] ──► for each set bit i: bin |= i, ones++
                                       │
                       ones == 1 ?  valid = 1 : valid = 0
```

Every set bit's index is OR-ed into `bin` unconditionally; the OR-tree
itself does not distinguish a genuine one-hot input from a malformed one —
that distinction is made entirely by the separate `ones` population count.

## 7. Module Hierarchy and Connections

```
tb_onehot_to_bin
├── dut8  : onehot_to_bin #(.WIDTH(8))
└── dut16 : onehot_to_bin #(.WIDTH(16))
```

## 8. Verilog Concepts Used

* `$clog2` to size the binary output from the parameterized input width.
* A `for` loop inside a combinational `always @(*)` block that both builds
  an OR-tree (`bin = bin | i[...]`) and accumulates a population count in
  the same pass.
* Separating "compute a result" from "decide whether the result is
  meaningful" into two independent computations (`bin` via OR-tree, `valid`
  via population count) rather than conflating them in one expression.

## 9. Source Code Explanation

```verilog
always @(*) begin
    bin  = {BIN_WIDTH{1'b0}};
    ones = 0;
    for (i = 0; i < WIDTH; i = i + 1) begin
        if (onehot[i]) begin
            bin  = bin | i[BIN_WIDTH-1:0];
            ones = ones + 1;
        end
    end
    valid = (ones == 1);
end
```
* `bin` starts at 0 and only ever has bits OR-ed in, never cleared, so for
  a true one-hot input the single set bit's index passes through unchanged.
* For a malformed input (zero or multiple bits set), `bin` still comes out
  as *some* value (the OR of every set index) — this is exactly why
  `valid` must be checked separately: the OR-tree does not, and cannot by
  its own construction, detect that its result is meaningless for a
  non-one-hot input.
* `ones` is an independent count, incremented once per set bit scanned in
  the same loop; `valid` is simply `ones == 1`, with no dependency on the
  particular index values involved.

## 10. Testbench Explanation

`tb_onehot_to_bin` covers two widths:

1. **`WIDTH=8`, exhaustive**: all 256 possible 8-bit codes (8 genuinely
   one-hot, 248 invalid — one all-zero plus every combination with two or
   more bits set) checked against an independently computed population
   count and bit-index reference model.
2. **`WIDTH=16`, directed + random**: all 16 one-hot codes, several
   directed invalid codes (all-zero, all-ones, every adjacent two-hot
   pair), and 2000 random 16-bit vectors from `$random(seed)` (default
   seed `1`, overridable with `+seed=<n>`), confirming the OR-tree/
   population-count approach generalizes correctly beyond the exhaustively
   checked width.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | WIDTH=8 exhaustive | all 256 codes | `valid`/`bin` match population-count reference model |
| 2 | WIDTH=16 one-hot | all 16 single-bit codes | `valid=1`, `bin` = bit index |
| 3 | WIDTH=16 invalid | all-zero, all-ones, 15 two-hot pairs | `valid=0` |
| 4 | WIDTH=16 random | 2000 vectors, seed=1 | matches reference model regardless of population count |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 053` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_onehot_to_bin` — **PASS**

```text
WIDTH=8 exhaustive sweep (256 codes: 8 one-hot + 248 invalid)...
  done: 256 checks, errors so far: 0
WIDTH=16 directed one-hot codes (16 codes)...
WIDTH=16 directed invalid codes (all-zero, all-ones, two-hot)...
WIDTH=16 random codes (2000 vectors)...
  done: 2289 checks total, errors so far: 0
TEST PASSED: 2289 checks
tb/tb_onehot_to_bin.v:95: $finish called at 2289000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 109 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The OR-tree unrolls to `WIDTH` OR gates feeding each bit of `bin`,
  similar in spirit to a wide reduction-OR; gate depth grows logarithmically
  with `WIDTH` once synthesis balances the OR tree, unlike a `case`-based
  encoder whose depth depends on the synthesis tool's mux-tree strategy.
* `bin` is only meaningful when `valid = 1`; callers must check `valid`,
  exactly as `encoder8to3` requires in category 02 — this design does not
  attempt to make `bin` "safe" on its own for invalid inputs beyond
  defaulting it to 0 at the start of each evaluation.
* Purely combinational, no reset or clock.

## 14. Common Mistakes

* Trusting `bin` without checking `valid` — for a genuinely malformed
  input the OR-tree still produces *a* numeric value, which looks like a
  legitimate index but is not.
* Assuming population count and bit-index extraction must be two separate
  passes over the input — this design computes both together in one loop,
  which is both simpler and avoids redundant iteration.
* Forgetting `$clog2(WIDTH)` must size `bin` correctly for a non-power-of-two
  `WIDTH` — this design assumes power-of-two widths (as tested), and a
  caller instantiating a non-power-of-two `WIDTH` should re-check that
  `$clog2` still gives the intended output width.

## 15. Possible Improvements

* Add a priority-fallback mode (return the lowest or highest set bit's
  index even when the input is not strictly one-hot), matching the
  priority encoder studied earlier in category 02.
* Implement and compare a `generate`-based binary-tree OR reduction against
  this loop-based version for synthesis depth/area.

## 16. What This Program Teaches

* Building a width-generic decoder with a `for` loop instead of an
  enumerated `case` table.
* Why a "does this OR-tree give a valid answer" check must be computed
  independently of the answer itself.
* Testing the same algorithm at two different widths to confirm it
  generalizes, not just that one hard-coded case works.

## 17. Industry Relevance

Converting one-hot state or grant vectors back to a compact binary index is
routine in FSM debug/status logic, arbiter grant encoding, and interrupt
controllers; the general OR-tree/population-count technique here scales to
any width without per-code enumeration, unlike a `case`-table encoder.

## 18. How to Run

```bash
python3 scripts/run.py 053            # compile, simulate, synthesize, lint
cd 03-combinational-logic/053-one-hot-to-binary-converter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/onehot_to_bin.v tb/tb_onehot_to_bin.v
vvp build/sim.vvp +vcd +seed=42
```
