# 039 — 3-to-8 Decoder (Cascaded from 2:4 Decoders)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Elementary | `decoder3to8` | `src/decoder2to4.v`, `src/decoder3to8.v` | `tb/tb_decoder3to8.v` |

## 1. Objective

Build a 3-to-8 one-hot decoder by cascading two of the program-038
`decoder2to4` blocks, using the top address bit to enable exactly one of
them — the same technique real decoder ICs (e.g. the 74138) use internally
to extend a smaller decoder to a wider one.

## 2. What the Design Does

`decoder3to8` converts the 3-bit binary code `a` into a one-hot 8-bit
output `y`, active only while `en = 1`:

| `en` | `a` | `y` (`y7..y0`) |
|---|---|---|
| 0 | any | `0000_0000` |
| 1 | `000` | `0000_0001` |
| 1 | `001` | `0000_0010` |
| 1 | `010` | `0000_0100` |
| 1 | `011` | `0000_1000` |
| 1 | `100` | `0001_0000` |
| 1 | `101` | `0010_0000` |
| 1 | `110` | `0100_0000` |
| 1 | `111` | `1000_0000` |

Internally, `a[2]` chooses which half of `y` is live: `a[1:0]` addresses
within that half via two independent `decoder2to4` instances.

## 3. Why It Is Useful

This cascade pattern — using the extra address bit(s) to enable/disable
smaller identical decoder blocks — is exactly how wider address decoders
are built from a fixed-size decoder primitive, and it demonstrates the
general principle (also used for wider muxes, encoders and memory chip
selects) that N-bit problems decompose into (N-1)-bit sub-problems plus one
selecting bit.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 3 | Binary code to decode |
| `en` | input | 1 | Active-high enable; forces `y` to all-zero when low |
| `y` | output | 8 | One-hot decode of `a`, or all-zero when `en = 0` |

No parameters.

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `en_lo` | 1 | Enables `dec_lo` when `en=1` and `a[2]=0` (target is in `y[3:0]`) |
| `en_hi` | 1 | Enables `dec_hi` when `en=1` and `a[2]=1` (target is in `y[7:4]`) |
| `y_lo` | 4 | Output of the low-half `decoder2to4`, becomes `y[3:0]` |
| `y_hi` | 4 | Output of the high-half `decoder2to4`, becomes `y[7:4]` |

## 6. Architecture

```
              en_lo = en & ~a[2]
 a[1:0] ──┬──►[ decoder2to4 dec_lo ]──► y_lo ──► y[3:0]
          │
 a[2] ────┤   en_hi = en &  a[2]
          └──►[ decoder2to4 dec_hi ]──► y_hi ──► y[7:4]
```

`a[1:0]` fans out to both `decoder2to4` instances unchanged; `a[2]` (via
`en_lo`/`en_hi`) decides which one is actually enabled, so only one half of
`y` can ever be non-zero at a time.

## 7. Module Hierarchy and Connections

```
tb_decoder3to8
└── dut : decoder3to8
    ├── dec_lo : decoder2to4 (a=a[1:0], en=en_lo) -> y_lo -> y[3:0]
    └── dec_hi : decoder2to4 (a=a[1:0], en=en_hi) -> y_hi -> y[7:4]
```

## 8. Verilog Concepts Used

* Structural composition of two instances of a smaller, previously verified
  module to build a wider one (following the same pattern as program 033's
  mux tree, applied to decoders instead).
* Continuous-assignment `wire` declarations with an initializer
  (`wire en_lo = en & ~a[2];`) computing the per-instance enables.
* Bit concatenation (`{y_hi, y_lo}`) to assemble the final output from two
  half-width results.

## 9. Source Code Explanation

```verilog
module decoder3to8 (
    input  wire [2:0] a,
    input  wire       en,
    output wire [7:0] y
);
    wire en_lo = en & ~a[2];
    wire en_hi = en &  a[2];
    wire [3:0] y_lo, y_hi;

    decoder2to4 dec_lo (.a(a[1:0]), .en(en_lo), .y(y_lo));
    decoder2to4 dec_hi (.a(a[1:0]), .en(en_hi), .y(y_hi));

    assign y = {y_hi, y_lo};
endmodule
```

* `en_lo` and `en_hi` are mutually exclusive whenever `en = 1`: exactly one
  of `~a[2]` and `a[2]` is true, so exactly one of the two `decoder2to4`
  instances is enabled and the other outputs all-zero.
* Both instances receive the same `a[1:0]`; only their `en` input differs.
  Each instance's own `en ? (0001 << a) : 0000` logic (from program 038)
  handles disabling internally — `decoder3to8` does not need to separately
  force `y_hi`/`y_lo` to zero.
* `{y_hi, y_lo}` places `y_hi` (bits for `a[2]=1`) in the upper 4 bits and
  `y_lo` (bits for `a[2]=0`) in the lower 4 bits, matching the truth table
  in section 2.

## 10. Testbench Explanation

`tb_decoder3to8` is exhaustive: `{en, a}` is only 4 bits, so all 16
combinations are covered in one run.

1. `en`/`a` are driven from a `for` loop over `i = 0..15`.
2. After a `#1` settling delay, the bench computes
   `expected = en ? (8'b1 << a) : 8'b0` independently and compares.
3. Two structural invariants are also checked: when `en = 1`, exactly one
   bit of `y` is set (verified by summing all 8 bits); when `en = 0`, `y`
   is exactly all-zero.
4. Every combination prints a row; any mismatch prints an `ERROR:` line
   with time, inputs, expected and actual values.

The final line is `TEST PASSED: 16 checks` or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Disabled | `en=0`, `a`=0..7 | `y = 8'b0` for every `a` |
| 2 | Enabled | `en=1`, `a`=0..7 | `y` one-hot at bit `a` |

All 16 cases (100% of the input space) are exercised, including the
one-hot and all-zero invariants.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 039` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_decoder3to8` — **PASS**

```text
en a2 a1 a0 | y
 0   0  0  0  | 00000000
 0   0  0  1  | 00000000
 0   0  1  0  | 00000000
 0   0  1  1  | 00000000
 0   1  0  0  | 00000000
 0   1  0  1  | 00000000
 0   1  1  0  | 00000000
 0   1  1  1  | 00000000
 1   0  0  0  | 00000001
 1   0  0  1  | 00000010
 1   0  1  0  | 00000100
 1   0  1  1  | 00001000
 1   1  0  0  | 00010000
 1   1  0  1  | 00100000
 1   1  1  0  | 01000000
 1   1  1  1  | 10000000
done: 16 checks
TEST PASSED: 16 checks
tb/tb_decoder3to8.v:48: $finish called at 16000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 18 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The cascade adds one extra AND-gate level (computing `en_lo`/`en_hi`)
  compared to a flat 3:8 decoder, but reuses a previously verified block
  entirely unmodified — Yosys reports 18 cells total, matching two 2:4
  decoders (8 cells each) plus the two enable-gating gates.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Enabling both halves unconditionally (e.g. tying `en_lo = en_hi = en`)
  instead of gating by `a[2]`, which would make both `decoder2to4`
  instances active simultaneously and corrupt the one-hot property.
* Swapping which half `a[2]=0` vs `a[2]=1` selects, which reverses the
  upper/lower placement of `y_hi`/`y_lo` in the final concatenation.

## 15. Possible Improvements

* Extend the same cascade technique one more level for a 4:16 decoder.
* Compare against the fully parameterized `decoder_n` of program 040, which
  achieves the same generality with a single shift expression instead of a
  hand-built cascade.

## 16. What This Program Teaches

* Composing a wider decoder from smaller, already-verified decoder
  instances using the extra address bit as an enable selector.
* That an instance's own internal enable logic (from program 038) can be
  reused unmodified when cascading, rather than duplicating the gating at
  the parent level.
* Verifying a cascaded design exhaustively against the same one-hot and
  disabled-state invariants used for its building block.

## 17. Industry Relevance

Classic decoder ICs (the 74138 3:8 decoder, for instance) are internally
structured exactly this way — smaller decode stages gated by the extra
address bits — and the same cascading principle scales address decoding to
any width in memory-mapped systems.

## 18. How to Run

```bash
python3 scripts/run.py 039            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/039-decoder-3to8-cascaded && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/decoder2to4.v src/decoder3to8.v tb/tb_decoder3to8.v
vvp build/sim.vvp +vcd
```
