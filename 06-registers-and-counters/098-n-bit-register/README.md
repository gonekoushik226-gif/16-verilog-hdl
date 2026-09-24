# 098 — N-bit Register

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Beginner | `register_n` | `src/register_n.v` | `tb/tb_register_n.v` |

## 1. Objective

Generalize program 087's single-bit D flip-flop and program 089's
clock-enable pattern to a whole `WIDTH`-bit data bus — the starting
point for every register, counter, and pipeline stage in this category.

## 2. What the Design Does

`register_n` loads `d` into `q` on a rising `clk` edge whenever `en=1`;
otherwise `q` holds. `rst_n` asynchronously clears `q` to 0.

## 3. Why It Is Useful

Every wider sequential element in this repository — counters, shift
registers, pipeline stages, memory-mapped configuration registers — is
built from exactly this parallel-load-with-enable pattern, just with
different next-value logic feeding `d`.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | load enable |
| `d` | input | `WIDTH` | data to load |
| `q` | output | `WIDTH` | registered value |

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

None — `q` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)  q <= 0
    else if (en) q <= d
    else         q <= q   (implicit hold)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* `parameter WIDTH` sizing every port from one declaration.
* Identical control structure to program 089's `dff_en`, just widened
  from 1 bit to `WIDTH` bits.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  q <= {WIDTH{1'b0}};
    else if (en) q <= d;
end
```
`{WIDTH{1'b0}}` is a replication producing a `WIDTH`-bit all-zero
constant regardless of the parameter's value — the width-generic
equivalent of a plain `1'b0` literal.

## 10. Testbench Explanation

`tb_register_n` checks reset, explicit hold (`en=0` with `d` still
changing), explicit load, then 20 cycles of randomized `en`/`d` compared
against a software reference register maintained in the testbench, plus
a final check that reset overrides an asserted enable.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | reset | rst_n=0 | q=0 |
| 2 | load | en=1 | q <= d |
| 3 | hold | en=0, d changing | q unchanged |
| 4 | random | 20 random (en,d) cycles | q matches software reference |
| 5 | reset overrides enable | rst_n=0, en=1 | q forced to 0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 098` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_register_n` — **PASS**

```text
TEST PASSED: 26 checks
tb/tb_register_n.v:61: $finish called at 247000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 8 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This is this category's canonical building block; later programs
  reference it directly rather than re-deriving the same pattern.

## 14. Common Mistakes

* Forgetting the enable and always loading `d` every cycle — silently
  turns a controllable register into a plain unconditional pass-through.

## 15. Possible Improvements

* Add a synchronous clear separate from `en`, or a byte-enable variant
  (see program 140).

## 16. What This Program Teaches

* Parameterized, enable-gated parallel register loading as the base
  building block for this entire category.

## 17. Industry Relevance

Parallel-load registers with enable are the single most common
sequential element in real RTL — configuration registers, pipeline
latches, and accumulator stages are all variations on this exact
pattern.

## 18. How to Run

```bash
python3 scripts/run.py 098            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/098-n-bit-register && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/register_n.v tb/tb_register_n.v
vvp build/sim.vvp +vcd
```
