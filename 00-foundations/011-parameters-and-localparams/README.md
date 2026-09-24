# 011 — Parameters and Localparams

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Elementary | `param_top` | `src/param_counter.v`, `src/param_top.v` | `tb/tb_param_top.v` |

## 1. Objective

Write one reusable module and instantiate it several times with different
parameter values; derive dependent constants with `localparam` and `$clog2`.

## 2. What the Design Does

`param_counter` is a modulo-`MODULUS` counter whose bit width is computed
from the modulus. `param_top` uses it three times:

| Instance | MODULUS | Derived WIDTH | Counts | Enabled by |
|---|---|---|---|---|
| `u_tenths` | 10 | 4 | 0…9 | `en` |
| `u_seconds` | 60 | 6 | 0…59 | `tenths_wrap` (each time tenths goes 9→0) |
| `u_hex` | 16 | 4 | 0…15 | `en` |

`u_tenths` and `u_seconds` form a cascaded timer; `minute_tick` is high on the
cycle in which the seconds counter wraps.

## 3. Why It Is Useful

Parameterization lets one verified module serve many purposes — FIFOs of
different depths, buses of different widths — without copying code. Deriving
widths automatically removes a whole class of "counter too narrow" bugs.

## 4. Interface

`param_counter`:

| Parameter | Default | Description |
|---|---|---|
| `MODULUS` | 10 | Number of states (≥ 2) |
| `WIDTH` | `$clog2(MODULUS)` | Counter width; override only to widen |

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Clock, async active-low reset |
| `en` | in | 1 | Count enable |
| `count` | out | `WIDTH` | Current count |
| `wrap` | out | 1 | `en` and count at its last value |

`param_top`: `clk`, `rst_n`, `en` in; `tenths[3:0]`, `seconds[5:0]`,
`hex_count[3:0]`, `minute_tick` out.

## 5. Internal Signals

| Signal | Where | Purpose |
|---|---|---|
| `LAST` | `param_counter` (localparam) | `MODULUS − 1`, the value at which the counter wraps |
| `tenths_wrap` | `param_top` | wrap of `u_tenths`, enable of `u_seconds` |

## 6. Architecture

```
en ─┬─► u_tenths (mod 10) ── wrap ──► en: u_seconds (mod 60) ── wrap ──► minute_tick
    │        │ count[3:0] ─► tenths          │ count[5:0] ─► seconds
    └─► u_hex (mod 16) ── count[3:0] ─► hex_count
```

## 7. Module Hierarchy and Connections

```
tb_param_top
└── dut : param_top
    ├── u_tenths  : param_counter #(.MODULUS(10))
    ├── u_seconds : param_counter #(.MODULUS(60))
    └── u_hex     : param_counter #(.MODULUS(16))   (.wrap() left unconnected)
```

## 8. Verilog Concepts Used

* ANSI parameter port list `#( parameter … )`.
* A parameter whose default depends on another parameter.
* `localparam` — an internal constant that cannot be overridden.
* `$clog2` — ceiling log2, evaluated at elaboration time.
* Named parameter override `#(.MODULUS(60))`.
* Replication with a parameter `{WIDTH{1'b0}}`.
* Part-select of an integer localparam `LAST[WIDTH-1:0]`.
* Explicitly unconnected output port `.wrap()`.
* Hierarchical access to an instance's parameter in the testbench
  (`dut.u_seconds.WIDTH`).

## 9. Source Code Explanation

```verilog
module param_counter #(
    parameter MODULUS = 10,
    parameter WIDTH   = $clog2(MODULUS)
) (
```
`$clog2(10) = 4`, `$clog2(60) = 6`, `$clog2(16) = 4`. Because `WIDTH` is
declared in the parameter list it can be used in the port declarations that
follow.

```verilog
localparam integer LAST = MODULUS - 1;
assign wrap = en && (count == LAST[WIDTH-1:0]);
```
`LAST` is derived and fixed. Comparing against `LAST[WIDTH-1:0]` keeps both
operands the same width (lint-clean). An earlier version declared
`localparam [WIDTH-1:0] LAST = MODULUS - 1;`, which Verilator flagged
(`WIDTHTRUNC`) because the 32-bit subtraction result is truncated into the
narrower localparam.

```verilog
else if (en)
    count <= (count == LAST[WIDTH-1:0]) ? {WIDTH{1'b0}} : count + 1'b1;
```
Count while enabled; return to 0 after the last value. `{WIDTH{1'b0}}` is a
zero of the right width for any parameter value.

In `param_top`:

```verilog
param_counter #(.MODULUS(60)) u_seconds (
    .clk(clk), .rst_n(rst_n), .en(tenths_wrap),
    .count(seconds), .wrap(minute_tick)
);
```
Named parameter override, then named port connections. The enable is the
lower counter's wrap signal — the standard way to cascade counters on one
clock (no derived clocks).

## 10. Testbench Explanation

* Prints and checks the derived `WIDTH` of each instance via hierarchical
  references.
* Runs 1300 cycles (more than two "minutes" of tenths) with `en` low one cycle
  in seven.
* A behavioural model (`m_tenths`, `m_seconds`, `m_hex`) is updated right
  after each rising edge using the same enable, and all three counts are
  compared 1 ns later.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | derived widths | 4, 6, 4 |
| 2 | 1300 cycles with gaps in `en` | all counts equal the model every cycle |
| 3 | wrap 9→0 | seconds increments by one |
| 4 | wrap 59→0 | minute tick, seconds back to 0 |
| 5 | `u_hex` | wraps 15→0 naturally |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 011` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_param_top` — **PASS**

```text
derived widths: tenths=4 seconds=6 hex=4 bits
after  200 cycles: tenths=1 seconds=17 hex=11
after  400 cycles: tenths=3 seconds=34 hex=7
after  600 cycles: tenths=4 seconds=51 hex=2
after  800 cycles: tenths=6 seconds=8 hex=14
after 1000 cycles: tenths=7 seconds=25 hex=9
after 1200 cycles: tenths=9 seconds=42 hex=5
minute ticks modelled: 1
TEST PASSED: 1301 checks
tb/tb_param_top.v:68: $finish called at 13016000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 58 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `$clog2(MODULUS)` gives enough bits for values `0 … MODULUS−1`. It does not
  give enough bits to *store* `MODULUS` itself when it is a power of two
  (`$clog2(16) = 4` cannot hold 16) — keep that in mind for occupancy counters
  (see FIFOs, 145).
* `MODULUS = 1` would give `WIDTH = 0`; the parameter comment documents the
  `≥ 2` requirement.
* Leaving an output unconnected with `.wrap()` is explicit and lint-friendly;
  omitting the port entirely also works but looks like an oversight.

## 14. Common Mistakes

* **Using `defparam`** to change parameters from outside — deprecated,
  hard to trace; use `#()`.
* **Positional parameter overrides** `#(60)` — break silently when the
  parameter order changes.
* **Hard-coding widths** that should follow a parameter.
* **Overriding a derived parameter inconsistently** (`MODULUS=60, WIDTH=4`).

## 15. Possible Improvements

* Add a `generate`-time check that `MODULUS ≥ 2` (SystemVerilog `$error`, or a
  simulation-time `initial` check).
* Add an up/down mode (see 105).

## 16. What This Program Teaches

* Declaring, deriving and overriding parameters.
* `localparam` vs `parameter`.
* Cascading counters with enables instead of clocks.

## 17. Industry Relevance

IP blocks are delivered as parameterized RTL (data width, depth, number of
ports). Correct derivation of internal widths from parameters is a standard
review item, and cascaded clock-enable counters are how real designs build
time bases.

## 18. How to Run

```bash
python3 scripts/run.py 011
cd 00-foundations/011-parameters-and-localparams && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_param_top.v
vvp build/sim.vvp
```
