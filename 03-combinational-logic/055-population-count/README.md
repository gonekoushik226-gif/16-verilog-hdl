# 055 — Population Count (Adder Tree)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | `popcount` | `src/popcount.v` | `tb/tb_popcount.v` |

## 1. Objective

Count the number of 1 bits in a bus using a recursive adder tree, and
observe how this technique — unlike the leading-zero tree in the previous
program — does not require the input to split into exactly equal halves.

## 2. What the Design Does

`popcount` recursively splits its `WIDTH`-bit input into two halves, counts
the 1 bits of each half recursively, and adds the two partial counts
together. At the base case (`WIDTH == 1`), the count is simply that single
bit's value.

## 3. Why It Is Useful

Population count (also called Hamming weight) is used for error-correcting
code syndrome computation, checksum-like integrity checks, priority/request
counting in arbiters, and as a primitive in bit-manipulation-heavy
algorithms; many modern CPU ISAs provide a dedicated `popcount` instruction
for exactly this reason.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | bits to count |
| `count` | output | `$clog2(WIDTH+1)` | number of 1 bits in `data`, `0`–`WIDTH` |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | input width (any value ≥ 1, not restricted to powers of two) |

## 5. Internal Signals

Per recursion level: `count_hi`, `count_lo` — the partial population counts
of the upper and lower halves being added together.

## 6. Architecture

```
                      data[WIDTH-1:0]
                     /                \
          data[WIDTH-1:HALF]      data[HALF-1:0]
             (REM bits)             (HALF bits)
                  │                      │
            popcount(REM)          popcount(HALF)
                  │                      │
              count_hi                count_lo
                  └──────────┬───────────┘
                          count_hi + count_lo
```

## 7. Module Hierarchy and Connections

```
tb_popcount
├── dut8  : popcount #(.WIDTH(8))
└── dut32 : popcount #(.WIDTH(32))

popcount #(.WIDTH(W))                (for W > 1)
├── upper : popcount #(.WIDTH(W-W/2))  (recursive self-instantiation)
└── lower : popcount #(.WIDTH(W/2))
    ... down to WIDTH == 1 (base case)
```

## 8. Verilog Concepts Used

* Recursive module self-instantiation through `generate if`, as in the
  previous program's `lzc_tree`, but with an unequal split (`HALF =
  WIDTH/2`, `REM = WIDTH-HALF`) that still terminates correctly for any
  `WIDTH`, not only powers of two.
* Relying on Verilog's automatic operand-width extension for addition
  (`count_hi + count_lo`) instead of manually zero-extending each operand,
  since addition (unlike the previous program's conditional mux) naturally
  promotes both operands to the result's width.
* `$clog2` sizing each recursion level's own count output independently.

## 9. Source Code Explanation

```verilog
if (WIDTH == 1) begin : base
    assign count = data[0];
end else begin : recurse
    localparam HALF = WIDTH / 2;
    localparam REM  = WIDTH - HALF;
    ...
    popcount #(.WIDTH(REM))  upper (.data(data[WIDTH-1:HALF]), .count(count_hi));
    popcount #(.WIDTH(HALF)) lower (.data(data[HALF-1:0]),     .count(count_lo));
    assign count = count_hi + count_lo;
end
```
* The base case directly returns the single bit's own value (0 or 1) as
  its "count".
* Each recursive case splits its input into an upper (`REM` bits) and
  lower (`HALF` bits) half — sized so `REM + HALF == WIDTH` exactly for
  any `WIDTH`, including odd values — counts each independently, and adds
  the two results. Addition is commutative and has no notion of bit
  position, so the split does not need to be symmetric the way the
  leading-zero tree's did.

## 10. Testbench Explanation

`tb_popcount` checks two widths against a flat bit-summation reference
model (`for` loop over every bit, `exp = exp + d[b]`) — a structurally
different, non-recursive computation from the RTL's adder tree:

1. **`WIDTH=8`, exhaustive**: all 256 values.
2. **`WIDTH=32`, directed**: all-zero (`count=0`), all-ones (`count=32`),
   and every single-bit-set value (`count=1`).
3. **`WIDTH=32`, random**: 2000 vectors from `$random(seed)` (default seed
   `1`, overridable with `+seed=<n>`).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | WIDTH=8 exhaustive | all 256 values | `count` matches bit-summation reference |
| 2 | WIDTH=32 all-zero | `0x00000000` | `count=0` |
| 3 | WIDTH=32 all-ones | `0xFFFFFFFF` | `count=32` |
| 4 | WIDTH=32 single bits | 32 values, one bit set each | `count=1` |
| 5 | WIDTH=32 random | 2000 vectors, seed=1 | matches reference model |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 055` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_popcount` — **PASS**

```text
WIDTH=8 exhaustive sweep (256 values)...
  done: 256 checks, errors so far: 0
WIDTH=32 directed corners (all-zero, all-ones, single bits)...
WIDTH=32 random sweep, seed=1 (2000 vectors)...
  done: 2290 checks total, errors so far: 0
TEST PASSED: 2290 checks
tb/tb_popcount.v:80: $finish called at 2290000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 27 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The recursive adder tree has `O(log2(WIDTH))` addition depth versus a
  flat `WIDTH`-input summation's much longer carry chain if implemented as
  one big `+` reduction — synthesis tools often perform this same
  rebalancing automatically, but expressing it explicitly in the RTL makes
  the structure visible and independent of a particular tool's optimizer.
* Because the split need not be even, `popcount` works for any `WIDTH ≥ 1`,
  unlike `lzc_tree`'s power-of-two restriction.
* Purely combinational, no reset or clock.

## 14. Common Mistakes

* Assuming a recursive tree split must always be exactly even — this only
  matters when bit position carries meaning (as in leading-zero counting);
  for a commutative reduction like summation it does not.
* Manually zero-extending addition operands when Verilog already promotes
  both operands to the result's width automatically for an unsigned `+` —
  unnecessary, though harmless if done correctly (as `lzc_tree`'s
  conditional-select case did need to, since a `?:` does not auto-extend
  the way arithmetic operators do).
* Not accounting for the output width: `count` must be sized for the
  maximum possible input (`WIDTH` bits all set), i.e. `$clog2(WIDTH+1)`
  bits, not `$clog2(WIDTH)`.

## 15. Possible Improvements

* Compare synthesized area/depth of this recursive tree against a flat
  `+` reduction and a lookup-table-based nibble-popcount approach.
* Extend to a saturating or thresholded popcount (e.g. "at least K bits
  set") useful for approximate-majority and voting logic.

## 16. What This Program Teaches

* Building a genuine adder tree with recursive module instantiation.
* Recognizing when a recursive split must be symmetric (position-sensitive
  results) versus when any split works (commutative reductions).
* Relying on, rather than fighting, Verilog's automatic operand-width
  promotion rules for arithmetic operators.

## 17. Industry Relevance

Population count is a standard hardware primitive (`POPCNT` on x86,
`CNT`/`VCNT` on Arm) used in codes, checksums, and bit-manipulation
algorithms; recursive adder-tree structures like this one underlie many
real multiplier and reduction-operator synthesis implementations.

## 18. How to Run

```bash
python3 scripts/run.py 055            # compile, simulate, synthesize, lint
cd 03-combinational-logic/055-population-count && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/popcount.v tb/tb_popcount.v
vvp build/sim.vvp +vcd +seed=42
```
