# 076 — 4x4 Array Multiplier

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `array_multiplier4` | `src/half_adder.v`, `src/full_adder.v`, `src/array_multiplier4.v` | `tb/tb_array_multiplier4.v` |

## 1. Objective

Build the first multiplier in this category: form partial products with
AND gates, then sum them with an array of adder cells — the standard
"array multiplier" structure every faster multiplier (077-079) refines.

## 2. What the Design Does

`array_multiplier4` multiplies two 4-bit unsigned numbers into an 8-bit
product. It forms four partial-product rows (`a` masked and shifted by
each bit of `b`) and sums all four with three sequential 8-bit adder
stages, each built from half/full adder cells.

## 3. Why It Is Useful

Unsigned multiplication is `sum_i (b_i * a * 2^i)` — a shift-and-add
computed entirely with combinational logic. This program makes that
structure explicit and physically visible in the RTL, as the foundation
for signed (077), carry-save-reduced (078) and Booth-recoded (079)
multipliers later in this category.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 4 | multiplicand (unsigned) |
| `b` | input | 4 | multiplier (unsigned) |
| `product` | output | 8 | `a * b`, always exact (max 15×15=225 fits in 8 bits) |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `pp0..pp3` | 8 each | four partial-product rows, `a` masked by `b[i]` and pre-shifted to weight `i` |
| `sum1`, `sum2` | 8 each | running totals after each addition stage |
| `carry1..carry3` | 8 each | per-stage internal adder carry chains |

## 6. Architecture

```
pp0 = b[0] ? a       : 0
pp1 = b[1] ? a << 1  : 0
pp2 = b[2] ? a << 2  : 0
pp3 = b[3] ? a << 3  : 0

sum1 = pp0 + pp1     (8-bit adder: half adder bit0, full adders bits 1-7)
sum2 = sum1 + pp2    (same adder shape)
product = sum2 + pp3 (same adder shape)
```
Three adder stages, not four, since the first row (`pp0`) needs no
addition of its own — it is simply the first operand into stage 1.

## 7. Module Hierarchy and Connections

```
array_multiplier4
├── stage1[0..7] : half_adder (bit 0) / full_adder (bits 1-7)  -- sum1 = pp0+pp1
├── stage2[0..7] : half_adder (bit 0) / full_adder (bits 1-7)  -- sum2 = sum1+pp2
└── stage3[0..7] : half_adder (bit 0) / full_adder (bits 1-7)  -- product = sum2+pp3
      (three separate generate loops in one module, each instantiating
       its own 8 adder cells)
```

## 8. Verilog Concepts Used

* A `generate for` loop containing a `generate if`/`else` to pick a
  `half_adder` for the carry-less bit 0 and a `full_adder` for the
  carry-chained bits 1-7, three times over (one per addition stage).
* Bit masking with the ternary operator (`b[i] ? a<<i : 0`) to form each
  partial-product row.

## 9. Source Code Explanation

```verilog
wire [7:0] pp1 = b[1] ? {3'b000, a, 1'b0} : 8'b0;
...
generate
    for (i = 0; i < 8; i = i + 1) begin : stage1
        if (i == 0)
            half_adder ha (.a(pp0[0]), .b(pp1[0]), .sum(sum1[0]), .carry(carry1[0]));
        else
            full_adder fa (.a(pp0[i]), .b(pp1[i]), .cin(carry1[i-1]),
                            .sum(sum1[i]), .carry_out(carry1[i]));
    end
endgenerate
```
Each partial-product row is pre-shifted into an 8-bit field so ordinary
same-width addition correctly aligns every bit's weight. Bit 0 of every
stage genuinely has no incoming carry, so it uses a `half_adder`; every
other bit chains the previous bit's carry through a `full_adder`,
exactly mirroring program 064's ripple-carry adder, repeated three times
to fold in each successive partial-product row.

## 10. Testbench Explanation

`tb_array_multiplier4` exhaustively drives all 256 combinations of 4-bit
`a` and `b`, comparing `product` against Verilog's own `a*b`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | all 256 `(a,b)` combinations | `product == a*b` |
| 2 | maximum | a=15,b=15 | product=225 |
| 3 | zero operand | a=0 or b=0 | product=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 076` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_array_multiplier4` — **PASS**

```text
TEST PASSED: 256 checks
tb/tb_array_multiplier4.v:44: $finish called at 256000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 169 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This "array" is a linear chain of three full-width adder stages, not a
  true 2-D systolic diagonal array — simpler to derive correctly while
  still demonstrating the partial-product/adder-array structure; program
  078's Wallace tree shows a genuinely parallel reduction instead.
* Unsigned only; program 077 handles the signed case.

## 14. Common Mistakes

* Forgetting to pre-shift each partial-product row before adding —
  without the shift, every row would be added at the same bit weight,
  computing `4*a` instead of `a*b`.
* Using a `full_adder` with `cin` tied to 0 everywhere instead of a
  `half_adder` at bit 0 — functionally identical, but misses the point
  that bit 0 genuinely has no carry to chain.

## 15. Possible Improvements

* Extend to a signed version (program 077), or restructure as a true
  carry-save reduction tree (program 078) to cut the critical path from
  three sequential adds down to two (one reduction pass, one final add).

## 16. What This Program Teaches

* The shift-and-add structure of unsigned binary multiplication.
* Building a multi-stage adder network from single-bit cells, reusing the
  same half/full-adder building blocks as the adder programs earlier in
  this category.

## 17. Industry Relevance

Array multipliers are simple and regular in layout, making them a
reasonable choice for small, non-timing-critical multiplies; wider or
faster multipliers in real designs almost always use carry-save reduction
trees (078) or Booth recoding (079) instead, both of which this program's
partial-product formulation directly leads into.

## 18. How to Run

```bash
python3 scripts/run.py 076            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/076-array-multiplier-4x4 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/half_adder.v src/full_adder.v src/array_multiplier4.v tb/tb_array_multiplier4.v
vvp build/sim.vvp +vcd
```
