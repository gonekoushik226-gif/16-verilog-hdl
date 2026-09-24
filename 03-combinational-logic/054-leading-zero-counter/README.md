# 054 — Leading-Zero Counter (Priority Scan vs. Tree)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Intermediate | (none — two independent modules) | `src/lzc_loop.v`, `src/lzc_tree.v` | `tb/tb_leading_zero_counter.v` |

## 1. Objective

Implement leading-zero counting two structurally different ways — an
unrolled priority-scan loop and a recursive divide-and-conquer tree — and
prove both compute the identical result for every input, illustrating the
trade-off between an `O(WIDTH)`-depth sequential-style scan and an
`O(log WIDTH)`-depth tree.

## 2. What the Design Does

Both `lzc_loop` and `lzc_tree` count the number of consecutive 0 bits from
the most-significant bit of a `WIDTH`-bit input, down to (but not
including) the first 1 bit. `all_zero` flags an all-zero input, for which
`count` equals `WIDTH` (every bit is a "leading zero" since there is no 1
bit to stop at). The two modules present an identical interface, so either
can be substituted for the other.

## 3. Why It Is Useful

Leading-zero count is the core operation behind floating-point
normalization (aligning a mantissa after an operation), priority
arbitration, and fast integer `log2`/bit-length computation. Comparing a
loop-based and a tree-based implementation of the same function is a
direct, concrete introduction to the depth/complexity trade-offs that
recur throughout combinational RTL design (also seen later in this
curriculum's carry-lookahead vs. ripple-carry adders).

## 4. Interface

(identical for both modules)

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | value to scan |
| `count` | output | `$clog2(WIDTH+1)` | number of leading zero bits, `0`–`WIDTH` |
| `all_zero` | output | 1 | 1 when every bit of `data` is 0 |

Parameters (both modules):

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | input width; `lzc_tree` requires a power of two |

## 5. Internal Signals

`lzc_loop`: `i` (loop index), `done` (latched-in-simulation-sense priority
flag: 1 once the first 1 bit has been seen, stopping further counting).

`lzc_tree`: per-recursion-level `count_hi`/`count_lo`, `allz_hi`/`allz_lo`
— the two half-width sub-results being combined.

## 6. Architecture

```
lzc_loop (priority scan, WIDTH stages):
  data[W-1] data[W-2] ... data[0]
      │         │              │
   count++   count++ (until first 1 found, then frozen)

lzc_tree (divide-and-conquer, log2(WIDTH) levels):
                      data[W-1:0]
                     /            \
            data[W-1:W/2]      data[W/2-1:0]
             (upper half)       (lower half)
                  │                   │
            lzc_tree(W/2)       lzc_tree(W/2)
                  │                   │
          allz_hi,count_hi     allz_lo,count_lo
                  └─────────┬─────────┘
             allz_hi ? (W/2 + count_lo) : count_hi
```

## 7. Module Hierarchy and Connections

```
tb_leading_zero_counter
├── dutLoop8/32  : lzc_loop #(.WIDTH(8|32))
└── dutTree8/32  : lzc_tree #(.WIDTH(8|32))

lzc_tree #(.WIDTH(W))               (for W > 1)
├── upper : lzc_tree #(.WIDTH(W/2))   (recursive self-instantiation)
└── lower : lzc_tree #(.WIDTH(W/2))
    ... down to WIDTH == 1 (base case, no further instances)
```

`lzc_tree` instantiates itself recursively through a `generate if`,
terminating at the `WIDTH == 1` base case; for `WIDTH = 32` this creates a
5-level-deep tree of 63 total instances.

## 8. Verilog Concepts Used

* `lzc_loop`: an unrolled `for` loop with a "done" guard flag implementing
  a priority scan combinationally (no clock — the loop still executes
  fully every evaluation, but later iterations become no-ops once `done`
  is set).
* `lzc_tree`: **recursive module self-instantiation** through
  `generate if` — the module instantiates smaller copies of itself until
  reaching a fixed base case, a standard technique for describing
  logarithmic-depth trees (adders, multipliers, reductions) without manual
  unrolling.
* Zero-extension of a narrower sub-instance's output into a wider local
  wire (`{{(CW-SUB_CW){1'b0}}, count_hi_raw}`) to combine differently-sized
  intermediate results cleanly.
* Two independently structured implementations of the same specification,
  cross-checked against each other and against a testbench reference
  model.

## 9. Source Code Explanation

`lzc_loop`'s core loop:
```verilog
for (i = WIDTH - 1; i >= 0; i = i - 1) begin
    if (!done) begin
        if (data[i]) done = 1'b1;
        else         count = count + 1'b1;
    end
end
```
* `done` starts cleared and the loop scans from the MSB down; each
  iteration only acts while `!done`, so once the first 1 bit is found,
  every remaining (lower-index) iteration is a no-op — exactly a priority
  scan, unrolled into `WIDTH` fixed stages.

`lzc_tree`'s recursive step:
```verilog
lzc_tree #(.WIDTH(HALF)) upper (.data(data[WIDTH-1:HALF]), .count(count_hi_raw), .all_zero(allz_hi));
lzc_tree #(.WIDTH(HALF)) lower (.data(data[HALF-1:0]),     .count(count_lo_raw), .all_zero(allz_lo));
...
assign count = allz_hi ? (HALF[CW-1:0] + count_lo) : count_hi;
```
* If the upper half is entirely zero, every one of its `HALF` bits is a
  leading zero, and the count continues into however many leading zeros
  the lower half itself has; otherwise the first 1 bit is already inside
  the upper half, so its own count is the final answer without even
  looking at the lower half's value (only `count_hi` is used in that
  branch, though `lower` is still instantiated and evaluated in hardware
  since both halves exist unconditionally in the circuit).

## 10. Testbench Explanation

`tb_leading_zero_counter` instantiates both implementations at two widths
and checks three things per input: each module against an independent
reference model (a testbench-local priority scan with its own `found`
flag, written separately from both RTL modules), and the two RTL modules
against each other directly.

1. **`WIDTH=8`, exhaustive**: all 256 values.
2. **`WIDTH=32`, directed**: all-zero, all-ones, and each of the 32
   single-bit-set values (the exact boundary cases for a priority scan).
3. **`WIDTH=32`, random**: 2000 vectors from `$random(seed)` (default seed
   `1`, overridable with `+seed=<n>`).

A bug was found and fixed during development of this testbench itself: the
first version of the reference-model loop did not stop at the first
matching bit, so it kept overwriting `exp_count` all the way down to the
*lowest* set bit instead of stopping at the *highest* — both RTL modules
were already correct and agreed with each other, but disagreed with the
broken reference, which pointed directly at the testbench rather than the
design.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | WIDTH=8 exhaustive | all 256 values | both modules match reference model |
| 2 | WIDTH=32 all-zero | `0x00000000` | `count=32`, `all_zero=1` |
| 3 | WIDTH=32 all-ones | `0xFFFFFFFF` | `count=0`, `all_zero=0` |
| 4 | WIDTH=32 single bits | 32 values, one bit set each | `count` = bit's own leading-zero distance from MSB |
| 5 | WIDTH=32 random | 2000 vectors, seed=1 | both modules agree with each other and the reference model |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 054` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_leading_zero_counter` — **PASS**

```text
WIDTH=8 exhaustive sweep (256 values)...
  done: 512 checks, errors so far: 0
WIDTH=32 directed corners (all-zero, all-ones, single bits)...
WIDTH=32 random sweep, seed=1 (2000 vectors)...
  done: 6614 checks total, errors so far: 0
TEST PASSED: 6614 checks
tb/tb_leading_zero_counter.v:122: $finish called at 2290000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 88 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `lzc_loop` has combinational depth proportional to `WIDTH` (`done`
  propagates through up to `WIDTH` stages); `lzc_tree` has depth
  proportional to `log2(WIDTH)`, at the cost of `WIDTH-1` total instances
  instantiated across all recursion levels versus `lzc_loop`'s single flat
  block — the classic latency-vs-instance-count trade-off.
* `lzc_tree` requires `WIDTH` to be a power of two so `HALF = WIDTH/2` is
  always an exact, equal split; `lzc_loop` has no such restriction.
* Both are pure combinational logic, no reset or clock.

## 14. Common Mistakes

* In a priority-scan loop, forgetting the "already found" guard and
  letting a later (less significant) iteration overwrite an earlier,
  correct result — precisely the bug caught in this program's own
  testbench reference model (§10), not the RTL, but illustrating exactly
  the failure mode a real priority-scan implementation must avoid.
* In the tree version, using the lower half's count when the upper half is
  *not* all zero — the correct rule only adds the lower half's count when
  the upper half contributed no 1 bit at all.
* Forgetting to zero-extend a narrower recursive sub-result before
  combining it with a wider running total, which silently truncates or
  misaligns the addition.

## 15. Possible Improvements

* Add a non-power-of-two-width tree variant using unequal splits.
* Add a corresponding trailing-zero counter (scan from the LSB) as a
  companion pair, as `bin2gray`/`gray2bin` did for Gray code.

## 16. What This Program Teaches

* Two genuinely different structural approaches (unrolled loop vs.
  recursive tree) to the same function, and how to compare their
  depth/instance-count trade-offs.
* Recursive module self-instantiation via `generate if` as a way to
  describe a logarithmic-depth tree without manual unrolling.
* Cross-checking independent implementations against each other, not only
  against a single reference model — which is exactly what caught this
  program's one real bug (in the testbench, not the RTL).

## 17. Industry Relevance

Leading-zero counters are a standard primitive in floating-point units
(mantissa normalization), fast software `clz`/`bsr` intrinsics implemented
in hardware, and priority arbitration logic; real ALU and FPU
implementations make exactly this loop-vs-tree latency/area trade-off when
choosing an implementation strategy.

## 18. How to Run

```bash
python3 scripts/run.py 054            # compile, simulate, synthesize, lint
cd 03-combinational-logic/054-leading-zero-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/lzc_loop.v src/lzc_tree.v tb/tb_leading_zero_counter.v
vvp build/sim.vvp +vcd +seed=42
```
