# 048 — Parity Generator and Checker

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Beginner | (none — two independent modules) | `src/parity_generator.v`, `src/parity_checker.v` | `tb/tb_parity_codec.v` |

## 1. Objective

Build a matched transmit/receive pair — a parity generator and a parity
checker — that together detect any single-bit error introduced between
generation and checking, and understand exactly what parity can and cannot
detect.

## 2. What the Design Does

`parity_generator` computes one parity bit from an `WIDTH`-bit data word so
that the combined codeword `{data, parity}` has an even (`ODD=0`) or odd
(`ODD=1`) total number of 1 bits. `parity_checker` independently recomputes
the same expected bit from the received `data` and compares it against the
received `parity_in`, raising `error` on any mismatch. Because flipping any
single bit of `{data, parity}` always changes the total 1-count's parity,
`error` is guaranteed to go high for exactly one bit flipped anywhere in the
codeword — but two bit flips cancel out and are silently missed, which is
the classic limitation of simple parity.

## 3. Why It Is Useful

Parity is the simplest possible error-detecting code and is still used
today wherever a cheap, fast single-error indicator is enough: memory
buses, UART framing, and many bus protocols carry a parity bit per byte or
word. Understanding its exact detection guarantee (odd bit-flip counts,
never even) is a prerequisite for the Hamming code later in this category,
which extends parity to also correct the error it detects.

## 4. Interface

**`parity_generator`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | data word to protect |
| `parity` | output | 1 | parity bit for `{data, parity}` |

**`parity_checker`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | received data word |
| `parity_in` | input | 1 | received parity bit |
| `error` | output | 1 | 1 when `{data, parity_in}` does not match the expected parity |

Parameters (both modules):

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | width of the data word |
| `ODD` | 0 | 0 = even parity, 1 = odd parity — generator and checker must agree |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `expected_parity` (in `parity_checker`) | 1 | parity recomputed from the received `data`, compared against `parity_in` |

## 6. Architecture

```
             ┌──────────────────┐                  ┌──────────────────┐
   data ────►│ parity_generator │── parity ───┐     │  parity_checker  │
             └──────────────────┘             ├────►│ data, parity_in │──► error
             (transmit side)                  │     └──────────────────┘
                                          "channel"     (receive side)
                                     (may flip a bit)
```

Both modules compute the identical `^data` (or its complement) reduction
independently; no state or shared logic connects them except the codeword
itself.

## 7. Module Hierarchy and Connections

```
tb_parity_codec
├── genE : parity_generator #(.WIDTH(8), .ODD(0))
├── chkE : parity_checker   #(.WIDTH(8), .ODD(0))
├── genO : parity_generator #(.WIDTH(8), .ODD(1))
└── chkO : parity_checker   #(.WIDTH(8), .ODD(1))
```

There is no top-level wrapper module: the testbench itself plays the role
of the "channel", copying (and optionally corrupting) the generator's output
into the checker's input, mirroring how parity is used across a real link.

## 8. Verilog Concepts Used

* Reduction XOR (`^data`) as the core of both even and odd parity.
* Two independently-parameterized instances (`ODD=0`, `ODD=1`) of the same
  pair of modules run side by side in one testbench.
* Fault injection in a testbench: deliberately corrupting one bit of a
  correct signal to exercise the detection logic, rather than only testing
  the clean path.

## 9. Source Code Explanation

```verilog
assign parity = ODD ? ~(^data) : (^data);
```
* `^data` is 1 exactly when `data` has an odd number of 1 bits. For even
  parity, appending that bit directly always brings the total to an even
  count; for odd parity, its complement is appended instead.

```verilog
wire expected_parity = ODD ? ~(^data) : (^data);
assign error = (parity_in != expected_parity);
```
* The checker recomputes the same formula from the *received* `data` and
  compares it to the *received* `parity_in`. This is algebraically
  equivalent to `error = ^{data, parity_in}` (even) or its complement (odd)
  — a single reduction XOR over the whole codeword — which is why any one
  bit flip anywhere in `{data, parity_in}` always toggles `error`.

## 10. Testbench Explanation

`tb_parity_codec` drives both the even (`genE`/`chkE`) and odd
(`genO`/`chkO`) pairs with the same data stimulus:

1. **Clean-codeword sweep**: for all 256 possible 8-bit data values,
   `check_clean` generates parity, feeds it straight into the matching
   checker unmodified, and confirms `error == 0` for both configurations
   (and independently confirms the total XOR of `{data,parity}` is 0 for
   even / 1 for odd).
2. **Single-bit error injection**: for every one of the 256 data values and
   every one of the `WIDTH+1 = 9` codeword bit positions (8 data bits plus
   the parity bit itself), `check_single_bit_error` flips exactly that one
   bit before presenting it to the checker and confirms `error == 1` — a
   total of `256 × 9 = 2304` single-bit-flip cases per configuration,
   4608 across both.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Clean codeword, even | all 256 data values | `error=0`, total parity even |
| 2 | Clean codeword, odd | all 256 data values | `error=0`, total parity odd |
| 3 | Single-bit error, data bits | 256 data values × 8 data-bit positions | `error=1` |
| 4 | Single-bit error, parity bit | 256 data values × 1 parity-bit position | `error=1` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 048` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_parity_codec` — **PASS**

```text
exhaustive clean-codeword sweep (256 data values)...
  done: 512 checks, errors so far: 0
exhaustive single-bit error injection (256 data values x 9 bit positions)...
  done: 5120 checks total, errors so far: 0
TEST PASSED: 5120 checks
tb/tb_parity_codec.v:107: $finish called at 5120000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 15 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `parity_generator` and `parity_checker` must be instantiated with the
  same `WIDTH` and `ODD` on both ends of a real link; nothing in this
  design enforces that at the protocol level, only at the testbench level.
* Simple parity detects any odd number of bit errors and misses every even
  number (in particular, exactly two flipped bits are invisible) — this is
  a fundamental property of a single XOR-based check, not a bug, and the
  testbench only exercises the single-bit-flip case that parity is
  specified to catch.
* Both modules are pure combinational logic with no reset or clock.

## 14. Common Mistakes

* Mismatching `ODD` between generator and checker — every clean codeword
  would then be reported as an error, since the checker expects the
  opposite total parity.
* Assuming parity can correct an error rather than merely detect it —
  `error` only says *that* the codeword is inconsistent, not *which* bit is
  wrong; correction needs the extra structure built in the Hamming code
  program later in this category.
* Believing parity catches all errors — it is blind to any even number of
  simultaneous bit flips, a property demonstrated by the fact that this
  design's single-bit-flip sweep is exhaustive precisely because two-bit
  flips are known, by construction, to be undetectable.

## 15. Possible Improvements

* Extend to a 2D (row/column) parity scheme that can correct, not just
  detect, single-bit errors without the full Hamming code machinery.
* Add a `parity_type` runtime input instead of the `ODD` parameter for
  protocols that switch parity convention per frame.

## 16. What This Program Teaches

* Reduction XOR as an error-detection primitive.
* The precise fault model simple parity does and does not cover.
* Structuring a testbench around fault injection (corrupt-then-check)
  rather than only golden-path stimulus.

## 17. Industry Relevance

Parity bits protect ECC-lite memory buses, RS-232/UART frames, and many
legacy and current bus protocols; understanding its single-bit-only
detection guarantee is the direct motivation for the stronger Hamming and
CRC codes covered later in this curriculum.

## 18. How to Run

```bash
python3 scripts/run.py 048            # compile, simulate, synthesize, lint
cd 03-combinational-logic/048-parity-generator-checker && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/parity_generator.v src/parity_checker.v tb/tb_parity_codec.v
vvp build/sim.vvp +vcd
```
