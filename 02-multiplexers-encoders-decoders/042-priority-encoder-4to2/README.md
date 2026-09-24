# 042 — 4-to-2 Priority Encoder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `priority_encoder4to2` | `src/priority_encoder4to2.v` | `tb/tb_priority_encoder4to2.v` |

## 1. Objective

Implement a priority encoder that, unlike the plain encoder of program 041,
accepts any combination of active input bits and reports the index of the
**highest-priority** one, using `casez` with don't-care bits to express
priority directly in the case labels.

## 2. What the Design Does

`priority_encoder4to2` reports the index of the highest-numbered set bit
in `d`, and whether any bit was set at all:

| `d` (any bits below the marked one are don't-cares) | `y` | `valid` |
|---|---|---|
| `1???` | `11` | 1 |
| `01??` | `10` | 1 |
| `001?` | `01` | 1 |
| `0001` | `00` | 1 |
| `0000` | `00` (don't-care) | 0 |

Bit 3 always wins if set, regardless of the other bits; bit 0 only wins if
it is the only bit set.

## 3. Why It Is Useful

Priority encoders resolve exactly the situation a plain encoder (041)
flags as invalid: multiple simultaneous requesters. Interrupt controllers,
bus arbiters and resource allocators all need a well-defined, deterministic
choice when several sources are active at once, and "highest index wins"
(or the mirrored "lowest index wins") is the standard resolution rule.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `d` | input | 4 | Request/active lines, any combination allowed |
| `y` | output | 2 | Index of the highest-priority set bit; don't-care when `valid=0` |
| `valid` | output | 1 | 1 when any bit of `d` is set, 0 when `d = 0000` |

No parameters.

## 5. Internal Signals

None — `y` and `valid` are `reg` only because they are assigned inside an
`always` block; both remain pure combinational functions of `d`.

## 6. Architecture

```
        ┌─────────────────────────────────┐
  d[3:0]│ always @(*) casez (d)           │──► y
   ────►│   4'b1???: y=3                 │
        │   4'b01??: y=2                 │
        │   4'b001?: y=1                 │
        │   4'b0001: y=0                 │
        │   default: y=0                 │
        └─────────────────────────────────┘──► valid = |d
```

Priority is expressed by the **order** of the `casez` items: the first
matching pattern wins, and each subsequent pattern's `?` bits cover cases
already claimed by a higher-priority pattern.

## 7. Module Hierarchy and Connections

```
tb_priority_encoder4to2
└── dut : priority_encoder4to2
```

The testbench drives `d` and observes `y`/`valid` directly; there is no
further hierarchy.

## 8. Verilog Concepts Used

* `casez`, which treats `?` (and `z`) in a case item as a don't-care bit
  that matches either 0 or 1 in the corresponding position of `d`.
* Case-item **priority**: `casez` (like `case`) evaluates items top to
  bottom and takes the first match, which is exactly what encodes "bit 3
  beats bit 2 beats bit 1 beats bit 0" without any extra logic.
* The reduction-OR operator `|d` to compute `valid` in one expression.
* A default assignment before the `casez` to keep the block latch-free.

## 9. Source Code Explanation

```verilog
always @(*) begin
    y     = 2'b00;
    valid = |d;
    casez (d)
        4'b1???: y = 2'd3;
        4'b01??: y = 2'd2;
        4'b001?: y = 2'd1;
        4'b0001: y = 2'd0;
        default: y = 2'b00;
    endcase
end
```

* `valid = |d;` is 1 if any bit of `d` is 1, 0 only when `d = 4'b0000` —
  this is computed once, independently of which bit ends up winning.
* `4'b1???` matches any `d` with bit 3 set, regardless of bits 2..0 — since
  it is checked first, bit 3 always wins when set, satisfying "highest
  index has priority" without needing to explicitly exclude the other
  patterns.
* `4'b01??` is only reached when bit 3 was 0 (the previous item did not
  match), so matching it already implies bit 3 is 0; the `?`s cover bits
  1 and 0 regardless of their value.
* `4'b0001` requires an exact match, since it is the lowest-priority real
  input and has no lower bits to mark as don't-care.
* `default` (reached only by `d = 4'b0000`) leaves `y = 2'b00`; combined
  with `valid = 0`, the interface makes clear this value must not be relied
  upon by the caller.

## 10. Testbench Explanation

`tb_priority_encoder4to2` is exhaustive: `d` is only 4 bits, so all 16
combinations are covered in one run.

1. `d` is driven from a `for` loop over `i = 0..15`.
2. The reference model scans bits 0 to 3 in a loop and keeps overwriting
   `expected_y` whenever a set bit is found, so after the loop
   `expected_y` holds the **highest** set bit's index — an independent
   reimplementation of "highest bit wins" that does not reuse the DUT's
   `casez` structure.
3. `expected_valid = |d`. The check compares `valid` unconditionally, and
   `y` only when `expected_valid` is true, matching the documented
   don't-care behaviour of `y` when `d = 0`.
4. Every row is printed in truth-table form; any mismatch prints an
   `ERROR:` line with time, `d`, expected and actual values.

The final line is `TEST PASSED: 16 checks` or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | No requesters | `d = 0000` | `valid=0` |
| 2 | Single requester | `d` = each single bit set | `valid=1`, `y` = that bit's index |
| 3 | Multiple requesters | all remaining 11 combinations | `valid=1`, `y` = index of the **highest** set bit |

All 16 cases (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 042` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_priority_encoder4to2` — **PASS**

```text
d3 d2 d1 d0 | y1 y0 valid
 0  0  0  0  |  0  0   0
 0  0  0  1  |  0  0   1
 0  0  1  0  |  0  1   1
 0  0  1  1  |  0  1   1
 0  1  0  0  |  1  0   1
 0  1  0  1  |  1  0   1
 0  1  1  0  |  1  0   1
 0  1  1  1  |  1  0   1
 1  0  0  0  |  1  1   1
 1  0  0  1  |  1  1   1
 1  0  1  0  |  1  1   1
 1  0  1  1  |  1  1   1
 1  1  0  0  |  1  1   1
 1  1  0  1  |  1  1   1
 1  1  1  0  |  1  1   1
 1  1  1  1  |  1  1   1
done: 16 checks
TEST PASSED: 16 checks
tb/tb_priority_encoder4to2.v:45: $finish called at 16000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 5 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `casez`'s don't-care matching directly implements priority with far less
  logic than a plain `case` listing all 16 patterns individually would need
  — Yosys reports only 5 cells after generic synthesis.
* Using `?` for don't-cares (rather than `x`, which `casez` also treats as
  wildcard) keeps the case labels unambiguous — `?` is reserved for
  "don't care in this pattern", never for "unknown value on the wire".
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Writing the case items in the wrong order (e.g. checking `4'b0001`
  before `4'b1???`) — since `casez` takes the first match, reordering the
  items silently changes which bit wins on multi-bit inputs.
* Using plain `case` instead of `casez`, which would require listing all
  16 combinations explicitly (as in program 041's encoder) instead of
  letting `?` collapse many patterns into one line — functionally
  possible, but loses the direct visual mapping between priority order and
  case-item order.
* Confusing this design's "highest bit wins" convention with a "lowest bit
  wins" priority scheme used elsewhere — always check the specification,
  since both conventions are common in different bus arbiters.

## 15. Possible Improvements

* Generalize to an N-bit priority encoder with a `for` loop instead of a
  fixed 4-input `casez` (program 043 does exactly this).
* Add a configurable priority direction (MSB-wins vs. LSB-wins) parameter.

## 16. What This Program Teaches

* Using `casez` don't-cares to express priority concisely.
* The distinction between a plain encoder (041, requires exactly one active
  input) and a priority encoder (this program, resolves multiple active
  inputs deterministically).
* Writing an independent bit-scanning reference model in a testbench to
  avoid re-deriving the DUT's own case-priority logic.

## 17. Industry Relevance

Priority encoders are the core of interrupt controllers (which interrupt
line to service first), bus/resource arbiters (which requester gets the
grant), and leading-zero/leading-one detection used in floating-point
normalization and dynamic priority scheduling.

## 18. How to Run

```bash
python3 scripts/run.py 042            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/042-priority-encoder-4to2 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/priority_encoder4to2.v tb/tb_priority_encoder4to2.v
vvp build/sim.vvp +vcd
```
