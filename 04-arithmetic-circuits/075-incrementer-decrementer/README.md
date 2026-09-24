# 075 — Incrementer/Decrementer

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Elementary | `inc_dec` | `src/inc_dec.v` | `tb/tb_inc_dec.v` |

## 1. Objective

Build a dedicated ±1 unit instead of a full adder with one operand tied
to a constant, using the observation that a half adder's sum and a half
subtractor's diff are literally the same equation.

## 2. What the Design Does

`inc_dec` adds or subtracts exactly 1 from an 8-bit value `a`, selected
by `dec` (0 = increment, 1 = decrement), producing `result` and a `wrap`
flag that reports whether the operation rolled over (`0xFF -> 0x00` or
`0x00 -> 0xFF`).

## 3. Why It Is Useful

Program counters, loop counters and address generators overwhelmingly
add or subtract 1, not an arbitrary operand — a dedicated ±1 unit avoids
instantiating (or synthesizing) a full generic adder just to add a
constant.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 8 | value to increment/decrement |
| `dec` | input | 1 | 0 = increment, 1 = decrement |
| `result` | output | 8 | `a+1` or `a-1`, wrapped to 8 bits |
| `wrap` | output | 1 | carry-out (increment) / borrow-out (decrement) |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | operand width |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `chain_bit` | 1 | running carry (increment) / borrow (decrement) through the bit loop |

## 6. Architecture

```
chain_bit = 1                       (always adding/subtracting exactly 1)
for i = 0 to WIDTH-1:
    result[i] = a[i] XOR chain_bit
    chain_bit = dec ? (~a[i] & chain_bit)     // borrow propagate
                    : ( a[i] & chain_bit)     // carry propagate
wrap = chain_bit (after the loop)
```
A half adder's `sum = a XOR carry_in` and a half subtractor's `diff = a
XOR borrow_in` are the same expression, so `result[i]` does not need to
know which direction is active — only the *propagate condition* for the
next `chain_bit` differs between increment (propagate a carry out of a
`1` bit) and decrement (propagate a borrow out of a `0` bit).

## 7. Module Hierarchy and Connections

Single module; the bit chain is built with a procedural `for` loop inside
one combinational `always @(*)` block rather than separate module
instances.

## 8. Verilog Concepts Used

* A combinational `always @(*)` block with a procedural `for` loop
  computing a running scalar (`chain_bit`) across all `WIDTH` iterations
  — chosen over a `generate`-based per-bit vector (as used in program
  065's `rca_n`) specifically because a `generate` loop writing
  `assign`s to overlapping slices of one shared vector here triggered a
  Verilator `UNOPTFLAT` false-positive on the apparent circular
  dependency; a single procedural loop avoids it entirely.
* Default assignment (`result = 0`, `chain_bit = 1`) at the top of the
  block, satisfying the repository's no-unintended-latch rule.

## 9. Source Code Explanation

```verilog
always @(*) begin
    result    = {WIDTH{1'b0}};
    chain_bit = 1'b1;
    for (i = 0; i < WIDTH; i = i + 1) begin
        result[i] = a[i] ^ chain_bit;
        chain_bit = dec ? ((~a[i]) & chain_bit) : (a[i] & chain_bit);
    end
    wrap = chain_bit;
end
```
Each iteration computes one bit's result and updates `chain_bit` for the
next iteration, exactly mirroring a hardware ripple chain but expressed
procedurally; Verilog's blocking assignment (`=`) inside `always @(*)`
gives each iteration the previous iteration's updated `chain_bit`, the
same value a hardware carry/borrow wire would carry forward.

## 10. Testbench Explanation

`tb_inc_dec` exhaustively drives all 256 values of `a` for both `dec=0`
and `dec=1` (512 cases), comparing against a 9-bit Verilog reference
(`a+1` or `a-1`, both computed with unsigned wraparound) so the reference
`[8]` bit directly gives the expected carry-out (increment) or
borrow-out (decrement) — Verilog's own unsigned subtraction wraparound
happens to produce a `[8]` bit that is 1 exactly when `a=0`, matching
this design's borrow semantics with no sign inversion needed.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | increment, no wrap | a=0..254, dec=0 | result=a+1, wrap=0 |
| 2 | increment, wrap | a=255, dec=0 | result=0, wrap=1 |
| 3 | decrement, no wrap | a=1..255, dec=1 | result=a-1, wrap=0 |
| 4 | decrement, wrap | a=0, dec=1 | result=255, wrap=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 075` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_inc_dec` — **PASS**

```text
TEST PASSED: 512 checks
tb/tb_inc_dec.v:56: $finish called at 512000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 23 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely combinational; no reset/clock.
* A generate-based per-bit vector implementation is logically equivalent
  and was tried first, but produced a Verilator `UNOPTFLAT` lint warning
  from the tool's flattened dependency analysis of overlapping vector
  slices; the procedural-loop version used here is functionally
  identical and lint-clean.

## 14. Common Mistakes

* Assuming increment and decrement need entirely separate bit logic —
  the XOR term for `result[i]` is identical in both directions; only the
  chain-bit propagate condition differs.
* Getting the borrow propagate condition backwards (`a[i] & chain_bit`
  instead of `~a[i] & chain_bit`) — a borrow propagates out of a bit only
  when that bit is 0, the opposite condition from a carry.

## 15. Possible Improvements

* Extend to a signed saturating variant that clamps instead of wrapping
  at the boundaries.

## 16. What This Program Teaches

* The algebraic identity between half-adder sum and half-subtractor diff.
* A concrete example of choosing procedural over generate-based RTL to
  sidestep a specific lint tool limitation, and documenting why.

## 17. Industry Relevance

Dedicated increment/decrement units are extremely common in program
counters, address generators and loop counters, where synthesizing a
full generic adder purely to add a constant 1 would waste area compared
to this specialized chain.

## 18. How to Run

```bash
python3 scripts/run.py 075            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/075-incrementer-decrementer && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/inc_dec.v tb/tb_inc_dec.v
vvp build/sim.vvp +vcd
```
