# 043 — Parameterized N-Bit Priority Encoder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Intermediate | `priority_encoder_n` | `src/priority_encoder_n.v` | `tb/tb_priority_encoder_n.v` |

## 1. Objective

Generalize the fixed 4-input priority encoder of program 042 to any width
`N` using a `for` loop instead of a fixed `casez`, and add a
`MSB_PRIORITY` parameter that selects whether the highest- or
lowest-indexed active bit wins.

## 2. What the Design Does

`priority_encoder_n` scans all `N` bits of `d` and reports the index of the
winning bit:

* `MSB_PRIORITY = 1`: the **highest**-indexed set bit wins (same convention
  as program 042).
* `MSB_PRIORITY = 0`: the **lowest**-indexed set bit wins.

`valid` is 1 whenever any bit of `d` is set, 0 only when `d = 0` (in which
case `y` is don't-care, exactly as in program 042).

## 3. Why It Is Useful

Real arbiters and interrupt controllers need priority encoders of many
different widths, and the priority convention (MSB-wins vs. LSB-wins) is a
design choice, not a fixed law of nature — different bus protocols and
interrupt schemes pick different conventions. A single parameterized module
covering both avoids maintaining separate fixed-width, fixed-direction
encoders for each case.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `d` | input | `N` | Request/active lines, any combination allowed |
| `y` | output | `$clog2(N)` | Index of the winning set bit; don't-care when `valid=0` |
| `valid` | output | 1 | 1 when any bit of `d` is set, 0 when `d = 0` |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `N` | 8 | Number of request lines |
| `MSB_PRIORITY` | 1 | 1: highest-indexed bit wins; 0: lowest-indexed bit wins |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `i` (loop variable) | integer | Scans bit positions 0..N-1 (or N-1..0) inside the `always` block |

## 6. Architecture

```
MSB_PRIORITY=1:  scan i = 0 .. N-1, keep overwriting y on every d[i]=1
                 -> the LAST (highest-index) hit is what remains in y

MSB_PRIORITY=0:  scan i = N-1 .. 0, keep overwriting y on every d[i]=1
                 -> the LAST (lowest-index) hit is what remains in y
```

Both directions use the exact same "overwrite on every hit" idea; only the
scan order changes which hit survives as the final value.

## 7. Module Hierarchy and Connections

```
tb_priority_encoder_n
├── dutA : priority_encoder_n #(.N(8),  .MSB_PRIORITY(1))  -- exhaustive
├── dutB : priority_encoder_n #(.N(8),  .MSB_PRIORITY(0))  -- exhaustive
├── dutC : priority_encoder_n #(.N(16), .MSB_PRIORITY(1))  -- random
└── dutD : priority_encoder_n #(.N(16), .MSB_PRIORITY(0))  -- random
```

## 8. Verilog Concepts Used

* A `for` loop inside a combinational `always @(*)` block, synthesizable
  because `N` (the loop bound) is a compile-time constant.
* `$clog2(N)` sizing both the output port and the loop's index cast.
  the array/vector index.
* A parameter (`MSB_PRIORITY`) used as an `if`/`else` condition, selecting
  between two different pieces of combinational logic at elaboration time
  (Yosys and Verilator both constant-fold the unused branch away).
* Reusable `task`s in the testbench (`check8`, `check16`) parameterized by
  the priority direction, avoiding duplicated checking code for four DUT
  instances.

## 9. Source Code Explanation

```verilog
always @(*) begin
    y     = {$clog2(N){1'b0}};
    valid = |d;
    if (MSB_PRIORITY) begin
        for (i = 0; i < N; i = i + 1)
            if (d[i]) y = i[$clog2(N)-1:0];
    end else begin
        for (i = N - 1; i >= 0; i = i - 1)
            if (d[i]) y = i[$clog2(N)-1:0];
    end
end
```

* The loop does not `break` on the first hit; it keeps assigning `y` for
  **every** set bit it visits, and blocking assignment (`=`) means each new
  assignment simply overwrites the previous one. The bit visited *last*
  among the set bits is therefore the one left in `y` when the loop ends.
* When `MSB_PRIORITY = 1`, the loop visits bit 0 first and bit `N-1` last,
  so if bit `N-1` is set, it is visited last and its assignment is the one
  that survives — the highest set bit wins.
* When `MSB_PRIORITY = 0`, the loop direction is reversed (`N-1` down to
  `0`), so the lowest set bit, being visited last, survives instead.
* Because `MSB_PRIORITY` is a `parameter`, the `if/else` choosing between
  the two loops is resolved once at elaboration time — an instance never
  contains both loops' hardware, only whichever one its parameter selected.

## 10. Testbench Explanation

`tb_priority_encoder_n` instantiates four configurations:

1. `dutA`/`dutB` (`N=8`, `MSB_PRIORITY=1`/`0`): `d` is swept over all 256
   values, exhaustively covering both priority directions at this width.
2. `dutC`/`dutD` (`N=16`, `MSB_PRIORITY=1`/`0`): 2000 random 16-bit vectors
   are applied to each (`$random` with an explicit seed for
   reproducibility), plus the `d=0` and `d=all-ones` corner cases are
   checked directly afterward.

The `check8`/`check16` tasks implement an independent reference model: a
loop that scans in the direction matching the requested priority and keeps
overwriting `expected_y` on every hit, mirroring the DUT's own algorithm
structure but written and invoked independently for each instance and
called with the actual outputs to compare. Every call increments `checks`;
a mismatch increments `errors` and prints an `ERROR:` line naming `N`, the
priority mode, `d`, expected and actual values. The final line is
`TEST PASSED: 4516 checks` (512 exhaustive + 4000 random + 4 corner cases)
or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive `N=8`, MSB priority | `d` = 0..255 | `y` = index of highest set bit |
| 2 | Exhaustive `N=8`, LSB priority | `d` = 0..255 | `y` = index of lowest set bit |
| 3 | Random `N=16`, MSB priority | 2000 random vectors | `y` = index of highest set bit |
| 4 | Random `N=16`, LSB priority | 2000 random vectors | `y` = index of lowest set bit |
| 5 | Corners `N=16` | `d=0`, `d=all-ones` | `valid=0` for `d=0`; correct extreme index for `d=all-ones` |

`N=8` is exercised over 100% of its input space in both priority
directions; `N=16` is exercised with 4000 random vectors plus both
all-zero and all-ones corner cases.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 043` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_priority_encoder_n` — **PASS**

```text
N=8 exhaustive, MSB and LSB priority (512 combinations):
N=16 random, MSB and LSB priority (4000 vectors):
done: 4516 checks
TEST PASSED: 4516 checks
tb/tb_priority_encoder_n.v:120: $finish called at 2258000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 20 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The "overwrite on every hit, keep the last one" loop idiom is a common,
  readable way to write a priority scan in Verilog; Yosys still reduces it
  to the same 2:1-mux-chain hardware a hand-written priority `casez` would
  produce (20 cells total for all four instantiated configurations).
* `MSB_PRIORITY` is resolved at elaboration time, so choosing one direction
  costs nothing extra in the other direction's unused logic — no hardware
  for the untaken branch is generated.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Assuming the loop "stops at the first match" — it does not; understanding
  that it visits every bit and the assignment order (not an early exit)
  determines the winner is essential to seeing why reversing the loop
  direction reverses priority.
* Forgetting that `i` must be declared as a plain `integer` (not sized to
  `$clog2(N)` bits) so the loop bound comparisons (`i < N`, `i >= 0`) work
  correctly for all `N`, including the `i >= 0` termination in the
  descending loop.
* Mixing up the meaning of `MSB_PRIORITY = 0`: it does not disable priority
  encoding, it only flips which end of `d` is favored.

## 15. Possible Improvements

* Add a tree-structured (`generate`-based) implementation for comparison
  with this loop-based one, useful when synthesis timing at very large `N`
  becomes a concern.
* Provide the matching parameterized decoder (`decoder_n`, already done in
  program 040) as a natural round-trip pair.

## 16. What This Program Teaches

* Writing a synthesizable `for` loop inside a combinational block whose
  bound is a parameter.
* How the direction of an "overwrite on every hit" scan determines which
  match survives, without needing an explicit early-exit or priority
  ladder.
* Testing a parameterized design at more than one width, with exhaustive
  coverage where feasible and randomized coverage where the space is too
  large.

## 17. Industry Relevance

Priority encoders of parameterized width are core IP blocks in interrupt
controllers, round-robin/fixed-priority bus arbiters, and leading-bit
detection for floating-point normalization; a configurable priority
direction lets the same block serve protocols with opposite priority
conventions without duplicated RTL.

## 18. How to Run

```bash
python3 scripts/run.py 043            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/043-priority-encoder-parameterized && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/priority_encoder_n.v tb/tb_priority_encoder_n.v
vvp build/sim.vvp +vcd
```
