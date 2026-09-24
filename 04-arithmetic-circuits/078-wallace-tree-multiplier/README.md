# 078 — Wallace-Tree Multiplier

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Advanced | `wallace_mult4` | `src/half_adder.v`, `src/full_adder.v`, `src/wallace_mult4.v` | `tb/tb_wallace_mult4.v` |

## 1. Objective

Replace program 076's sequential adder chain with a genuinely parallel
carry-save reduction: compress all 16 partial products, column by
column, down to two rows using 3:2 compressors, and combine those two
rows with a single final carry-propagate adder (CPA).

## 2. What the Design Does

`wallace_mult4` forms the same 16 AND partial products as program 076
(`pp_i_j = a[i] & b[j]`, at weight `i+j`), but instead of adding them one
row at a time, reduces each same-weight column in parallel across three
compression stages until every column holds at most 2 bits, then adds
the final two rows with one carry-propagate adder.

## 3. Why It Is Useful

Program 076's design pays a full ripple-adder delay three times in
sequence (one per extra row folded in). A Wallace tree instead reduces
*height*, not width: every compression stage runs in parallel across all
columns, so the number of sequential full-adder delays grows only
logarithmically with the number of partial-product rows, not linearly —
this is the technique program 073's carry-save adder generalizes to more
operands, and the one real multipliers actually use.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 4 | multiplicand (unsigned) |
| `b` | input | 4 | multiplier (unsigned) |
| `product` | output | 8 | `a * b`, exact |

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `pp_i_j` (16 wires) | the 16 AND partial products, named by row/column |
| `s2_1,c2_1` .. `s4_3,c4_3` | sum/carry outputs of each of the 6 compressor full adders, named by (column, stage) |
| `row_a[6:0]`, `row_b[6:0]` | the two rows remaining after reduction, ready for the final CPA |

## 6. Architecture

Column bit-counts before reduction (by weight, 0-6): `1,2,3,4,3,2,1`.
Three compression stages bring every column down to height ≤ 2:

```
stage 1: compress w2(3->1+carry), w3's first 3 of 4 bits(->1+carry), w4(3->1+carry)
stage 2: compress w3(3->1+carry), w5(3->1+carry)
stage 3: compress w4(3->1+carry)

after stage 3, column heights: 1,2,1,1,1,2,2  (all <= 2)
```
Each compression step is one `full_adder` used as a 3:2 compressor
(three same-weight bits in, a sum bit that stays in the column and a
carry bit that moves to the next column up). The full stage-by-stage bit
bookkeeping is written out in `wallace_mult4.v`'s comments exactly as
derived, so the wiring can be checked column by column against the
comments.

## 7. Module Hierarchy and Connections

```
wallace_mult4
├── fa1..fa6 : full_adder   (6 compressor cells across 3 reduction stages)
├── ha0      : half_adder   (bit 0 of the final CPA — row_b[0] is always 0)
└── cpa[1..6]: full_adder   (generate loop, bits 1-6 of the final CPA)
```

## 8. Verilog Concepts Used

* Named individual signals for every partial product and every
  compressor sum/carry, documented stage by stage in comments — chosen
  over a generic looped reduction because a fixed, explicitly-derived
  wiring is much easier to verify by hand (and was checked by hand,
  column by column, before being coded) than a general algorithm that
  would need to dynamically group an arbitrary number of same-weight
  bits.
* A `generate for` loop only for the final CPA, where the pattern really
  is uniform bit-to-bit.

## 9. Source Code Explanation

See the architecture in §6 and the stage-by-stage comments in
`wallace_mult4.v`, which mirror each other exactly: every compressor
instance's inputs/outputs are named after the column and stage they
belong to (e.g. `s3_2`/`c3_2` = column 3's stage-2 compressor outputs),
so the RTL can be read as a direct transcription of the derivation.

## 10. Testbench Explanation

`tb_wallace_mult4` exhaustively drives all 256 combinations of 4-bit `a`
and `b`, comparing `product` against Verilog's own `a*b` — identical
methodology to program 076, so the two multiplier architectures can be
directly compared for correctness.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | all 256 `(a,b)` combinations | `product == a*b` |
| 2 | maximum | a=15,b=15 | product=225 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 078` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_wallace_mult4` — **PASS**

```text
TEST PASSED: 256 checks
tb/tb_wallace_mult4.v:44: $finish called at 256000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 102 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This fixed, hand-derived wiring is specific to a 4x4 multiplier; a
  parameterized Wallace tree for arbitrary width would need a genuinely
  algorithmic column-reduction procedure (commonly implemented with a
  queue-based or recursive reduction pass), which is a substantially
  larger undertaking left as a possible improvement.
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Losing track of which column a compressor's carry output belongs to —
  every carry moves exactly one column higher than the compressor that
  produced it, never staying in the same column.
* Forgetting a "leftover" bit that didn't fit into a group of 3 during a
  stage (e.g. column 3's 4th bit `pp_3_0` in stage 1) — it must still
  carry forward into the next stage even though it wasn't part of that
  stage's compressor.

## 15. Possible Improvements

* Generalize to a parameterized-width Wallace tree using an algorithmic
  reduction pass instead of hand-derived fixed wiring.
* Compare synthesized cell/depth counts against program 076's array
  multiplier to make the depth-reduction concrete.

## 16. What This Program Teaches

* The Wallace-tree reduction principle: compress column height in
  parallel rather than adding rows sequentially.
* How to derive and verify a fixed compressor-tree wiring by hand,
  tracking exactly which bit goes where through multiple stages.

## 17. Industry Relevance

Wallace-tree (and the closely related Dadda) reduction is the standard
technique inside virtually every high-performance hardware multiplier,
almost always combined with Booth recoding (program 079) to also reduce
the *number* of partial-product rows needing reduction in the first
place.

## 18. How to Run

```bash
python3 scripts/run.py 078            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/078-wallace-tree-multiplier && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/half_adder.v src/full_adder.v src/wallace_mult4.v tb/tb_wallace_mult4.v
vvp build/sim.vvp +vcd
```
