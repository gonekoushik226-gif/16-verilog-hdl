# 060 — Thermometer Code Converter (with Bubble Detection)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | (none — two independent modules) | `src/bin2therm.v`, `src/therm2bin.v` | `tb/tb_thermometer_converter.v` |

## 1. Objective

Implement both directions of binary/thermometer code conversion, and
handle the real-world case a flash-ADC-style decoder must deal with: a
received thermometer code that is not perfectly monotonic ("bubbles"),
decoding it robustly while still flagging that something was off.

## 2. What the Design Does

`bin2therm` converts a binary count `bin` (`0`–`WIDTH`) into a `WIDTH`-bit
thermometer code where the low `bin` bits are 1 and the rest are 0.
`therm2bin` converts a thermometer-coded value back to a binary count by
counting its 1 bits (population count) — a technique that is naturally
tolerant of small comparator errors — and separately raises `bubble`
whenever the received code is not the canonical monotonic form for its own
count.

## 3. Why It Is Useful

Thermometer code is the natural output of a bank of independent threshold
comparators (as in a flash ADC): each comparator fires 1 when the input
exceeds its own threshold, and in the noise-free case exactly the low
`bin` comparators fire. Real comparator banks occasionally produce a
"bubble" — one comparator disagreeing with its neighbors due to noise or
metastability — and a robust decoder must still produce a sensible reading
rather than a wildly wrong one.

## 4. Interface

**`bin2therm`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `bin` | input | `$clog2(WIDTH+1)` | binary count, `0`–`WIDTH` |
| `therm` | output | `WIDTH` | thermometer code: low `bin` bits are 1 |

**`therm2bin`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `therm` | input | `WIDTH` | received thermometer code (possibly with bubbles) |
| `bin` | output | `$clog2(WIDTH+1)` | decoded count (population count of `therm`) |
| `bubble` | output | 1 | 1 when `therm` is not the canonical monotonic code for `bin` |

Parameters (both modules):

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | thermometer code width |

## 5. Internal Signals

`bin2therm`: loop index `i` inside the combinational `always` block.

`therm2bin`: `BW` (`localparam`, `$clog2(WIDTH+1)`) sizing `bin`; loop
index `i`, reused for both the population-count pass and the canonical-form
comparison pass.

## 6. Architecture

```
bin2therm:  therm[i] = (i < bin)   for i = 0..WIDTH-1

therm2bin:  bin    = popcount(therm)
            bubble = 1 if therm != canonical-code-for(bin), else 0
```

## 7. Module Hierarchy and Connections

```
tb_thermometer_converter
├── dut_b2t : bin2therm #(.WIDTH(8))
└── dut_t2b : therm2bin #(.WIDTH(8))
```

The testbench feeds `dut_b2t`'s output into `dut_t2b`'s input for the
round-trip check, and drives `dut_t2b` directly with hand-crafted
non-canonical codes for the bubble-detection check.

## 8. Verilog Concepts Used

* A `for` loop inside `always @(*)` building a monotonic bit pattern from
  a comparison against the loop index (`therm[i] = (i < bin)`).
* Population-count-based decoding as a robustness technique, contrasted
  with a naive "find the highest set bit" decoder that a single bubble
  would corrupt more severely.
* A second, independent pass over the same data (re-deriving the canonical
  code from the already-computed count and comparing) to detect a
  structural property (monotonicity) separately from computing the count
  itself.
* Explicit bit-width extension (`{{(BW-1){1'b0}}, therm[i]}`) when adding a
  single bit into a wider accumulator, avoiding an implicit-width-extension
  lint warning.

## 9. Source Code Explanation

`bin2therm`:
```verilog
for (i = 0; i < WIDTH; i = i + 1)
    therm[i] = (i < bin);
```
* Bit `i` of the output is 1 exactly when its index is below `bin`,
  directly encoding "the low `bin` bits are set" without any shift/
  subtract arithmetic.

`therm2bin`:
```verilog
bin = {BW{1'b0}};
for (i = 0; i < WIDTH; i = i + 1)
    bin = bin + {{(BW-1){1'b0}}, therm[i]};

bubble = 1'b0;
for (i = 0; i < WIDTH; i = i + 1)
    if (therm[i] != (i < bin))
        bubble = 1'b1;
```
* The first loop counts every set bit in `therm`, regardless of their
  position — this is exactly why a single misplaced bit (a bubble) still
  yields a count off by at most one from the "intended" threshold, instead
  of an arbitrarily wrong result the way reading off "the position of the
  highest set bit" would if that highest bit happened to be a bubble.
* The second loop re-derives what the canonical code *should* look like for
  the count just computed (`i < bin`, the same expression `bin2therm`
  uses) and compares it bit-for-bit against the actual `therm`; any
  mismatch anywhere sets `bubble`, flagging that the input was not a clean
  monotonic thermometer code even though `bin` itself is still a
  well-defined, reasonable count.

## 10. Testbench Explanation

`tb_thermometer_converter` covers:

1. **Exhaustive round trip**: every valid count `bin = 0..WIDTH` (9 values
   for `WIDTH=8`) is converted to thermometer code and back, checking both
   the intermediate code and the recovered count, and confirming
   `bubble = 0` for every legitimately generated code.
2. **Directed bubble codes**: seven hand-crafted non-monotonic 8-bit
   patterns (isolated bits below/above the "front", fully alternating
   patterns, and a canonical code with one bit deliberately flipped),
   each checked against an independently computed population count and
   confirmed to raise `bubble = 1`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive round trip | `bin = 0..8` | `therm2bin(bin2therm(bin)) == bin`, `bubble=0` |
| 2 | Bubble codes | 7 non-monotonic 8-bit patterns | `bin` = popcount, `bubble=1` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 060` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_thermometer_converter` — **PASS**

```text
exhaustive bin->therm->bin round trip (bin = 0..8)...
  done: 18 checks, errors so far: 0
directed bubble (non-monotonic) codes...
  done: 25 checks total, errors so far: 0
TEST PASSED: 25 checks
tb/tb_thermometer_converter.v:91: $finish called at 25000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 71 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Population-count decoding is deliberately chosen over a "find the
  boundary" decoder because it degrades gracefully: one bubble changes the
  count by at most one, rather than potentially jumping to a wildly
  different position.
* `bubble` is purely diagnostic here — `bin` is still reported as the best
  available count regardless of `bubble`'s value, matching how a real
  flash-ADC decoder typically still produces a reading even in the
  presence of comparator noise.
* Both modules are pure combinational logic, no reset or clock.

## 14. Common Mistakes

* Decoding a thermometer code by searching for "the last 1 before the
  first 0" instead of counting — this is exact only for a perfectly clean
  code and can be badly wrong in the presence of even one bubble, unlike
  the population-count approach.
* Conflating `bubble` with "the count is definitely wrong" — a single
  bubble only shifts the count by one at most; `bubble` says the code was
  not clean, not that `bin` is unusable.
* Forgetting to widen a single-bit term before adding it into a wider
  accumulator — Verilog does not implicitly widen the way some other
  languages do, and an explicit replication/concatenation is needed to
  avoid a truncated (or lint-flagged) addition.

## 15. Possible Improvements

* Extend the decoder to also report the number and/or positions of
  detected bubbles, not just their presence.
* Add a corrected-thermometer-code output (the canonical code compared
  against in the bubble check) alongside the binary count.

## 16. What This Program Teaches

* Thermometer-to-binary decoding via population count as a
  noise-tolerant technique, not just a mathematical curiosity.
* Separating "compute a best-effort answer" from "flag that the input
  was not ideal" as two independent outputs.
* Re-deriving an expected structure from a computed result to check a
  property (monotonicity) that the primary computation does not itself
  verify.

## 17. Industry Relevance

Flash ADCs are the fastest ADC architecture precisely because every
comparator evaluates in parallel, producing thermometer code directly;
robust (bubble-tolerant) thermometer-to-binary decoding is a standard,
necessary companion block in any real flash-ADC or similar
comparator-bank-based design.

## 18. How to Run

```bash
python3 scripts/run.py 060            # compile, simulate, synthesize, lint
cd 03-combinational-logic/060-thermometer-code-converter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bin2therm.v src/therm2bin.v tb/tb_thermometer_converter.v
vvp build/sim.vvp +vcd
```
