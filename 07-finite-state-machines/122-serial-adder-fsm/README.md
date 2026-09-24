# 122 — Serial Adder FSM

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `serial_adder` | `src/serial_adder.v` | `tb/tb_serial_adder.v` |

## 1. Objective

Show that a full adder's carry chain — normally rippled through
combinational logic across bit *positions* (program 064) — can instead
be rippled through a 2-state Mealy FSM across clock *cycles*, trading one
bit per clock for a hardware footprint independent of operand width.

## 2. What the Design Does

`serial_adder` adds two numbers presented one bit per clock, LSB first.
`start` (pulsed for one cycle before the first bit pair) synchronously
clears the carry state. Each subsequent cycle, `sum = a ^ b ^ carry`
(the Mealy output, valid combinationally the same cycle `a`/`b` are
presented) and the carry state updates to `majority(a, b, carry)` for
the next bit.

## 3. Why It Is Useful

Serial arithmetic trades latency (N cycles for an N-bit result) for
area — one full-adder's worth of logic regardless of operand width —
which is exactly the same trade-off explored more generally by the
FSM+datapath ("FSMD") sequential multiplier/divider programs later in
category 12. It is also the smallest possible illustration of a Mealy
FSM implementing real arithmetic instead of a toy pattern detector.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `start` | input | 1 | pulse one cycle before bit 0 of a new addition; clears carry to 0 |
| `a`, `b` | input | 1 each | operand bits, LSB first |
| `sum` | output | 1 | Mealy sum output for the current bit |
| `carry_out` | output | 1 | registered carry (into the next bit, or the final carry after the last bit) |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `carry_state`, `carry_next` | 1 | current / next carry (the FSM's only state) |

## 6. Architecture

```
        a=b=0                                majority(a,b,carry)
   C0 -----------> C0          sum = a^b^carry_state (Mealy)
   C0 --a^b=1----> C1
   C1 --a&b=1 or (a^b)&carry=1--> C1
   C1 --else------------------> C0
```
Equivalently: `carry_next = (a&b) | (a&carry) | (b&carry)` — the
standard full-adder carry equation, here computed once per cycle instead
of once per bit position.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A 1-bit FSM state register doubling as an arithmetic carry — the
  smallest possible non-trivial Mealy FSM.
* `sum` as a Mealy (state + input) combinational output, `carry_out` as
  a plain registered-state readout, both driven by the same
  `carry_state` bit.
* A synchronous, input-driven reset (`start`) layered on top of the
  module's asynchronous `rst_n`, distinguishing "power-on reset" from
  "begin a new operation."

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     carry_state <= C0;
    else if (start) carry_state <= C0;
    else            carry_state <= carry_next;
end
```
Two different reset mechanisms are both present and clearly
distinguished: `rst_n` is the module-wide asynchronous reset (per
CLAUDE.md §4's house style), while `start` is an ordinary synchronous
input that also happens to force the carry to 0 — necessary because,
unlike a plain reset, `start` must be usable *between* additions without
disturbing the clock.

```verilog
assign sum       = a ^ b ^ carry_state;
assign carry_out = carry_state;
```
`sum` reacts immediately (combinationally) to the current bit pair,
while `carry_out` simply exposes the registered carry — after the last
bit of an addition, `carry_out` holds the true final carry bit.

## 10. Testbench Explanation

`tb_serial_adder` computes `expected = a_val + b_val` once per test case
using plain Verilog arithmetic on a 64-bit `reg` (independent of the
DUT's bit-serial mechanism), pulses `start`, then feeds each operand bit
LSB first, checking `sum` against `expected[i]` every cycle and
`carry_out` against `expected[width]` (the true carry-out bit) after the
last bit. Coverage: directed edge cases (`0+0`, max+max full carry
propagation, alternating bits with no carry, a single ripple through all
bits), plus 150 random 8-bit and 150 random 16-bit operand pairs (fixed
seed, reproducible).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | 0+0 | all zero bits | sum all 0, no carry |
| 2 | max+max | `255+255` (8-bit) | sum bits + carry match `510` |
| 3 | max+1 | `255+1` | rolls over, `carry_out=1` |
| 4 | no-carry pattern | `170+85` (alternating) | sum bits match, no carry ever set |
| 5 | random | 150×8-bit + 150×16-bit pairs | every bit and final carry match `a+b` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 122` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_serial_adder` — **PASS**

```text
TEST PASSED: 3954 checks
tb/tb_serial_adder.v:83: $finish called at 39546000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 9 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `start` must be pulsed (not held) — holding it high would continuously
  clear the carry on every clock, never allowing addition to progress;
  this is exactly the kind of "pulse vs. level" control-signal
  distinction real FSM-driven datapaths must get right.
* Trading N cycles of latency for O(1) hardware area is the entire point
  of this design; it is not intended to be faster than a combinational
  ripple-carry adder for small widths.

## 14. Common Mistakes

* Holding `start` high across multiple cycles instead of pulsing it for
  exactly one — silently corrupts every addition after the first bit.
* Feeding operand bits MSB-first (the natural order for the FSM
  sequence-detector programs in this same category) instead of LSB-first
  — arithmetic carry propagation requires LSB-first, the opposite
  convention from 118/119/121's MSB-first serial reads.

## 15. Possible Improvements

* Add a `done` output asserted after exactly `width` bits, generated by
  an external counter, so a consumer does not need to track width itself.
* Extend to a serial adder/subtractor by conditionally inverting `b` and
  seeding the initial carry to 1 (two's-complement subtraction).

## 16. What This Program Teaches

* Implementing real bit-serial arithmetic as a small Mealy FSM.
* The area/latency trade-off between bit-parallel and bit-serial
  datapaths, using the exact same full-adder equations as program 063.
* Distinguishing an operation-scoped synchronous reset from the module's
  power-on asynchronous reset.

## 17. Industry Relevance

Bit-serial arithmetic was standard in area-constrained historical designs
and remains relevant today in extremely resource-constrained logic (bit
banging protocols, minimal microcontroller ALUs, some cryptographic
cores) wherever trading cycles for gates is the right trade-off.

## 18. How to Run

```bash
python3 scripts/run.py 122            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/122-serial-adder-fsm && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/serial_adder.v tb/tb_serial_adder.v
vvp build/sim.vvp +vcd
```
