# 103 — LFSR Pseudo-Random Generator (Fibonacci vs. Galois)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Intermediate | (none — two independent modules) | `src/lfsr_fibonacci.v`, `src/lfsr_galois.v` | `tb/tb_lfsr.v` |

## 1. Objective

Build a maximal-length linear feedback shift register two structurally
different ways — Fibonacci (external feedback) and Galois (internal
feedback) — using the same underlying polynomial, and confirm both
visit every nonzero state exactly once before repeating.

## 2. What the Design Does

Both modules are 8-bit shift registers implementing the primitive
polynomial `x^8 + x^6 + x^5 + x^4 + 1`. `lfsr_fibonacci` shifts left and
XORs four tap bits together into one external feedback bit that enters
at the LSB. `lfsr_galois` shifts right and, only when the bit shifting
out is 1, additionally XORs a fixed tap mask into the whole register.
Both produce the identical 255-state cycle (the "randomness"), just
via different internal wiring.

## 3. Why It Is Useful

LFSRs are the cheapest hardware source of a long, deterministic,
seemingly-random bit sequence — used for pseudo-random test pattern
generation (BIST, program 152), scrambling (program 187), and simple
CRC computation (program 183). Comparing Fibonacci and Galois forms of
the *same* polynomial shows they are two implementations of one
mathematical object, not two different generators.

## 4. Interface

**`lfsr_fibonacci`** / **`lfsr_galois`**: `clk`, `rst_n` in; `q[WIDTH-1:0]`
out. Parameters: `WIDTH` (default 8).

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| (Fibonacci) `feedback` | XOR of taps 8,6,5,4 (bits 7,5,4,3), fed into the LSB each shift |
| (Galois) `TAP_MASK` | `8'hB8`, XORed into the whole register only when the shifted-out bit is 1 |

## 6. Architecture

```
Fibonacci: feedback = state[7]^state[5]^state[4]^state[3]
           state <= {state[6:0], feedback}       (shift left)

Galois:    state <= state[0] ? ((state>>1) ^ 8'hB8) : (state>>1)   (shift right)
```
Both reset to the nonzero seed `8'h01` — `0` is the one state a
XOR-feedback LFSR cannot escape (every tap XORs to 0, so feedback stays
0 forever), which is why a nonzero seed is essential rather than the
usual all-zero reset value.

## 7. Module Hierarchy and Connections

Two independent single-module designs, both instantiated side by side
in the testbench.

## 8. Verilog Concepts Used

* External (Fibonacci) vs. internal (Galois) feedback structures for the
  same polynomial, and the classic Galois bit-trick formula
  `(state>>1) ^ (mask if lsb else 0)`.
* A `localparam` fixed tap mask derived from a specific, named,
  maximal-length polynomial rather than an arbitrary constant.

## 9. Source Code Explanation

See §6. The Fibonacci form concentrates all its XOR logic into one
external feedback signal computed from specific tap bits; the Galois
form spreads the same polynomial's effect across the register by
conditionally XORing a fixed mask in as part of every shift — this
distribution is what typically gives Galois-form LFSRs a shorter
critical path (and hence higher achievable clock rate) in real hardware,
despite computing the same sequence.

## 10. Testbench Explanation

`tb_lfsr` runs both LFSRs for exactly 255 cycles from their shared
`8'h01` seed, using a 256-entry "visited" bitmap per LFSR to catch two
failure modes at once: landing on the locked all-zero state, or
repeating any state before all 255 nonzero states have been seen. It
finally checks both LFSRs are back at the seed value at cycle 255,
confirming the full maximal-length period.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | no lock-up | 255 cycles from seed | all-zero state never reached |
| 2 | maximal period | 255 cycles from seed | every nonzero state visited exactly once |
| 3 | period exactness | cycle 255 | state returns exactly to the seed |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 103` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_lfsr` — **PASS**

```text
TEST PASSED: 513 checks
tb/tb_lfsr.v:89: $finish called at 2556000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 22 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The tap positions `[8,6,5,4]` are a specific, well-known
  maximal-length polynomial for an 8-bit LFSR, not an arbitrary choice —
  most tap sets do *not* produce a maximal-length sequence, and getting
  them wrong produces a shorter cycle instead (still deterministic, but
  visiting fewer than all 255 states) — exactly what this program's
  exhaustive period check is designed to catch.
* This is a *pseudo*-random generator: fully deterministic and
  repeatable from a given seed, useful for reproducible test patterns,
  not for anything requiring cryptographic unpredictability.

## 14. Common Mistakes

* Resetting to the all-zero state — with pure XOR feedback (not XNOR),
  all-zero is a fixed point the LFSR can never leave.
* Choosing tap positions that don't correspond to a primitive polynomial
  — produces a valid-looking but non-maximal-length LFSR whose period is
  some proper divisor of `2^WIDTH-1`, easy to miss without an exhaustive
  period check like this program's.

## 15. Possible Improvements

* Parameterize the tap set for other primitive polynomials/widths and
  verify each one's maximal-length property the same way.

## 16. What This Program Teaches

* Two structurally different but mathematically equivalent LFSR
  implementations of the same polynomial.
* Why seed choice matters for XOR-feedback LFSRs, and how to verify a
  claimed maximal-length property exhaustively.

## 17. Industry Relevance

LFSRs are used throughout real hardware for built-in self-test pattern
generation, data scrambling/whitening, and CRC computation — Galois-form
LFSRs specifically are preferred in high-speed designs for their shorter
feedback path.

## 18. How to Run

```bash
python3 scripts/run.py 103            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/103-lfsr-random-generator && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/lfsr_fibonacci.v src/lfsr_galois.v tb/tb_lfsr.v
vvp build/sim.vvp +vcd
```
