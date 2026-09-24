# 059 — Triple Modular Redundancy (TMR) Majority Voter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | `tmr_voter` | `src/tmr_voter.v` | `tb/tb_tmr_voter.v` |

## 1. Objective

Implement a per-bit 2-of-3 majority voter for triple modular redundancy,
and demonstrate by fault injection exactly what it guarantees (masking any
single copy's fault) and exactly where that guarantee breaks down (two
copies faulted identically).

## 2. What the Design Does

`tmr_voter` takes three `WIDTH`-bit copies (`a`, `b`, `c`) of what should
be the same signal and outputs their bitwise 2-of-3 majority `voted`: for
each bit position, the output is 1 whenever at least two of the three
input bits are 1. `disagree` reports whenever the three copies were not
bit-for-bit identical, independent of whether the majority vote still
produced the correct result.

## 3. Why It Is Useful

TMR is the standard fault-tolerance technique for masking a single
malfunctioning copy of a signal — three redundant instances of the same
logic (or three redundant sensor readings, or three redundant memory
copies) are voted together so that any one wrong copy is outvoted by the
other two. It is used in radiation-hardened and safety-critical designs
(aerospace, automotive, industrial control) where a single-point fault
must not propagate.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b`, `c` | input | `WIDTH` | three redundant copies of the same signal |
| `voted` | output | `WIDTH` | bitwise 2-of-3 majority of `a`, `b`, `c` |
| `disagree` | output | 1 | 1 when any bit position of the three copies is not unanimous |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | width of each redundant copy |

## 5. Internal Signals

None — both outputs are a direct function of the three inputs.

## 6. Architecture

```
a,b,c[i] ──► majority(a[i],b[i],c[i]) ──► voted[i]     (per bit, i = 0..WIDTH-1)

disagree = OR over all i of (a[i] != b[i] != c[i] not all equal)
```

## 7. Module Hierarchy and Connections

```
tb_tmr_voter
└── dut : tmr_voter #(.WIDTH(8))
```

## 8. Verilog Concepts Used

* The classic 2-of-3 majority Boolean function expressed directly as
  `(a&b)|(b&c)|(a&c)`, applied bitwise across a bus via plain bitwise
  operators (no per-bit loop needed).
* A reduction-OR (`|(...)`) collapsing a per-bit disagreement vector into
  a single flag.
* Fault-injection testbench methodology: deliberately corrupting one or
  two of the three input copies and checking both the expected masked
  result and the expected *unmaskable* result, rather than only exercising
  the fault-free path.

## 9. Source Code Explanation

```verilog
assign voted = (a & b) | (b & c) | (a & c);
assign disagree = |((a ^ b) | (b ^ c) | (a ^ c));
```
* `voted[i]` is 1 exactly when at least two of `a[i]`, `b[i]`, `c[i]` are
  1: each of the three AND terms catches one pair agreeing on 1, and OR-ing
  them together covers every way a majority-of-1 can occur — this is the
  standard 2-of-3 majority gate, applied bitwise for free by using bitwise
  (not reduction) operators on the full-width buses.
* `(a^b)|(b^c)|(a^c)` is nonzero at bit `i` whenever not all three inputs
  agree at that bit (any pairwise difference sets it); the outer reduction
  OR (`|(...)`) then collapses that per-bit vector down to a single
  `disagree` bit that is 1 if *any* bit position anywhere in the word was
  not unanimous, even if `voted` still came out correct there.

## 10. Testbench Explanation

`tb_tmr_voter` builds up three fault scenarios:

1. **No fault**: `a = b = c = golden` for directed (`0x00`, `0xFF`, `0xAA`,
   `0x55`) and 200 random golden values — `voted` must equal `golden`
   exactly and `disagree` must be 0.
2. **Single-copy fault**: for 20 golden values (2 directed, 18 random),
   every one of the 3 copies, and every one of the `WIDTH` bit positions,
   `check_single_fault` flips exactly that one bit in exactly one copy and
   confirms `voted` still equals the untouched `golden` (the fault is
   fully masked) while `disagree` correctly reports 1.
3. **Double-copy fault, same bit**: for the same 20 golden values, every
   pair of the 3 copies, and every bit position, `check_double_fault_same_bit`
   flips the *same* bit position in *two* of the three copies. The two
   faulty copies now agree with each other on the wrong value and outvote
   the one remaining good copy, so `voted` is checked to differ from
   `golden` at exactly that bit — demonstrating TMR's fundamental limit,
   not a bug: two coincident faults at the same bit position are
   inherently unrecoverable by a 2-of-3 vote.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | No fault | `a=b=c=golden`, directed + 200 random | `voted=golden`, `disagree=0` |
| 2 | Single-copy fault | 1 bit flipped in 1 of 3 copies, all copies × all bits × 20 goldens | `voted=golden` (masked), `disagree=1` |
| 3 | Double-copy fault, same bit | 1 bit flipped identically in 2 of 3 copies, all pairs × all bits × 20 goldens | `voted` wrong at that bit (unmaskable), `disagree=1` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 059` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_tmr_voter` — **PASS**

```text
no-fault sweep: directed + random golden values...
  done: 204 checks, errors so far: 0
single-copy-fault sweep: every copy x every bit x directed/random goldens...
  done: 684 checks total, errors so far: 0
double-copy-fault (same bit) sweep: every copy pair x every bit x directed/random goldens...
  done: 1164 checks total, errors so far: 0
TEST PASSED: 1164 checks
tb/tb_tmr_voter.v:126: $finish called at 1164000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 87 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* TMR masks any single copy's arbitrary fault (stuck-at, transient bit
  flip, or full logic error) at every bit position, but cannot correct two
  copies that are simultaneously wrong in the same way — this is a
  structural limit of 2-of-3 voting, not something more logic in the voter
  itself can fix; higher redundancy (5-of-N, or a completely different
  error-correcting code) is needed for stronger fault models.
* `disagree` is useful even when `voted` is correct: it reports "one copy
  disagreed and was outvoted" as a health/diagnostic signal, distinct from
  "the voted output is wrong."
* Purely combinational, no reset or clock; this voter does not itself
  provide any fault *logging* or *latching* — a real safety-critical system
  would typically capture `disagree` into a sticky status register.

## 14. Common Mistakes

* Assuming TMR corrects any two simultaneous faults — it only corrects
  faults that remain a minority (at most one wrong copy per bit position);
  two copies wrong at the same bit position defeats the vote, exactly as
  this program's double-fault test demonstrates.
* Implementing the majority function with reduction operators
  (`&{a,b,c}` style) instead of the pairwise AND/OR form — reduction
  operators collapse a single vector's own bits together, not the
  bit-by-bit majority across three separate buses.
* Treating `disagree` as equivalent to "output is wrong" — as shown in
  test #2, `disagree` is 1 even when `voted` is still perfectly correct
  (single-copy fault, successfully masked).

## 15. Possible Improvements

* Add per-bit or per-copy fault-location reporting (which copy disagreed),
  useful for scheduling replacement/repair of the faulty module.
* Extend to N-modular redundancy with a parameterized `N`-of-`(2N+1)`
  voter for stronger fault tolerance at higher hardware cost.

## 16. What This Program Teaches

* The 2-of-3 majority function and its direct Boolean expression.
* Precisely what triple modular redundancy guarantees, demonstrated by
  fault injection rather than asserted in a comment.
* Why a diagnostic flag (`disagree`) and the corrected output (`voted`)
  are two genuinely different pieces of information a voter can provide.

## 17. Industry Relevance

TMR is standard practice in radiation-hardened space electronics,
safety-critical automotive and industrial controllers, and some
high-reliability FPGA configurations (triplicated flip-flops with voting
logic to mitigate single-event upsets); understanding its single-fault
guarantee and multi-fault limitation is essential to correctly specifying
where TMR is (and is not) sufficient.

## 18. How to Run

```bash
python3 scripts/run.py 059            # compile, simulate, synthesize, lint
cd 03-combinational-logic/059-majority-voter-tmr && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/tmr_voter.v tb/tb_tmr_voter.v
vvp build/sim.vvp +vcd +seed=42
```
