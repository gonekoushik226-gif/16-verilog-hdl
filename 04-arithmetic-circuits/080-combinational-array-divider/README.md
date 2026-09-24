# 080 — Combinational Array Divider (Restoring Division)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Advanced | `array_divider` | `src/div_cell_row.v`, `src/array_divider.v` | `tb/tb_array_divider.v` |

## 1. Objective

Build unsigned division as a fully combinational array — the restoring-
division algorithm "unrolled in space" (one stage of hardware per
dividend bit) instead of iterated in time over multiple clock cycles.

## 2. What the Design Does

`array_divider` divides a `WIDTH`-bit `dividend` by a `WIDTH`-bit
`divisor`, producing a `WIDTH`-bit `quotient` and `WIDTH`-bit
`remainder`. It chains `WIDTH` `div_cell_row` stages, one per dividend
bit (processed MSB-first): each stage shifts the next dividend bit into
the running partial remainder, trial-subtracts the divisor, and either
keeps the subtracted result (quotient bit 1) or restores the
pre-subtraction value (quotient bit 0, "restoring division").

## 3. Why It Is Useful

Long division by hand works exactly this way: bring down the next digit,
try subtracting the divisor, and either accept the subtraction (write a
1) or restore the previous value (write a 0). This program makes that
algorithm's hardware realization explicit and, because it is fully
combinational, directly comparable in style to the array multiplier
(076) it structurally mirrors.

## 4. Interface

**`array_divider`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `dividend` | input | `WIDTH` | number to divide |
| `divisor` | input | `WIDTH` | number to divide by |
| `quotient` | output | `WIDTH` | `dividend / divisor` |
| `remainder` | output | `WIDTH` | `dividend % divisor` |
| `div_by_zero` | output | 1 | 1 when `divisor == 0` |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 6 | dividend/divisor/quotient/remainder width |

**`div_cell_row`**: `rem_in`, `divisor` (`ROWW` bits each) in; `rem_out`
(`ROWW` bits), `qbit` out.

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `rem[0..WIDTH]` | the running partial remainder after each row (`rem[0]=0`, `rem[WIDTH]`=final remainder) |
| `qbits[WIDTH-1:0]` | one quotient bit produced by each row |
| (inside `div_cell_row`) `borrow[ROWW:0]`, `diff[ROWW-1:0]` | the row's internal bit-serial subtract-with-borrow chain |

## 6. Architecture

```
for row i = 0 .. WIDTH-1 (processing dividend[WIDTH-1] down to dividend[0]):
    shifted_in = {rem[i][ROWW-2:0], dividend[WIDTH-1-i]}
    trial = shifted_in - divisor_ext        (bit-serial borrow chain)
    if borrow occurred (shifted_in < divisor):
        rem[i+1] = shifted_in      (restore)
        qbits[WIDTH-1-i] = 0
    else:
        rem[i+1] = trial
        qbits[WIDTH-1-i] = 1

quotient  = qbits
remainder = rem[WIDTH]
```
Divide-by-zero contract (there is no exception mechanism in purely
combinational hardware): when `divisor=0`, every trial subtraction never
borrows, so `quotient` saturates to all-1s and `remainder` ends up equal
to the original `dividend` — `div_by_zero` flags this case explicitly so
a caller can detect and handle it.

## 7. Module Hierarchy and Connections

```
array_divider #(.WIDTH(N))
└── row[0..N-1] : div_cell_row #(.ROWW(N+1)) (shifted_in, divisor_ext) -> rem[i+1], qbits[N-1-i]
```

## 8. Verilog Concepts Used

* A `generate for` loop cascading `WIDTH` instances of a row module,
  each consuming the previous row's output — structurally the same
  cascade pattern as program 065's `rca_n`.
* A procedural `always @(*)` block with a `for` loop implementing the
  row's internal borrow chain, chosen over a `generate`-based per-bit
  vector for the same reason as program 075: a generate loop writing
  per-bit `assign`s into a shared vector produced a Verilator
  `UNOPTFLAT` false positive here as well.
* `wire [ROWW-1:0] rem [0:WIDTH]` — an unpacked array of vector nets, one
  element per row boundary.

## 9. Source Code Explanation

`div_cell_row`'s `always @(*)` block computes a single-bit-at-a-time
subtract-with-borrow chain (`diff[i] = rem_in[i] ^ divisor[i] ^
borrow[i]`, standard full-subtractor logic) across all `ROWW` bits, then
decides in one step whether the trial subtraction is valid
(`!borrow[ROWW]`, meaning `rem_in >= divisor`) and drives `rem_out`/
`qbit` accordingly. `array_divider`'s generate loop wires each row's
`shifted_in` from the previous row's remainder plus the next dividend
bit (MSB-first, since long division processes the most significant digit
first), and collects every row's `qbit` into the correct position of
`qbits`.

## 10. Testbench Explanation

`tb_array_divider` exhaustively drives all `64x64=4096` combinations of
6-bit `dividend` and `divisor` (including every `divisor=0` case),
comparing against a reference model that uses Verilog's own `/` and `%`
for nonzero divisors and this design's documented divide-by-zero
contract (`quotient=all-1s`, `remainder=dividend`) otherwise, plus
checking `div_by_zero` directly against `divisor==0`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | all 4096 `(dividend,divisor)` combinations | matches `dividend/divisor`, `dividend%divisor` |
| 2 | divide by zero | any dividend, divisor=0 | quotient=63, remainder=dividend, div_by_zero=1 |
| 3 | exact division | e.g. dividend=12,divisor=4 | quotient=3, remainder=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 080` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_array_divider` — **PASS**

```text
TEST PASSED: 4096 checks
tb/tb_array_divider.v:58: $finish called at 4096000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 317 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Combinational division has a long critical path (`WIDTH` sequential
  subtract-with-borrow rows, each itself `ROWW` bits of borrow chain) —
  practical dividers are almost always sequential/iterative (one row of
  hardware reused over multiple cycles, see program 215) rather than
  fully unrolled like this; this program prioritizes making the
  algorithm's structure visible over area/speed efficiency.
* `ROWW = WIDTH+1` gives the running remainder enough headroom for the
  bit shifted in each row without ever needing to widen further.

## 14. Common Mistakes

* Processing dividend bits LSB-first instead of MSB-first — restoring
  division (like long division by hand) must bring down digits starting
  from the most significant one.
* Under-sizing the row width (using `WIDTH` instead of `WIDTH+1` bits for
  `rem_in`) — the shifted-in bit needs the extra headroom bit even though
  the steady-state remainder always fits back within `WIDTH` bits after
  restoring.
* Assuming `div_by_zero` prevents the other outputs from being driven —
  they still are, following this design's explicit documented contract,
  rather than being left undefined.

## 15. Possible Improvements

* Convert to the iterative (one row, many cycles) sequential version for
  area comparison — see program 215's non-restoring divider.
* Add signed-division support with appropriate sign correction on
  quotient and remainder.

## 16. What This Program Teaches

* The restoring-division algorithm and its direct correspondence to
  long division by hand.
* Spatially unrolling an iterative algorithm into a fully combinational
  structural array.

## 17. Industry Relevance

Restoring (and non-restoring) division algorithms underlie essentially
every hardware integer divider; the combinational array form shown here
is mostly of educational value, while real dividers use the iterative
form (program 215) or algorithms like SRT division to trade latency for
area.

## 18. How to Run

```bash
python3 scripts/run.py 080            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/080-combinational-array-divider && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/div_cell_row.v src/array_divider.v tb/tb_array_divider.v
vvp build/sim.vvp +vcd
```
