# 040 — Parameterized N-to-2^N Decoder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Elementary | `decoder_n` | `src/decoder_n.v` | `tb/tb_decoder_n.v` |

## 1. Objective

Generalize the fixed-width decoders of programs 038–039 into a single
module whose address width `N` is a parameter, using the same shift-based
one-hot construction scaled to any `N` via `$clog2`-style parameter
arithmetic (`OUT_W = 1 << N`).

## 2. What the Design Does

`decoder_n` converts the `N`-bit binary code `a` into a one-hot
`2^N`-bit output `y`, active only while `en = 1`:

```
y = en ? (one-hot bit `a` set) : all-zero,   y is 2^N bits wide
```

For `N = 3` this behaves exactly like `decoder2to4` extended one bit (in
fact identically to the address decode inside `decoder3to8`, program 039);
for `N = 4` it produces a 16-bit one-hot output.

## 3. Why It Is Useful

Real designs need decoders of many different widths (2:4, 3:8, 4:16, 5:32,
...) for address decoding, opcode dispatch, and one-hot state encoding.
Writing one parameterized module instead of a family of fixed-width modules
avoids duplicated, drift-prone RTL — this is the same generalization program
037 applied to the demultiplexer.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | `N` | Binary code to decode |
| `en` | input | 1 | Active-high enable; forces `y` to all-zero when low |
| `y` | output | `2^N` | One-hot decode of `a`, or all-zero when `en = 0` |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `N` | 3 | Address width; output width is derived as `2^N` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `OUT_W` (`localparam`) | — | `1 << N`, the derived output width, used only at elaboration time |

## 6. Architecture

```
 a[N-1:0] ──► shift {0..0,1} left by a ──► one-hot pattern (OUT_W bits)
                                                  │
 en ──────────────────────────[ gate to zero when en=0 ]──► y
```

Identical in structure to `decoder2to4` (program 038), but with the
literal width and shift amount both derived from the parameter `N` instead
of being fixed at 2 and 4.

## 7. Module Hierarchy and Connections

```
tb_decoder_n
├── dut3 : decoder_n #(.N(3))   -- 3:8 decoder, exhaustive
└── dut4 : decoder_n #(.N(4))   -- 4:16 decoder, exhaustive
```

## 8. Verilog Concepts Used

* `localparam OUT_W = 1 << N;` deriving a dependent width from a parameter,
  continuing the pattern from program 011.
* A parameter used directly in a **port width expression**
  (`output wire [(1<<N)-1:0] y`), not just in an internal signal.
* Replication (`{OUT_W-1{1'b0}}`) to build a width-generic single-bit
  constant before shifting it.
* Bitwise power-of-2 test in the testbench (`y & (y-1) == 0`) to check the
  one-hot invariant without a fixed-width popcount.

## 9. Source Code Explanation

```verilog
module decoder_n #(
    parameter N = 3
) (
    input  wire [N-1:0]      a,
    input  wire              en,
    output wire [(1<<N)-1:0] y
);
    localparam OUT_W = 1 << N;

    assign y = en ? ({{OUT_W-1{1'b0}}, 1'b1} << a) : {OUT_W{1'b0}};
endmodule
```

* `output wire [(1<<N)-1:0] y` sizes the output port itself from the
  parameter, so instantiating with `#(.N(4))` automatically produces a
  16-bit `y` with no separate width parameter to keep in sync.
* `localparam OUT_W = 1 << N;` gives the derived width a name, used in the
  replication and the all-zero literal, so the intent ("this is the decoded
  output width") is explicit rather than repeating `1<<N` everywhere.
* `{{OUT_W-1{1'b0}}, 1'b1}` builds an `OUT_W`-bit constant equal to 1 (bit 0
  set, everything else 0) at exactly the right width for any `N`; shifting
  it left by `a` produces the one-hot pattern, exactly as `4'b0001 << a`
  did for the fixed `N=2` case in program 038.
* `en ? (...) : {OUT_W{1'b0}}` gates the result to all-zero when disabled,
  using a properly-sized zero literal so the ternary's two branches always
  match in width regardless of `N`.

## 10. Testbench Explanation

`tb_decoder_n` instantiates two configurations and tests each exhaustively:

1. `dut3` (`N=3`): `{en, a}` is swept over all 16 combinations. Each check
   recomputes the expected one-hot pattern independently and additionally
   verifies, whenever `en=1`, that `y` is nonzero and a power of two
   (`y & (y-1) == 0`) — the general-width equivalent of the fixed bit-sum
   check used in programs 038–039.
2. `dut4` (`N=4`): the same exhaustive strategy is applied over all 32
   combinations of `{en, a}`.

Every check increments `checks`; a mismatch or a broken one-hot invariant
increments `errors` and prints an `ERROR:` line with the parameter set,
inputs, expected and actual values. The final line is `TEST PASSED: 48
checks` (16 + 32) or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive, `N=3` | `{en,a}` = 0..15 | One-hot `y` at bit `a` when `en=1`; all-zero otherwise |
| 2 | Exhaustive, `N=4` | `{en,a}` = 0..31 | One-hot `y` at bit `a` when `en=1`; all-zero otherwise |

Both parameter sets are exercised over 100% of their `{en, a}` input space.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 040` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_decoder_n` — **PASS**

```text
N=3 exhaustive (16 combinations):
N=4 exhaustive (32 combinations):
done: 48 checks
TEST PASSED: 48 checks
tb/tb_decoder_n.v:70: $finish called at 48000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 21 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `N=3` and `N=4` together synthesize to 21 cells total (Yosys generic
  `synth`), consistent with two independent one-hot decoders of different
  widths sharing no logic.
* The shift-based construction generalizes cleanly to any `N` supported by
  the simulator/synthesis tool's vector width limits; there is no
  power-of-2 restriction on `N` itself (unlike `mux_n`/`demux_n`'s
  restriction on their element-count parameter), since every `N`-bit `a`
  addresses a valid one-hot position in a `2^N`-bit `y` by construction.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Writing `1 << N` inline everywhere instead of naming it `OUT_W` — harmless
  functionally, but it obscures the relationship between the parameter and
  the derived width, especially in the replication expression.
* Forgetting to size the all-zero literal (`{OUT_W{1'b0}}` rather than a bare
  `0`) — a bare `0` would be extended/truncated implicitly and can trigger
  simulator/synthesis width-mismatch warnings.

## 15. Possible Improvements

* Add a `generate`-for-based alternative implementation (mirroring
  `demux_n`, program 037) for comparison with this shift-based one.
* Provide a matching parameterized priority encoder as the inverse
  operation (program 043 does this independently).

## 16. What This Program Teaches

* Deriving a port's width directly from a parameter expression.
* Using `localparam` to name a derived constant used in multiple places.
* Generalizing a verified fixed-width design (038) into a parameterized one
  without changing its underlying logic, only its width expressions.

## 17. Industry Relevance

Parameterized decoders are standard IP-reuse practice: the same RTL text
serves a 2:4 address decode block and a 5:32 one just by changing an
instantiation parameter, avoiding a family of near-duplicate fixed-width
modules that would otherwise need to be kept in sync by hand.

## 18. How to Run

```bash
python3 scripts/run.py 040            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/040-decoder-parameterized && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/decoder_n.v tb/tb_decoder_n.v
vvp build/sim.vvp +vcd
```
