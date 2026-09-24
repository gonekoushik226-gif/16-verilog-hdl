# 024 — Buffer Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `buffer_gate` | `src/buffer_gate.v` | `tb/tb_buffer_gate.v` |

## 1. Objective

Introduce the built-in `buf` gate primitive, show that a single primitive
instance can drive more than one output, and explain why a logically
"do-nothing" gate is a real, necessary component.

## 2. What the Design Does

`buffer_gate` drives `y1 = y2 = a`: both outputs simply repeat the input.

| `a` | `y1` | `y2` |
|---|---|---|
| 0 | 0 | 0 |
| 1 | 1 | 1 |
| x | x | x |
| z | x | x |

## 3. Why It Is Useful

A buffer does not change logic values, but it restores electrical drive
strength and adds a small, controlled amount of delay. Real uses:

* **Fanout repair** — a signal driving many downstream gates loads its
  driver; a buffer re-amplifies it partway along the path.
* **Clock and reset trees** — buffers (often several stages, sized larger
  toward the leaves) distribute a clock or reset to thousands of flip-flops
  with balanced delay.
* **Timing/delay insertion** — inserting buffers is a standard way for a
  place-and-route tool to fix a path that is too fast (hold violations).

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | Signal to buffer |
| `y1` | output | 1 | Buffered copy of `a` |
| `y2` | output | 1 | Second buffered copy of `a` |

No parameters.

## 5. Internal Signals

None — both outputs are direct copies of the input.

## 6. Architecture

```
        ┌──► y1
 a ──[ BUF ]
        └──► y2
```

One `buf` primitive fans the same driven signal out to two output ports.

## 7. Module Hierarchy and Connections

```
tb_buffer_gate
└── dut : buffer_gate
    └── u_buf : buf primitive (built-in), 1 input → 2 outputs
```

## 8. Verilog Concepts Used

* The built-in `buf` gate-level primitive (as opposed to the `assign`
  dataflow style used in 017–023).
* A primitive instance with **multiple output terminals**: `buf(y1, y2, a)`
  — every argument except the last is an output, and all outputs are
  driven from the single trailing input.

## 9. Source Code Explanation

```verilog
module buffer_gate (
    input  wire a,
    output wire y1,
    output wire y2
);
    buf u_buf (y1, y2, a);
endmodule
```

`buf u_buf (y1, y2, a);` instantiates one built-in buffer primitive named
`u_buf`. Its argument list is `(out1, out2, ..., in)`: here `y1` and `y2`
are both outputs, and `a` (the last argument) is the single input. This is
different from a module instantiation, where every port is matched
individually — a gate primitive's ports are positional and the last one is
always the input.

## 10. Testbench Explanation

`tb_buffer_gate` uses a `check_one(av, ev)` task (as in 019) to drive `a`
and compare both `y1` and `y2` against the expected value. It exercises
the two defined logic levels (exhaustive) and then `1'bx`/`1'bz` to show
that a buffer, like an inverter, cannot output high-impedance: an
undriven/unknown input reads back as unknown on both outputs. Mismatches
print an `ERROR:` line; the run ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

| # | `a` | Expected `y1`, `y2` |
|---|---|---|
| 1 | 0 | 0, 0 |
| 2 | 1 | 1, 1 |
| 3 | x | x, x |
| 4 | z | x, x |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 024` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_buffer_gate` — **PASS**

```text
a | y1 y2
 a=0 | y1=0 y2=0
 a=1 | y1=1 y2=1
 a=x | y1=x y2=x
 a=z | y1=x y2=x
TEST PASSED: 4 checks
tb/tb_buffer_gate.v:46: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 0 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Synthesis tools generally treat a logical buffer as a "no-op" and remove
  it unless it is annotated to be kept for timing/fanout reasons (Yosys's
  generic `synth` here maps it to 0 cells because there is nothing left to
  optimize once the buffer is combined with its driver).
* A `buf` primitive, like `not`, cannot produce a `z` output — only real
  tri-state primitives (`bufif0`/`bufif1`, see 025) can.

## 14. Common Mistakes

* Assuming a buffer is "free" or meaningless in RTL — in a real design,
  omitting deliberate buffering on long, high-fanout nets can cause timing
  failures that only appear after physical implementation.
* Writing `buf(a, y1, y2)` by mistake — gate-primitive argument order
  matters: the *last* terminal is always the input, not the first.
* Confusing this `buf` primitive with a hardware buffer/queue data
  structure — here "buffer" means a signal-repeating gate.

## 15. Possible Improvements

* Add a `#(delay)` on the `buf` instance to model an explicit buffer delay
  for glitch/hazard experiments (see 031).
* Show an N-way fanout buffer tree feeding several loads.

## 16. What This Program Teaches

* Gate-level primitive instantiation syntax and its positional port order.
* That a primitive can have multiple output terminals.
* Why buffers exist physically even though they are logical no-ops.

## 17. Industry Relevance

Clock-tree synthesis and fanout buffering are standard steps in every ASIC
and FPGA physical-design flow; understanding that a buffer is an electrical
component, not just a logic no-op, is foundational for timing closure.

## 18. How to Run

```bash
python3 scripts/run.py 024
cd 01-basic-gates/024-buffer-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/buffer_gate.v tb/tb_buffer_gate.v
vvp build/sim.vvp +vcd
```
