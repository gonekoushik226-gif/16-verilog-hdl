# 041 — 8-to-3 Encoder with Valid Flag

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `encoder8to3` | `src/encoder8to3.v` | `tb/tb_encoder8to3.v` |

## 1. Objective

Implement the inverse of a decoder: convert a one-hot 8-bit input back into
its 3-bit binary index, and explicitly flag inputs that are not valid
one-hot codes instead of producing a silently wrong answer.

## 2. What the Design Does

`encoder8to3` looks for exactly one set bit in `d` and reports its index on
`y`:

| `d` | `y` | `valid` |
|---|---|---|
| `0000_0001` | `000` | 1 |
| `0000_0010` | `001` | 1 |
| `0000_0100` | `010` | 1 |
| `0000_1000` | `011` | 1 |
| `0001_0000` | `100` | 1 |
| `0010_0000` | `101` | 1 |
| `0100_0000` | `110` | 1 |
| `1000_0000` | `111` | 1 |
| any other value (`0` bits set, or 2+ bits set) | `000` | 0 |

`valid` distinguishes a genuine "no active input" or "multiple active
inputs" condition from a real, meaningful `y = 0`.

## 3. Why It Is Useful

Plain (non-priority) encoders appear wherever a system needs to convert a
known-good one-hot signal (like a decoder's own output, or a set of
mutually-exclusive request lines) back into a binary index, while still
being able to detect a protocol violation (two requesters active at once,
or a hardware fault producing an unexpected code) via `valid`, rather than
producing a plausible-looking but meaningless `y`.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `d` | input | 8 | Expected to be one-hot |
| `y` | output | 3 | Binary index of the set bit in `d`, valid only when `valid=1` |
| `valid` | output | 1 | 1 when `d` is exactly one-hot, 0 otherwise |

No parameters.

## 5. Internal Signals

None — `y` and `valid` are `reg` only because they are assigned inside an
`always` block; both are still pure combinational functions of `d`.

## 6. Architecture

```
        ┌───────────────────────────────┐
  d[7:0]│ always @(*) case (d)          │──► y
   ────►│   8'b0000_0001: y=0           │
        │   ...                        │
        │   8'b1000_0000: y=7          │
        │   default: y=0, valid=0      │──► valid
        └───────────────────────────────┘
```

A single combinational lookup, distinguishing the 8 valid one-hot codes
from the other 248 possible values of `d`.

## 7. Module Hierarchy and Connections

```
tb_encoder8to3
└── dut : encoder8to3
```

The testbench drives `d` and observes `y`/`valid` directly; there is no
further hierarchy.

## 8. Verilog Concepts Used

* `always @(*)` combinational block with a **default assignment at the
  top** (`y = 3'b000; valid = 1'b1;`) to prevent an inferred latch.
* `case` statement matching exact bit patterns, with `default` handling
  every value not explicitly listed.
* A `begin ... end` block inside a `case` item to make two assignments
  (`y` and `valid`) atomically for the invalid case.
* A testbench-side bit-counting loop (`popcount`) as an independent
  reference model for "is `d` one-hot".

## 9. Source Code Explanation

```verilog
always @(*) begin
    y     = 3'b000;
    valid = 1'b1;
    case (d)
        8'b0000_0001: y = 3'd0;
        ...
        8'b1000_0000: y = 3'd7;
        default: begin
            y     = 3'b000;
            valid = 1'b0;
        end
    endcase
end
```

* The default assignments before the `case` give both outputs a value on
  every evaluation, so the `case`'s eight explicit branches only need to
  override `y` (they inherit `valid = 1` from the default), while the
  `default:` branch overrides both `y` and `valid` for every other value of
  `d`.
* Listing the 8 one-hot patterns as literal bit patterns (rather than, say,
  a priority scan) makes the "exactly one bit set" requirement explicit and
  self-documenting: any pattern not in that list — including `0`, `3`
  (`0000_0011`), or `255` (`1111_1111`) — falls to `default`.
* Because `d` is fully specified (256 possible values, 8 handled
  explicitly), the `default` branch is reachable for the remaining 248
  values, unlike the unreachable `default` in program 038's 2-bit decoder.

## 10. Testbench Explanation

`tb_encoder8to3` is exhaustive over the entire 8-bit input space (256
values, well within the "exhaustive when ≤ 2^16" rule):

1. For each value of `d` from 0 to 255, the bench independently counts the
   set bits (`popcount`) and records the index of the highest one seen
   (`bit_idx`) using a small bit-scanning loop — a reference model that
   does not reuse the DUT's `case` structure.
2. `expected_valid = (popcount == 1)`; `expected_y` is `bit_idx` when valid,
   else `3'b000`.
3. The check compares `valid` unconditionally, and only compares `y` when
   `expected_valid` is true — for invalid inputs, `y`'s value is defined by
   this implementation (forced to 0) but the check only asserts what the
   interface actually promises (`valid` says whether `y` means anything).

Every one of the 256 values increments `checks`; a mismatch increments
`errors` and prints an `ERROR:` line with `d`, expected and actual
`valid`/`y`. The final line is `TEST PASSED: 256 checks` or a
`TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | 8 valid one-hot codes | `d` = each single bit set | `valid=1`, `y` = bit index |
| 2 | All-zero | `d = 0000_0000` | `valid=0` |
| 3 | 247 remaining multi-bit codes | `d` = every other 8-bit value | `valid=0` |

All 256 possible values of `d` (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 041` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_encoder8to3` — **PASS**

```text
checked all 256 input codes (8 one-hot, 248 invalid)
done: 256 checks
TEST PASSED: 256 checks
tb/tb_encoder8to3.v:52: $finish called at 256000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 50 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Explicitly forcing `y = 3'b000` on invalid input (rather than leaving it
  `x` or matching the last valid value) makes simulation and synthesis
  agree and keeps waveform debugging predictable, at the cost of a slightly
  larger case table (50 cells reported by Yosys) than a priority-only
  design would need.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Treating a plain encoder like a priority encoder: if two bits of `d` are
  set, this design reports `valid=0` rather than silently picking the
  higher-priority bit — conflating the two behaviours produces a design
  that hides genuine protocol violations (see program 042 for the priority
  variant, where multiple active inputs are the expected, handled case).
* Forgetting the `valid` output entirely and just returning `y=0` for
  invalid input, which is indistinguishable from a legitimate `d =
  0000_0001` — exactly the ambiguity `valid` exists to resolve.

## 15. Possible Improvements

* Add a priority-encoder variant that behaves gracefully with multiple
  active bits (program 042 does this independently, not as a mode switch
  of this design).
* Generalize to N-to-log2(N) with a parameter, mirroring `decoder_n`
  (040) on the encode side.

## 16. What This Program Teaches

* Encoding as the structural inverse of decoding.
* Using an explicit valid/error flag instead of relying on a specific
  output value to signal an invalid condition.
* Verifying both the "expected" and "error" branches of a design over the
  complete input space.

## 17. Industry Relevance

Plain one-hot-to-binary encoders with a validity check are used wherever
software or another block needs a compact index from a set of
mutually-exclusive status or request lines — interrupt controllers,
resource-grant logic and one-hot state-machine decoders all use this exact
pattern, with the valid flag catching design or fault conditions early.

## 18. How to Run

```bash
python3 scripts/run.py 041            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/041-encoder-8to3 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/encoder8to3.v tb/tb_encoder8to3.v
vvp build/sim.vvp +vcd
```
