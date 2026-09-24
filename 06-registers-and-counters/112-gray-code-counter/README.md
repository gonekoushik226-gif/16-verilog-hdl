# 112 — Gray Code Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Intermediate | `gray_counter` | `src/gray_counter.v` | `tb/tb_gray_counter.v` |

## 1. Objective

Count through all `2^WIDTH` values with the single-bit-change property —
only one bit ever differs between consecutive outputs — using the
standard binary-to-Gray conversion applied to a plain internal binary
counter.

## 2. What the Design Does

`gray_counter` maintains an ordinary internal binary counter (`bin`) and
outputs `gray_count = bin ^ (bin >> 1)` every cycle — the classic
binary-to-Gray transform, re-applied continuously as `bin` counts.

## 3. Why It Is Useful

Ordinary binary counting can change *multiple* bits at once (e.g. `0111
-> 1000` changes all 4 bits) — if those bits are sampled by another
clock domain, or decoded combinationally, the transient mid-transition
values can produce glitches or incorrect momentary decodes. Gray code
guarantees only one bit ever changes, which is why it is the standard
choice for CDC pointer comparison (program 147's async FIFO) and
rotary/quadrature position encoding (program 166).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | count enable |
| `gray_count` | output | `WIDTH` | current Gray-code value |

Parameters: `WIDTH` (default 4).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `bin` | `WIDTH` | the underlying ordinary binary counter |

## 6. Architecture

```
bin <= bin + 1                    (plain binary counter, ordinary wraparound)
gray_count = bin ^ (bin >> 1)     (binary-to-Gray transform, every cycle)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* The standard `b ^ (b >> 1)` binary-to-Gray-code transform, applied as
  a continuous assignment on top of an ordinary counter rather than
  deriving Gray-code next-state logic directly.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  bin <= {WIDTH{1'b0}};
    else if (en) bin <= bin + 1'b1;
end
assign gray_count = bin ^ (bin >> 1);
```
Shifting `bin` right by one and XORing with itself is the standard
reflected-binary Gray code construction: bit `i` of the Gray code is 1
exactly when bits `i` and `i+1` of the binary value differ. Because
consecutive binary values differ by exactly the trailing-1s-then-one-0
pattern of ordinary increment, this transform guarantees the resulting
Gray values differ in exactly one bit between any two consecutive counts
— including across the wraparound from the maximum value back to 0.

## 10. Testbench Explanation

`tb_gray_counter` runs a full `2^WIDTH`-value cycle plus 4 more to
confirm the wrap, checking two things every cycle: the output matches
`bin ^ (bin>>1)` for an independently-maintained software binary
reference, and the Hamming distance (via a `popcount` of the XOR)
between consecutive Gray values is exactly 1.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full cycle | 20 cycles at WIDTH=4 | matches binary-to-Gray reference every cycle |
| 2 | one-bit-change | every transition, including the wrap | exactly one bit differs from the previous value |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 112` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_gray_counter` — **PASS**

```text
TEST PASSED: 21 checks
tb/tb_gray_counter.v:75: $finish called at 206000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 12 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Deriving Gray code from a plain binary counter (rather than
  implementing Gray-code increment logic directly) is simpler to get
  right and easier to verify, at the cost of keeping both a binary and a
  Gray representation in the design (though only `bin` is actually
  registered; `gray_count` is purely combinational from it).

## 14. Common Mistakes

* Forgetting the wraparound case when checking the one-bit-change
  property — it must hold across the maximum-value-to-zero transition
  too, not just between "normal" consecutive counts.
* Implementing "Gray code increment" directly with ad hoc bit-flip logic
  instead of the well-established `b ^ (b>>1)` transform — easy to get
  subtly wrong compared to deriving Gray code from an already-correct
  binary counter.

## 15. Possible Improvements

* Add a Gray-to-binary decoder as a companion module, useful for reading
  back a Gray-coded counter's value as an ordinary number.

## 16. What This Program Teaches

* The standard binary-to-Gray-code transform and why it guarantees the
  single-bit-change property.
* Verifying a property (Hamming distance) directly in a testbench,
  rather than only checking exact expected values.

## 17. Industry Relevance

Gray-code counters are the standard technique for safely crossing clock
domains with a counter value (asynchronous FIFO pointers, program 147)
and for decoding mechanical position sensors (rotary encoders, program
166) where multi-bit simultaneous transitions would otherwise risk
transient miscounts.

## 18. How to Run

```bash
python3 scripts/run.py 112            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/112-gray-code-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/gray_counter.v tb/tb_gray_counter.v
vvp build/sim.vvp +vcd
```
