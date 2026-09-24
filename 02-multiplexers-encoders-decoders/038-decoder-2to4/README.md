# 038 — 2-to-4 Decoder with Enable

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `decoder2to4` | `src/decoder2to4.v` | `tb/tb_decoder2to4.v` |

## 1. Objective

Implement a binary-to-one-hot decoder with an enable input, the standard
building block for address decoding and one-hot control generation.

## 2. What the Design Does

`decoder2to4` converts the 2-bit binary code `a` into a one-hot 4-bit
output `y`, but only while `en = 1`:

| `en` | `a` | `y3 y2 y1 y0` |
|---|---|---|
| 0 | xx | `0 0 0 0` |
| 1 | `00` | `0 0 0 1` |
| 1 | `01` | `0 0 1 0` |
| 1 | `10` | `0 1 0 0` |
| 1 | `11` | `1 0 0 0` |

Exactly one bit of `y` is 1 whenever `en = 1` (bit `a`), and `y` is all
zero whenever `en = 0`, regardless of `a`.

## 3. Why It Is Useful

One-hot decoding turns a compact binary address or opcode into individual
select lines — memory chip selects, register write-enables and multiplexer
control signals are all generated this way. The enable input lets several
decoders share the same address bus while only one is active at a time
(see the cascaded 3:8 decoder in program 039).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 2 | Binary code to decode |
| `en` | input | 1 | Active-high enable; forces `y` to all-zero when low |
| `y` | output | 4 | One-hot decode of `a` (bit `a` is 1), or all-zero when `en = 0` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a[1:0] ──► shift 1 left by a ──► (4'b0001 << a)
                                        │
 en ────────────────────────[ AND-gate each bit ]──► y
```

A single left-shift of the constant `4'b0001` by `a`, gated to zero when
`en` is low; no internal state or hierarchy.

## 7. Module Hierarchy and Connections

```
tb_decoder2to4
└── dut : decoder2to4
```

The testbench drives `a`/`en` and observes `y` directly; there is no
further hierarchy.

## 8. Verilog Concepts Used

* The shift operator (`<<`) used to generate a one-hot pattern from a
  binary index, instead of an explicit `case`.
* The ternary operator (`?:`) to apply the enable.
* A testbench-side one-hot invariant check (counting set bits) in addition
  to the exact expected-value comparison.

## 9. Source Code Explanation

```verilog
module decoder2to4 (
    input  wire [1:0] a,
    input  wire       en,
    output wire [3:0] y
);
    assign y = en ? (4'b0001 << a) : 4'b0000;
endmodule
```

* `4'b0001 << a` shifts the single set bit left by `a` positions: `a=0`
  gives `4'b0001`, `a=3` gives `4'b1000`. This produces the one-hot pattern
  directly from the binary value without listing all four cases explicitly.
* `en ? (...) : 4'b0000` gates the whole result: when `en` is 0, `y` is
  forced to all-zero irrespective of what the shift would have produced.
* This is functionally identical to a `case (a)` with four explicit
  literals (the style used in program 040's `decoder_n` for comparison),
  but the shift expresses the "index to one-hot" relationship directly.

## 10. Testbench Explanation

`tb_decoder2to4` is exhaustive: `{en, a}` has only 3 bits, so all 8
combinations are covered in one run.

1. `en`/`a` are driven from a `for` loop over `i = 0..7`, decomposed as
   `{en, a} = i[2:0]`.
2. After a `#1` settling delay, the bench computes
   `expected = en ? (4'b0001 << a) : 4'b0000` independently and compares.
3. An additional invariant check (`y[0]+y[1]+y[2]+y[3] == 1` whenever
   `en = 1`) confirms the output is genuinely one-hot, not just numerically
   equal to the expected value by coincidence.
4. Every combination prints a truth-table row; any mismatch prints an
   `ERROR:` line with time, inputs, expected and actual values.

The final line is `TEST PASSED: 8 checks` or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | `en` | `a` | Expected `y` |
|---|---|---|---|
| 1 | 0 | `00` | `0000` |
| 2 | 0 | `01` | `0000` |
| 3 | 0 | `10` | `0000` |
| 4 | 0 | `11` | `0000` |
| 5 | 1 | `00` | `0001` |
| 6 | 1 | `01` | `0010` |
| 7 | 1 | `10` | `0100` |
| 8 | 1 | `11` | `1000` |

All 8 cases (100% of the input space) are exercised, including the
one-hot invariant check.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 038` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_decoder2to4` — **PASS**

```text
en a1 a0 | y3 y2 y1 y0
 0   0  0  |  0   0   0   0
 0   0  1  |  0   0   0   0
 0   1  0  |  0   0   0   0
 0   1  1  |  0   0   0   0
 1   0  0  |  0   0   0   1
 1   0  1  |  0   0   1   0
 1   1  0  |  0   1   0   0
 1   1  1  |  1   0   0   0
done: 8 checks
TEST PASSED: 8 checks
tb/tb_decoder2to4.v:44: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 8 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The shift-based description synthesizes to the same 4-output AND-gate
  network a `case` statement would produce (8 cells reported by Yosys);
  there is no area or timing difference between the two coding styles at
  this size.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Forgetting the enable and wiring `y = 4'b0001 << a` directly, which
  leaves the decoder always active and breaks any design (like program
  039's cascade) that relies on disabling unselected decoder instances.
* Assuming `<<` on a 4-bit literal with `a` up to 3 could shift bits out —
  it cannot here since the maximum shift (3) still fits within the 4-bit
  result, but this stops being true if `a` were widened without also
  widening the one-hot output.

## 15. Possible Improvements

* Build a 3:8 decoder from two of these 2:4 decoders (program 039).
* Generalize to N:2^N with a parameter (program 040).

## 16. What This Program Teaches

* Generating a one-hot pattern from a binary index using a shift instead of
  an explicit case list.
* The role of an enable input in decoder cascading and address-map design.
* Checking a structural invariant (one-hot-ness) alongside exact value
  comparison in a testbench.

## 17. Industry Relevance

Address decoders in every memory-mapped system (selecting one peripheral's
chip-select line from an address field) are built from exactly this
binary-to-one-hot-with-enable primitive, usually chained the way program
039 demonstrates.

## 18. How to Run

```bash
python3 scripts/run.py 038            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/038-decoder-2to4 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/decoder2to4.v tb/tb_decoder2to4.v
vvp build/sim.vvp +vcd
```
