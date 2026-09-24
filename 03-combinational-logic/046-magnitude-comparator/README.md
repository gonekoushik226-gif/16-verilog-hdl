# 046 — Magnitude Comparator (4-bit, 7485-style)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | `comparator4` | `src/comparator1.v`, `src/comparator4.v` | `tb/tb_comparator4.v` |

## 1. Objective

Build a 4-bit magnitude comparator the way the classic 74LS85 does: as a
chain of identical 1-bit cells, each carrying a greater/less/equal decision
down to the next less-significant bit, and prove the cascade inputs let
several instances be chained for buses wider than 4 bits.

## 2. What the Design Does

`comparator4` compares two 4-bit buses `a` and `b` and drives exactly one of
`gt` (`a > b`), `lt` (`a < b`), `eq` (`a == b`). It also accepts external
cascade inputs `cin_gt`/`cin_lt`/`cin_eq`, the same three-wire "outcome so
far" convention used between its own internal cells; tying them to the idle
state (`cin_gt=0, cin_lt=0, cin_eq=1`) makes it a standalone 4-bit
comparator, while feeding a more-significant `comparator4`'s outputs into a
less-significant one's cascade inputs extends the comparison to 8, 12, 16...
bits, exactly as multiple 74LS85 packages are wired together.

## 3. Why It Is Useful

Magnitude comparison — not just equality — is needed for range checks,
sorting networks, priority arbitration and scheduler "which request is
oldest" logic. The cascade structure is the canonical example of building
a wide combinational function from small identical cells with an explicit
carry-like signal, the same pattern used later in this curriculum by
carry-lookahead adders and priority encoders.

## 4. Interface

**`comparator1`** (1-bit cell):

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 1 | bits being compared |
| `gt_in`, `lt_in`, `eq_in` | input | 1 | cascaded decision from the more-significant stage |
| `gt_out`, `lt_out`, `eq_out` | output | 1 | decision after including this bit |

**`comparator4`** (4-bit, top module):

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 4 | buses being compared |
| `cin_gt`, `cin_lt`, `cin_eq` | input | 1 | external cascade input (tie to `0,0,1` when unused) |
| `gt`, `lt`, `eq` | output | 1 | `a>b`, `a<b`, `a==b` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `g3,l3,e3` … `g1,l1,e1` | 1 each | inter-cell cascade wires between the four `comparator1` instances, bit 3 (MSB) down to bit 1 |

## 6. Architecture

```
cin_gt/lt/eq ──►┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
   a[3],b[3] ──►│ cell3  │─►│ cell2  │─►│ cell1  │─►│ cell0  │──► gt,lt,eq
                 └────────┘  └────────┘  └────────┘  └────────┘
                    ▲ a[3],b[3]  ▲ a[2],b[2]  ▲ a[1],b[1]  ▲ a[0],b[0]
```

Each `comparator1` cell only evaluates its own bit pair when `eq_in` is 1
(every more-significant bit compared equal so far); otherwise it passes the
incoming decision straight through, unchanged, to `gt_out`/`lt_out`.

## 7. Module Hierarchy and Connections

```
tb_comparator4
├── dut         : comparator4                (exhaustive 4-bit test)
├── stage_hi     : comparator4  (cascade idle)  ┐ directed 8-bit
└── stage_lo     : comparator4  (cascade = stage_hi's outputs) ┘ cascade test

comparator4
└── cell3, cell2, cell1, cell0 : comparator1 (chained MSB → LSB)
```

## 8. Verilog Concepts Used

* A per-bit cascade signal group (`gt/lt/eq`) instead of a single carry bit,
  because three mutually-exclusive outcomes (not two) must propagate.
* Structural instantiation of four identical cells with distinct
  per-instance port connections (no `generate`, to keep the 7485 stage
  order explicit and readable).
* A combinational `always @(*)` per cell with every output defaulted in
  every branch (no inferred latches).
* Cascading complete modules (two `comparator4` instances) to build a wider
  function, verified against `>`, `<`, `==` operators as the reference model.

## 9. Source Code Explanation

`comparator1`:

```verilog
if (eq_in) begin
    if (a & ~b)      begin gt_out=1'b1; lt_out=1'b0; eq_out=1'b0; end
    else if (~a & b) begin gt_out=1'b0; lt_out=1'b1; eq_out=1'b0; end
    else              begin gt_out=1'b0; lt_out=1'b0; eq_out=1'b1; end
end else begin
    gt_out = gt_in; lt_out = lt_in; eq_out = 1'b0;
end
```

* `eq_in` is the key gate: it is 1 only when every bit compared so far
  (from the more-significant cells) was equal. Only then may this cell's
  own bits change the outcome.
* If `eq_in` is 0, a more-significant bit has already decided `gt` or `lt`;
  this cell must not let its own (less-significant) bits overturn that —
  the first version of this design skipped this gate and let the least
  significant bit override an already-decided comparison, which the
  testbench's exhaustive sweep caught immediately (e.g. `a=1,b=2` was
  reported as `a>b`).
* `comparator4` instantiates four `comparator1` cells and wires bit 3 first
  (seeded by the external cascade inputs) down to bit 0 last, so `gt`/`lt`/
  `eq` reflect the full 4-bit comparison after the chain settles.

## 10. Testbench Explanation

`tb_comparator4` has two parts:

1. **Exhaustive 4-bit sweep**: all `16 × 16 = 256` `(a,b)` pairs are applied
   to a standalone `dut` (cascade tied idle) and checked against `>`, `<`,
   `==` on the plain integers.
2. **Directed 8-bit cascade test**: two `comparator4` instances (`stage_hi`,
   `stage_lo`) are wired exactly as two 74LS85 packages would be, forming
   an 8-bit comparator. Besides several hand-picked corner cases (all-zero,
   all-one, MSB-only differences), every pair whose high nibble is `5`
   (equal) is swept so the low-nibble comparison — gated entirely by the
   cascade — must decide every one of those 256 outcomes.

Both parts share `errors`/`checks` counters and the project's standard
`ERROR:`/`TEST PASSED`/`TEST FAILED` reporting.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive 4-bit | all 256 `(a,b)` pairs | `gt/lt/eq` matches `>`,`<`,`==` |
| 2 | Cascade corners | `0x00/0xFF`, `0x7F/0x80`, `0x55/0xAA` | 8-bit comparator agrees with integer compare |
| 3 | Cascade decides | high nibble equal (`0x5_`/`0x5_`), all 256 low-nibble pairs | low-stage comparison, via cascade, sets the final outcome |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 046` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_comparator4` — **PASS**

```text
exhaustive 4-bit comparator sweep (256 pairs)...
  done: 256 checks, errors so far: 0
directed 8-bit cascade test...
  done: 521 checks total, errors so far: 0
TEST PASSED: 521 checks
tb/tb_comparator4.v:105: $finish called at 521000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 24 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The cascade convention (`gt`,`lt`,`eq` as three mutually-exclusive wires
  rather than a 2-bit code) matches the 74LS85 datasheet directly, at the
  cost of one extra wire compared to a `signed 2-bit` encoding.
* `eq_out` is only ever 1 when the entire comparison (from the seeded
  cascade input down through this bit) has been equal; a cell that decides
  `gt`/`lt` always drives `eq_out = 0`, so exactly one of the three outputs
  is high at the top of the chain.
* No reset or clock: purely combinational, so `#1` settling delay is enough
  in the testbench for the chain to resolve.

## 14. Common Mistakes

* Letting a less-significant bit's own comparison override a
  more-significant bit's already-decided outcome — the exact bug found and
  fixed during this program's development (§9); the fix is gating every
  bit's own comparison on `eq_in`, not just deferring to it when the bits
  happen to match.
* Forgetting to tie unused cascade inputs to the idle state
  (`cin_gt=0,cin_lt=0,cin_eq=1`) on a standalone instance — leaving them
  floating or wrongly tied (e.g. `cin_eq=0`) forces the comparator to always
  report "not equal" regardless of `a` and `b`.
* Assuming `gt`, `lt`, and `eq` need separate priority logic to be made
  mutually exclusive — the per-cell structure already guarantees this by
  construction.

## 15. Possible Improvements

* Add an explicit `ge`/`le` output pair (common on real comparator ICs)
  derived combinationally from `gt`/`eq` and `lt`/`eq`.
* Generate the four-cell chain with a `generate for` loop parameterized on
  width, as done by the parameterized comparator in the next program.

## 16. What This Program Teaches

* Building a multi-bit combinational function from a chain of identical
  1-bit cells with an explicit cascade signal.
* Why a cascade signal must gate a cell's own decision, not just seed its
  default — verified the hard way via a real, caught bug.
* Chaining complete modules (not just gates) to extend a design beyond its
  native width, mirroring real multi-package cascading.

## 17. Industry Relevance

The 74LS85 cascading comparator is a textbook TTL part; the same
gt/lt/eq-with-cascade pattern appears inside modern arbiters, sorting
networks and scheduler priority logic wherever a wide comparison is built
from narrower, reusable comparison stages.

## 18. How to Run

```bash
python3 scripts/run.py 046            # compile, simulate, synthesize, lint
cd 03-combinational-logic/046-magnitude-comparator && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/comparator1.v src/comparator4.v tb/tb_comparator4.v
vvp build/sim.vvp +vcd
```
