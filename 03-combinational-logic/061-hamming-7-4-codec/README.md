# 061 — Hamming(7,4) Codec (Single-Error Correction)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Intermediate | (none — two independent modules) | `src/hamming74_encoder.v`, `src/hamming74_decoder.v` | `tb/tb_hamming74_codec.v` |

## 1. Objective

Implement the classic Hamming(7,4) single-error-correcting code — 4 data
bits protected by 3 parity bits arranged so their syndrome directly encodes
the position of any single flipped bit — closing out this category by
extending program 048's simple parity detection into genuine error
*correction*.

## 2. What the Design Does

`hamming74_encoder` takes 4 data bits and produces a 7-bit codeword with 3
interleaved parity bits, each covering an overlapping subset of positions
chosen so every position has a unique combination of parity coverage.
`hamming74_decoder` recomputes the same three parity checks on a received
codeword; the resulting 3-bit syndrome is 0 if the codeword is unchanged,
or otherwise directly names the 1-indexed position of the single bit that
was flipped, letting the decoder correct it before extracting the 4 data
bits.

## 3. Why It Is Useful

Hamming codes are the simplest example of forward error correction:
instead of merely detecting that an error occurred (as parity does), the
code's structure identifies exactly which bit is wrong, so a receiver can
fix it without asking the sender to retransmit. This underlies ECC memory
and many other real error-correcting systems.

## 4. Interface

**`hamming74_encoder`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | 4 | data bits, `{d4,d3,d2,d1}` |
| `code` | output | 7 | encoded codeword, `code[0]`=position 1 .. `code[6]`=position 7 |

**`hamming74_decoder`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `code_in` | input | 7 | received (possibly corrupted) codeword |
| `data_out` | output | 4 | corrected data bits, same `{d4,d3,d2,d1}` ordering |
| `error` | output | 1 | 1 when a single-bit error was detected (and corrected) |
| `syndrome` | output | 3 | 0 = no error, else the 1-indexed position of the corrected bit |

## 5. Internal Signals

**`hamming74_encoder`**: `p1`, `p2`, `p3` — the three computed parity bits.

**`hamming74_decoder`**: `s1`, `s2`, `s3` — the three recomputed parity
checks; `synd` — their concatenation, the syndrome; `corrected` — the
codeword with the faulty bit (if any) flipped back.

## 6. Architecture

```
codeword position:   1   2   3   4   5   6   7
codeword content:    p1  p2  d1  p3  d2  d3  d4

p1 = d1 ^ d2 ^ d4    (covers positions with bit0 set: 1,3,5,7)
p2 = d1 ^ d3 ^ d4    (covers positions with bit1 set: 2,3,6,7)
p3 = d2 ^ d3 ^ d4    (covers positions with bit2 set: 4,5,6,7)

decoder:
s1 = code[1] ^ code[3] ^ code[5] ^ code[7]   (re-check p1's group)
s2 = code[2] ^ code[3] ^ code[6] ^ code[7]   (re-check p2's group)
s3 = code[4] ^ code[5] ^ code[6] ^ code[7]   (re-check p3's group)
syndrome = {s3,s2,s1}  -->  0 = no error, else the faulty position (1-indexed)
```

The encoding scheme's key property: position `p`'s parity-bit coverage is
exactly the set of positions whose own index has bit `k` set, for the
parity bit that itself sits at position `2^k`. This is precisely what
makes the syndrome — built the same way on the receive side — equal to the
binary position number of any single flipped bit.

## 7. Module Hierarchy and Connections

```
tb_hamming74_codec
├── enc : hamming74_encoder
└── dec : hamming74_decoder
```

The testbench copies (and optionally corrupts) `enc`'s output into `dec`'s
input, mirroring a real transmit/receive link; the two modules have no
direct hardware connection to each other.

## 8. Verilog Concepts Used

* Interleaved parity-bit placement chosen so parity coverage sets encode
  binary position numbers — the conceptual core of the Hamming code,
  expressed directly as fixed XOR equations rather than a generic
  parity-check-matrix multiply.
* A syndrome computed as a concatenation of independent parity checks
  (`{s3,s2,s1}`), used both as a boolean ("was there an error") and as a
  numeric value ("which bit").
* A guarded variable-shift correction (`code_in ^ (7'b1 << (synd-1))`)
  selected only when the syndrome is nonzero — the shift amount is
  meaningless when `synd == 0`, so that branch of the ternary is never
  selected in that case even though hardware evaluates both.

## 9. Source Code Explanation

Encoder:
```verilog
wire p1 = d1 ^ d2 ^ d4;   // positions 1,3,5,7 minus p1 itself = d1,d2,d4
wire p2 = d1 ^ d3 ^ d4;   // positions 2,3,6,7 minus p2 itself = d1,d3,d4
wire p3 = d2 ^ d3 ^ d4;   // positions 4,5,6,7 minus p3 itself = d2,d3,d4
assign code = {d4, d3, d2, p3, d1, p2, p1};
```
* Each parity bit is the XOR of the data bits that fall within its own
  coverage group (excluding itself), chosen so that group is exactly
  "every position whose binary index has this parity bit's own bit set."

Decoder:
```verilog
wire [2:0] synd = {s3, s2, s1};
wire [6:0] corrected = (synd == 3'd0) ? code_in : (code_in ^ (7'b1 << (synd - 3'd1)));
assign data_out = {corrected[6], corrected[5], corrected[4], corrected[2]};
```
* `s1`, `s2`, `s3` each re-run one parity bit's own check against the
  *received* codeword; if nothing changed, every check still balances to 0.
  If exactly one bit anywhere in the codeword flipped, each check that
  originally covered that bit now disagrees, and each check that did not
  cover it still agrees — the pattern of which checks disagree, read as a
  binary number, is precisely that bit's own 1-indexed position, by
  construction of the coverage groups in §6.
* `corrected` flips codeword bit `synd-1` (0-indexed) only when `synd` is
  nonzero, undoing exactly the error the syndrome identified.
* `data_out` reads the three data positions (3, 5, 6, 7 → `corrected[2]`,
  `corrected[4]`, `corrected[5]`, `corrected[6]`) from the now-corrected
  codeword, so a single-bit error in a *parity* bit position is also
  handled correctly (the parity bit itself gets fixed, but since parity
  bits are not part of `data_out`, such an error never even reaches the
  data output — it is still detected and corrected internally for
  consistency and to keep `error`/`syndrome` accurate).

## 10. Testbench Explanation

`tb_hamming74_codec` exhaustively covers all 16 possible 4-bit data words.
For each one, it encodes once with `enc`, then for `flip_pos = 0` (no
error) through `flip_pos = 7` (each of the 7 codeword positions flipped in
turn), `check` copies the clean codeword, optionally flips exactly that one
bit, feeds it to `dec`, and confirms: `data_out` always equals the
original data (every single-bit error, anywhere in the 7-bit codeword, is
fully corrected), `error` is 0 only for the no-error case, and `syndrome`
exactly equals the flipped position number (or 0). This is `16 × 8 = 128`
checks, a complete exhaustive test of the code's single-error-correction
guarantee.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | No error | all 16 data words, codeword unmodified | `data_out` = original, `error=0`, `syndrome=0` |
| 2 | Single-bit error, each position | all 16 data words × 7 flip positions | `data_out` = original (corrected), `error=1`, `syndrome` = flipped position |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 061` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_hamming74_codec` — **PASS**

```text
all 16 data words x (no error + every single-bit error at 7 positions)...
done: 128 checks
TEST PASSED: 128 checks
tb/tb_hamming74_codec.v:67: $finish called at 144000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 39 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Hamming(7,4) corrects any single-bit error but, like simple parity,
  cannot reliably handle two simultaneous errors (a double error can
  produce a nonzero syndrome that points to the *wrong* bit, silently
  making things worse) — this design implements the base single-error-
  correcting code only, without the extra overall parity bit that extended
  Hamming (SECDED) codes add to additionally *detect* (not correct) double
  errors.
* Both modules are pure combinational logic, no reset or clock.
* The specific bit-position-to-data-bit mapping (`{p1,p2,d1,p3,d2,d3,d4}`)
  follows the standard textbook convention; any consistent mapping between
  matching encoder/decoder pairs works equally well.

## 14. Common Mistakes

* Getting a parity bit's coverage group wrong — even one incorrect
  coverage bit breaks the "syndrome equals binary position" property for
  every codeword, not just some.
* Forgetting to correct parity-bit errors (only correcting when the
  syndrome points at a data position) — an error in a parity bit is just
  as real as one in a data bit and must still be handled so `error`/
  `syndrome` stay meaningful, even though it happens not to change
  `data_out` either way.
* Assuming this code can correct 2-bit errors — it cannot; correcting
  double errors needs a fundamentally different (stronger) code, and
  attempting it with a Hamming(7,4) syndrome silently "corrects" the wrong
  bit instead.

## 15. Possible Improvements

* Add the SECDED extension (one overall parity bit across all 7 code bits)
  to additionally *detect* (without attempting to correct) double-bit
  errors, distinguishing that case from a genuine single-bit error.
* Generalize to Hamming(15,11) or a parameterized Hamming(2^m-1, 2^m-1-m)
  code for a different data/parity ratio.

## 16. What This Program Teaches

* How a parity-check matrix's structure (coverage groups keyed to binary
  position numbers) makes the syndrome directly locate a single-bit error.
* The concrete difference between error *detection* (program 048's simple
  parity) and error *correction* (this program).
* Why correcting only "the positions that map to data" is not enough — a
  parity-bit error must be corrected too for the code's guarantees to hold
  consistently.

## 17. Industry Relevance

Hamming codes (and their SECDED extensions) are the standard error
correction used in ECC memory (DRAM, cache, and register files in
reliability-sensitive systems), providing single-bit error correction and
double-bit error detection with a modest parity overhead — the same
syndrome-based correction principle demonstrated here underlies all of
them.

## 18. How to Run

```bash
python3 scripts/run.py 061            # compile, simulate, synthesize, lint
cd 03-combinational-logic/061-hamming-7-4-codec && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/hamming74_encoder.v src/hamming74_decoder.v tb/tb_hamming74_codec.v
vvp build/sim.vvp +vcd
```
