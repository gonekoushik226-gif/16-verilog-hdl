# 102 — Universal Shift Register

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `universal_shift_reg` | `src/universal_shift_reg.v` | `tb/tb_universal_shift_reg.v` |

## 1. Objective

Combine programs 098-101's separate register/SISO/SIPO/PISO designs into
one configurable block, matching the classic 74194-style universal shift
register.

## 2. What the Design Does

`universal_shift_reg` selects one of four operations per cycle via
`mode`: hold, shift-right (new bit enters at the MSB), shift-left (new
bit enters at the LSB), or parallel load.

## 3. Why It Is Useful

Real shift-register ICs (and many RTL shift registers) support all of
these modes in one configurable block rather than as separate fixed-
function modules — useful whenever a design needs to switch between
serial and parallel access, or between shift directions, at run time.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `mode` | input | 2 | 00=hold 01=shift-right 10=shift-left 11=load |
| `serial_in_left` | input | 1 | enters at the LSB when shifting left |
| `serial_in_right` | input | 1 | enters at the MSB when shifting right |
| `parallel_in` | input | `WIDTH` | word to load |
| `q` | output | `WIDTH` | register contents |

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

None beyond `q` itself.

## 6. Architecture

```
mode  action
00    hold        q <= q
01    shift-right q <= {serial_in_right, q[WIDTH-1:1]}
10    shift-left  q <= {q[WIDTH-2:0], serial_in_left}
11    load        q <= parallel_in
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A `case` statement selecting between four distinct next-state
  expressions in one clocked block, unifying the separate patterns from
  programs 098-101 into one module.

## 9. Source Code Explanation

```verilog
case (mode)
    MODE_HOLD:  q <= q;
    MODE_RIGHT: q <= {serial_in_right, q[WIDTH-1:1]};
    MODE_LEFT:  q <= {q[WIDTH-2:0], serial_in_left};
    MODE_LOAD:  q <= parallel_in;
endcase
```
Each branch is exactly the next-state expression from one of programs
098 (load), 099/100 (shift), applied conditionally based on `mode`.

## 10. Testbench Explanation

`tb_universal_shift_reg` exercises load, hold, 8 cycles of shift-right
(tracking the expected value bit by bit against `serial_in_right`), 8
cycles of shift-left (mirror image), and finally 20 cycles of randomized
mode/input selection, all checked against a software reference register
maintained the same way as the RTL's own `case` logic.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | load | mode=11 | q <= parallel_in |
| 2 | hold | mode=00 | q unchanged |
| 3 | shift-right | mode=01 x8 | q shifts right, serial_in_right enters MSB |
| 4 | shift-left | mode=10 x8 | q shifts left, serial_in_left enters LSB |
| 5 | random | 20 random mode/input cycles | q matches software reference |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 102` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_universal_shift_reg` — **PASS**

```text
TEST PASSED: 41 checks
tb/tb_universal_shift_reg.v:95: $finish called at 406000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 44 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Two separate serial inputs (`serial_in_left`, `serial_in_right`)
  rather than one shared pin — clearer in simulation/testing, at the
  cost of one extra port versus some real 74194 pinouts that share a
  single "serial data" pin with external steering logic.

## 14. Common Mistakes

* Swapping which serial input feeds which shift direction — shifting
  right should pull in a new MSB, not a new LSB, and vice versa for
  shifting left.

## 15. Possible Improvements

* Add a fifth mode for synchronous clear, distinct from full parallel
  load.

## 16. What This Program Teaches

* Selecting between multiple next-state behaviors with one `case`
  statement, unifying previously-separate designs into a configurable
  block.

## 17. Industry Relevance

Directly modeled on the 74194 universal shift register, a real, widely
used TTL/CMOS part; the same configurable-mode pattern appears in modern
RTL wherever a register needs runtime-selectable behavior.

## 18. How to Run

```bash
python3 scripts/run.py 102            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/102-universal-shift-register && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/universal_shift_reg.v tb/tb_universal_shift_reg.v
vvp build/sim.vvp +vcd
```
