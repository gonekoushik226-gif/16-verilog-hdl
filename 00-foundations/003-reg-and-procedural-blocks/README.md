# 003 — `reg` and Procedural Blocks

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `procedural_demo` | `src/procedural_demo.v` | `tb/tb_procedural_demo.v` |

## 1. Objective

Understand the difference between a Verilog `reg` (a variable assigned in a
procedural block) and a hardware register, by describing both combinational
logic and a flip-flop with `always` blocks.

## 2. What the Design Does

* `max_ab` is the larger of the 4-bit inputs `a` and `b`. It changes as soon
  as `a` or `b` changes (combinational).
* `max_q` stores `max_ab` on every rising edge of `clk`. It is cleared to 0
  immediately when `rst_n` goes low (asynchronous reset), independent of the
  clock.

Both outputs are declared `reg`, yet only `max_q` becomes a flip-flop.

## 3. Why It Is Useful

"Compute a value, then register it" is the basic pattern of every synchronous
design: combinational logic between flip-flops. Recognising which `always`
block produces gates and which produces flip-flops is the first skill needed
to read any RTL.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock; `max_q` updates on the rising edge |
| `rst_n` | input | 1 | Asynchronous reset, active low |
| `a`, `b` | input | 4 each | Unsigned operands |
| `max_ab` | output | 4 | `max(a, b)`, combinational |
| `max_q` | output | 4 | `max_ab` registered |

## 5. Internal Signals

None beyond the outputs.

## 6. Architecture

```
 a ---+   +------------+  max_ab        +-------+
      +-->| comparator |---+----------->| D   Q |----> max_q
 b ---+   | + 2:1 mux  |   |            |       |
          +------------+   +--> max_ab  |  >clk |
                                        +---+---+
                                   rst_n ---+ (async clear)
```

## 7. Module Hierarchy and Connections

```
tb_procedural_demo
└── dut : procedural_demo
```

## 8. Verilog Concepts Used

* `reg` — a **variable**: holds the last value assigned by procedural code. It
  models a flip-flop only when assigned in an edge-triggered block.
* `always @(*)` — combinational block; `@(*)` automatically includes every
  signal read inside the block in the sensitivity list.
* `always @(posedge clk or negedge rst_n)` — sequential block with
  asynchronous reset.
* Blocking `=` in combinational blocks, non-blocking `<=` in sequential blocks
  (explained in 010).
* `if/else` inside procedural code.
* Testbench: `always #5 clk = ~clk` clock generator, `@(posedge clk)` /
  `@(negedge clk)` event control, a `task` for checking, `$timeformat`, a
  watchdog `initial` block.

## 9. Source Code Explanation

```verilog
output reg  [3:0] max_ab,
output reg  [3:0] max_q
```
Outputs assigned inside `always` blocks must be declared `reg`.

```verilog
always @(*) begin
    if (a > b)
        max_ab = a;
    else
        max_ab = b;
end
```
Runs whenever `a` or `b` changes. Because **both** branches assign `max_ab`,
the output is always a function of the current inputs — synthesis builds a
4-bit comparator and a 2:1 multiplexer. If the `else` were missing,
`max_ab` would have to keep its old value when `a <= b`, and synthesis would
infer a latch (see 086).

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        max_q <= 4'd0;
    else
        max_q <= max_ab;
end
```
The block wakes up only on a rising `clk` edge or a falling `rst_n` edge.
The reset is tested first so that it has priority; `negedge rst_n` in the
list makes it asynchronous (it acts without a clock). Everything else happens
only at clock edges, so `max_q` holds its value between edges: a 4-bit
flip-flop with asynchronous clear.

## 10. Testbench Explanation

1. **Asynchronous reset** — `rst_n` is pulled low at 2 ns, before any rising
   clock edge (the first is at 5 ns). One nanosecond later `max_q` must
   already be 0.
2. **Combinational check** — while reset holds `max_q`, all 256 `(a, b)`
   pairs are applied and `max_ab` is compared with `(i > j) ? i : j` after
   1 ns.
3. **Sequential check** — reset is released on a falling edge. For eight
   random pairs, inputs change on the falling edge and `max_q` is checked 1 ns
   after the following rising edge. Changing inputs on the opposite edge from
   the one the design samples avoids testbench/design races.
4. **Hold check** — after changing the inputs mid-cycle, `max_ab` changes
   immediately but `max_q` must keep its old value until the next rising edge.
5. A watchdog ends the simulation with `TEST FAILED: timeout` if the bench
   ever hangs.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected |
|---|---|---|---|
| 1 | Async reset | `rst_n` low between clock edges | `max_q = 0` without a clock edge |
| 2 | Combinational | all 256 `(a,b)` | `max_ab = max(a,b)` |
| 3 | Register capture | 8 random pairs | `max_q` = `max_ab` of the previous cycle |
| 4 | Hold between edges | inputs change mid-cycle | `max_q` unchanged until next edge |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 003` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_procedural_demo` — **PASS**

```text
reset asserted at t=2 ns, max_q=0 at t=3 ns (no clock edge yet)
combinational max_ab checked for all 256 (a,b) pairs
 a  b | max_ab | max_q after next rising edge
 4  1 |    4   |    4
 9  3 |    9   |    9
13 13 |   13   |   13
 5  2 |    5   |    5
 1 13 |   13   |   13
 6 13 |   13   |   13
13 12 |   13   |   13
 9  6 |    9   |    9
TEST PASSED: 267 checks
tb/tb_procedural_demo.v:78: $finish called at 356000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 26 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The name `reg` is historical and misleading; SystemVerilog replaced it with
  `logic`. What matters is **how** the variable is assigned.
* Asynchronous reset needs `rst_n` in the sensitivity list; a synchronous reset
  would not (see 088).
* Yosys maps `max_q` to four flip-flops with asynchronous reset (`$_DFF_PN0_`)
  and `max_ab` to comparator/mux gates.

## 14. Common Mistakes

* **Believing `reg` always means flip-flop.**
* **Incomplete sensitivity lists** such as `always @(a)` in combinational
  code — simulation ignores changes on `b` while synthesis does not, so the two
  disagree. Use `@(*)`.
* **Missing `else`/default in combinational blocks** → unintended latch.
* **Assigning a `wire` in an `always` block** — compile error.
* **Changing testbench inputs on the same edge the design samples** — creates
  races whose outcome depends on simulator ordering.

## 15. Possible Improvements

* Add a clock enable so `max_q` only updates when requested (see 089).
* Parameterize the width (see 011).

## 16. What This Program Teaches

* `reg` vs hardware register.
* Combinational vs sequential `always` blocks.
* Asynchronous active-low reset.
* Race-free testbench timing using opposite clock edges.

## 17. Industry Relevance

This two-block style — combinational logic in `always @(*)`, state in
`always @(posedge clk or negedge rst_n)` — is the standard coding pattern in
ASIC and FPGA RTL guidelines, and the asynchronous active-low reset is the
most common reset style in ASIC flows.

## 18. How to Run

```bash
python3 scripts/run.py 003
cd 00-foundations/003-reg-and-procedural-blocks && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/procedural_demo.v tb/tb_procedural_demo.v
vvp build/sim.vvp +vcd
```
