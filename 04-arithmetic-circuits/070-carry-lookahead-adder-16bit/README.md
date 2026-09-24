# 070 — 16-bit Hierarchical Carry-Lookahead Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Advanced | `cla16` | `src/pg_cell.v`, `src/cla4_block.v`, `src/lookahead_unit.v`, `src/cla16.v` | `tb/tb_cla16.v` |

## 1. Objective

Scale carry-lookahead past the ~4-bit practical limit of program 069's
flat expansion by adding a second lookahead level: four 4-bit blocks each
do local lookahead, and a separate unit does lookahead *across* blocks
using their group propagate/generate signals.

## 2. What the Design Does

`cla16` adds two 16-bit numbers and a `cin`. It splits the operands into
four 4-bit blocks (`cla4_block`), each of which computes its own sum from
a block-local carry-in using the same expanded-equation technique as
program 069, and additionally reports a group propagate `P` (would this
whole block pass a carry straight through) and group generate `G` (does
this block produce a carry on its own, regardless of what enters it). A
single `lookahead_unit` takes all four blocks' `P`/`G` and computes all
four blocks' carry-ins *in parallel*, using the same equation shape as
program 069's per-bit carries — just one level higher.

## 3. Why It Is Useful

A single flat lookahead expansion becomes impractical in gate fan-in well
before 16 bits. Treating a whole block as one generate/propagate unit and
repeating the lookahead trick one level up is the standard way real fast
adders scale to 32/64 bits without paying ripple-carry's linear delay.

## 4. Interface

**`cla16`** (top level)

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 16 | first operand |
| `b` | input | 16 | second operand |
| `cin` | input | 1 | carry in |
| `sum` | output | 16 | `a + b + cin`, low 16 bits |
| `carry_out` | output | 1 | final carry out |

**`pg_cell`**: `a`, `b` in; `p`, `g` out (1 bit each).

**`cla4_block`**: `a[3:0]`, `b[3:0]`, `cin` in; `sum[3:0]`, `p_group`,
`g_group` out.

**`lookahead_unit`**: `p_group[3:0]`, `g_group[3:0]`, `cin` in;
`block_cin[3:0]`, `carry_out` out.

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `p_group[3:0]` | 4 | each block's group propagate, one bit per block |
| `g_group[3:0]` | 4 | each block's group generate, one bit per block |
| `block_cin[3:0]` | 4 | carry into each of the four blocks, from `lookahead_unit` |

## 6. Architecture

```
             +----- lookahead_unit -----+
             | computes block_cin[0..3] |
             | and carry_out from       |
             | p_group/g_group and cin  |
             +---------------------------+
                 |block_cin[i] feeds cla4_block[i].cin
   a[3:0],b[3:0]   a[7:4],b[7:4]   a[11:8],b[11:8]  a[15:12],b[15:12]
        |               |                |                  |
   cla4_block[0]   cla4_block[1]    cla4_block[2]      cla4_block[3]
        |               |                |                  |
    sum[3:0]         sum[7:4]        sum[11:8]          sum[15:12]

Each cla4_block also emits p_group[i]/g_group[i] up to lookahead_unit.
```
Within each block, bits still use the flat per-bit lookahead from program
069. Across blocks, `lookahead_unit` applies the identical equation
pattern one level up, treating each block's `(p_group, g_group)` exactly
like a single bit's `(p, g)` — the recursive structure of lookahead
generalizes cleanly to any number of levels.

## 7. Module Hierarchy and Connections

```
cla16
├── blk0 : cla4_block (a[3:0],   b[3:0],   block_cin[0]) -> sum[3:0],   p_group[0], g_group[0]
├── blk1 : cla4_block (a[7:4],   b[7:4],   block_cin[1]) -> sum[7:4],   p_group[1], g_group[1]
├── blk2 : cla4_block (a[11:8],  b[11:8],  block_cin[2]) -> sum[11:8],  p_group[2], g_group[2]
├── blk3 : cla4_block (a[15:12], b[15:12], block_cin[3]) -> sum[15:12], p_group[3], g_group[3]
│     each cla4_block instantiates 4x pg_cell internally (generate loop)
└── lu   : lookahead_unit (p_group, g_group, cin) -> block_cin, carry_out
```

## 8. Verilog Concepts Used

* Two-level hierarchical structural design: the same generate/propagate
  recursion applied at bit level (inside `cla4_block`) and at block level
  (inside `lookahead_unit`).
* `generate for` inside `cla4_block` to instantiate its four `pg_cell`s.
* Named generate block labels avoiding reserved-word collisions (a
  block-label or instance named `bit` or `cell` is rejected by Icarus
  Verilog / Verilator as a reserved keyword — this program's generate
  block is named `pg` and its instance `pgc` for exactly that reason).

## 9. Source Code Explanation

`pg_cell` is the same one-line `p`/`g` cell used per bit. `cla4_block`
instantiates four of them, computes its four internal carries with the
flat sum-of-products equations from program 069 (using its own `cin`
input rather than a hardwired 0), and additionally computes `p_group`
(AND of all four bit-propagates — the whole block passes a carry through
only if every bit does) and `g_group` (does the block generate a carry
even with no carry-in, by the same expanded OR-of-ANDs shape as a single
bit's carry equation, one level up). `lookahead_unit` takes four blocks'
`p_group`/`g_group` and computes `block_cin[0..3]` plus the final
`carry_out`, using literally the same equation shape as `cla4_block`'s
internal carries — substitute "block" for "bit" throughout. `cla16` wires
`lookahead_unit`'s `block_cin[i]` into `cla4_block[i]`'s `cin`, so every
block's carry-in is available immediately from the top-level `cin` and
group P/G signals, without waiting on any block below it.

## 10. Testbench Explanation

`tb_cla16` drives 2000 `$random` `(a,b,cin)` triples plus six directed
corner cases (all-zero, an all-ones addend forcing a full propagate
chain, both operands all-ones, MSB-only overflow, and two nibble-boundary
ripple cases), comparing `{carry_out,sum}` against a 17-bit Verilog
reference `a+b+cin` after each stimulus.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | random | 2000 random `(a,b,cin)` | matches `a+b+cin` |
| 2 | zero | 0+0+0 | sum=0, carry_out=0 |
| 3 | full propagate chain | 0xFFFF + 0x0000 + 1 | sum=0x0000, carry_out=1 |
| 4 | maximum generate | 0xFFFF + 0xFFFF + 1 | sum=0xFFFF, carry_out=1 |
| 5 | nibble-boundary ripple | 0x0FFF + 0x0001 | carry correctly crosses block boundary |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 070` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_cla16` — **PASS**

```text
TEST PASSED: 2006 checks
tb/tb_cla16.v:53: $finish called at 2006000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 175 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Two lookahead levels keep gate fan-in bounded (at most 5-input gates)
  while still avoiding ripple delay between blocks; a 64-bit adder would
  typically add a third level rather than flattening further.
* Purely combinational; no reset/clock.
* `cla4_block` reuses program 069's carry-equation *shape* but is a
  distinct, self-contained file per this repository's convention
  (decision 8 in `PROJECT_STATUS.md`) — it is not a copy-paste of
  `cla4.v`, since it additionally must expose group P/G and accept an
  external block carry-in.

## 14. Common Mistakes

* Naming a generate block or instance `bit` or `cell` — both are reserved
  words in at least one of the toolchains used here (Verilator rejected
  `cell`, and `bit` is a SystemVerilog type keyword some tools also
  reject even in Verilog-2005 mode); this was caught and fixed during
  development of this program.
* Computing `g_group` as a plain AND of the four bit-generates instead of
  the full OR-of-ANDs expansion — a block can generate a carry even if
  not every bit does, as long as a carry generated partway through
  propagates to the top of the block.

## 15. Possible Improvements

* Extend to a third lookahead level for 64-bit width, or generalize
  `cla4_block`/`lookahead_unit` with a `WIDTH`/`BLOCKS` parameter.

## 16. What This Program Teaches

* How carry-lookahead generalizes hierarchically: the same
  generate/propagate recursion, one level up, using group signals instead
  of bit signals.
* Structuring a design into levels that mirror the mathematical
  recursion, rather than one large flat module.

## 17. Industry Relevance

Hierarchical (multi-level) carry-lookahead is the textbook technique
behind historically fast ALU adders; real silicon today often uses
related but distinct structures (e.g. Kogge-Stone, Brent-Kung parallel
prefix trees) that solve the same underlying problem — computing all
carries in logarithmic depth — with different circuit topologies.

## 18. How to Run

```bash
python3 scripts/run.py 070            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/070-carry-lookahead-adder-16bit && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/pg_cell.v src/cla4_block.v src/lookahead_unit.v src/cla16.v tb/tb_cla16.v
vvp build/sim.vvp +vcd
```
