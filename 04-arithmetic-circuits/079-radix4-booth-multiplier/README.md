# 079 — Radix-4 (Modified) Booth Multiplier

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Advanced | `booth_radix4_mult` | `src/booth_encoder.v`, `src/booth_radix4_mult.v` | `tb/tb_booth_radix4_mult.v` |

## 1. Objective

Cut the number of partial-product rows roughly in half (compared to
program 076's one-row-per-bit array multiplier) by examining the
multiplier two bits at a time and recoding each pair into a single
signed digit, using the modified (radix-4) Booth algorithm.

## 2. What the Design Does

`booth_radix4_mult` multiplies two `WIDTH`-bit signed numbers. It scans
`b` in overlapping 3-bit windows (`b[2k+1], b[2k], b[2k-1]`, with a
virtual `b[-1]=0`), and for each window `booth_encoder` decodes the
signed digit that window represents (`0, +-1, +-2`) into a magnitude
select (`x1`/`x2`) and sign (`neg`). Each group's row is then `0`, `+-a`
or `+-2a`, shifted to that group's weight and summed.

## 3. Why It Is Useful

An ordinary array multiplier needs one partial-product row per bit of the
multiplier. Radix-4 Booth recoding processes 2 bits per group, roughly
halving the row count (and therefore the reduction depth needed to sum
them) — the standard first step (often paired with Wallace-tree
reduction, program 078) toward a fast hardware multiplier.

## 4. Interface

**`booth_radix4_mult`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | `WIDTH`, signed | multiplicand |
| `b` | input | `WIDTH`, signed | multiplier |
| `product` | output | `2*WIDTH`, signed | `a * b`, exact |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 6 | operand width; must be even |

**`booth_encoder`**: `b2`, `b1`, `b0` in (one 3-bit window); `neg`, `x1`,
`x2` out.

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `bext` | `b`, sign-extended and padded with a virtual `b[-1]=0`, so every group's 3-bit window can be sliced uniformly |
| `neg[NGROUPS-1:0]`, `x1[...]`, `x2[...]` | per-group decode results from `booth_encoder` |
| `acc` | running signed accumulator (with headroom bits) summing every group's row |

## 6. Architecture

```
booth_encoder truth table (per 3-bit window b2 b1 b0):
  000 -> 0     001 -> +1    010 -> +1    011 -> +2
  100 -> -2    101 -> -1    110 -> -1    111 -> 0

for group k = 0 .. NGROUPS-1:
    row_k = x2[k] ? 2a : (x1[k] ? a : 0)
    row_k = neg[k] ? -row_k : row_k
    acc += row_k << (2k)

product = acc[2*WIDTH-1:0]
```
The 1-bit overlap between consecutive windows (`b[2k-1]` is also
`b[2(k-1)+1]`, the top bit of the group below) is what makes the local
2-bit-at-a-time recoding equal the true multi-bit value of `b` — this is
the defining trick of Booth's algorithm.

## 7. Module Hierarchy and Connections

```
booth_radix4_mult #(.WIDTH(N))
└── enc[0..NGROUPS-1] : booth_encoder (bext[2k+2:2k]) -> neg[k], x1[k], x2[k]
      (generate loop; row formation and summation happen behaviorally
       in the top module's always block)
```

## 8. Verilog Concepts Used

* A `case` statement in `booth_encoder` implementing the classic Booth
  radix-4 decode table directly.
* `signed` port declarations and `$signed()` casts so arithmetic shifts
  (`<<<`) and negation behave correctly on two's-complement values.
* A procedural `for` loop accumulating variable-shifted signed
  contributions, with explicit sign-extension via bit replication
  (`{{N{row_mag[WIDTH]}}, row_mag}`) chosen over relying on Verilog's
  implicit assignment-context sign extension, which is functionally
  identical but triggers a Verilator `WIDTHEXPAND` lint warning when left
  implicit.

## 9. Source Code Explanation

`booth_encoder` is a direct transcription of the modified Booth radix-4
truth table. `booth_radix4_mult` builds `bext` (sign-extended `b` with a
bottom-padded 0), instantiates one `booth_encoder` per group via a
`generate for` loop, then in a single combinational `always` block loops
over every group: computes that group's magnitude (`a` or `2a`, held in a
`WIDTH+1`-bit register — wide enough for `2a` at any operand value,
including the most-negative one), negates it if `neg[k]`, sign-extends it
to the accumulator's full width, shifts it left by `2k`, and adds it into
`acc`. The final `product` is simply `acc`'s low `2*WIDTH` bits — exact,
because a `WIDTH`-bit signed multiply always fits exactly in `2*WIDTH`
bits, so the extra headroom bits in `acc` are guaranteed to be redundant
sign-extension once the sum is complete.

## 10. Testbench Explanation

`tb_booth_radix4_mult` drives two DUT instances. `dut6` (`WIDTH=6`) is
checked exhaustively over all `64x64=4096` signed operand combinations.
`dut16` (`WIDTH=16`) is checked with 3000 random operand pairs plus four
directed corners (both most-negative, most-negative x most-positive, both
most-positive, and zero x most-negative). Both are compared against
Verilog's own signed `a*b`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | WIDTH=6 exhaustive | all 4096 signed `(a,b)` pairs | matches signed `a*b` |
| 2 | WIDTH=16 random | 3000 random signed pairs | matches signed `a*b` |
| 3 | WIDTH=16 most-negative corner | a=b=-32768 | product = 2^30 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 079` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_booth_radix4_mult` — **PASS**

```text
TEST PASSED: 7100 checks
tb/tb_booth_radix4_mult.v:77: $finish called at 7100000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 298 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `WIDTH` must be even for the `NGROUPS = (WIDTH+2)/2` group count to
  exactly cover all `WIDTH+1` extended bits with 2-bit-stride windows;
  this is a documented constraint of this implementation, not a general
  limitation of the Booth algorithm itself.
* Rows are summed behaviorally with Verilog `+`, not a hand-built
  compressor tree (unlike program 078) — the pedagogical focus here is
  Booth *recoding* (halving the row count), which program 078's
  Wallace-tree reduction technique could be applied to independently.

## 14. Common Mistakes

* Forgetting the 1-bit overlap between groups (using non-overlapping
  2-bit windows instead of the correct 3-bit overlapping ones) — without
  the overlap, the recoded digits do not actually sum to the true value
  of `b`.
* Under-sizing the register holding `2a` — the most-negative operand's
  double needs one more bit than the operand itself; `WIDTH+1` bits is
  the minimum that is always sufficient, and using only `WIDTH` bits
  would silently truncate that one corner case.
* Relying on implicit sign-extension in an assignment between
  differently-sized signed regs — correct in Verilog's semantics, but
  worth making explicit (as this program does) since some lint tools
  flag it and explicit code is easier to audit.

## 15. Possible Improvements

* Replace the behavioral row summation with a genuine Wallace-tree
  reduction (per program 078) to also cut the reduction depth, not just
  the row count.
* Support odd `WIDTH` by adjusting the group-count formula.

## 16. What This Program Teaches

* The modified (radix-4) Booth recoding algorithm and why the 1-bit
  window overlap is essential.
* Sizing intermediate signed registers correctly to avoid silently
  truncating the most-negative-operand corner case.

## 17. Industry Relevance

Booth recoding (radix-4, and higher radices such as radix-8) is standard
in real hardware multipliers, almost always paired with Wallace/Dadda
tree reduction (078) and a fast final adder (069-072) to build a complete
high-performance multiplier datapath.

## 18. How to Run

```bash
python3 scripts/run.py 079            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/079-radix4-booth-multiplier && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/booth_encoder.v src/booth_radix4_mult.v tb/tb_booth_radix4_mult.v
vvp build/sim.vvp +vcd
```
