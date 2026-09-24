# 097 — Clocked Sequential Circuit Analysis

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Intermediate | `seq_circuit` | `src/d_ff.v`, `src/seq_circuit.v` | `tb/tb_seq_circuit.v` |

## 1. Objective

Practice the reverse of everything else in this category: given a
gate-plus-flip-flop circuit, derive its state table (next-state and
output equations) by reading the gates, then verify that derivation
exhaustively against the actual hardware — the standard "sequential
circuit analysis" exercise from a digital logic course.

## 2. What the Design Does

`seq_circuit` has two D flip-flops (state `q1,q0`) and one input `x`.
Its next-state and output logic — `d1 = q1 XOR (q0 AND x)`, `d0 =
NOT(q0) OR (q1 AND NOT x)`, `y = q1 AND q0` — are exactly the equations
a state-table derivation would read directly off this circuit's gates.

## 3. Why It Is Useful

Reading a schematic (or RTL) and reconstructing its behavior as a state
table is a core digital-design skill, distinct from *designing* a
circuit from a table (which most of this repository's other sequential
programs do). This program provides a small, fixed circuit specifically
so that skill can be practiced and checked mechanically.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `x` | input | 1 | circuit input |
| `y` | output | 1 | circuit output (Moore: depends on state only) |
| `state` | output | 2 | `{q1,q0}`, exposed directly for analysis/waveform inspection |

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `q1`, `q0` | the two flip-flops' registered state |
| `d1`, `d0` | next-state combinational logic feeding each flip-flop |

## 6. Architecture

```
d1 = q1 XOR (q0 AND x)
d0 = NOT(q0) OR (q1 AND NOT x)
y  = q1 AND q0                    (Moore: output depends only on state)
```
This *is* the state table, expressed as equations rather than a 4-row x
2-column table — the two representations are equivalent, and deriving
one from the other (in either direction) is the exercise this program
supports.

## 7. Module Hierarchy and Connections

```
seq_circuit
├── ff1 : d_ff (d1) -> q1
└── ff0 : d_ff (d0) -> q0
```

## 8. Verilog Concepts Used

* Hierarchical `force`/`release` on internal flip-flop state
  (`dut.ff1.q`, `dut.ff0.q`) to directly set an arbitrary state for
  testing, rather than being limited to states reachable by a normal
  stimulus sequence — the same technique program 132 uses to reach
  illegal FSM states.
* A Verilog `function` (`expected_next`) encoding the hand-derived
  next-state equations as an independent reference model.

## 9. Source Code Explanation

See §6 — the module is a direct, minimal transcription of the derived
equations feeding two plain D flip-flops (program 087's design, reused
as `d_ff`).

## 10. Testbench Explanation

`tb_seq_circuit` exhaustively forces every one of the 4 possible
`(q1,q0)` states via hierarchical `force` on the internal flip-flops
(using intermediate `reg` variables to hold the forced value, avoiding a
tool limitation with forcing directly from a loop-variable bit-select),
applies both values of `x`, checks the *combinational* output `y`
immediately, releases the force, and checks the *next state* reached
after one clock edge — all against the hand-derived equations
implemented independently as Verilog functions.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | output, every state | all 4 forced states | y matches `q1 AND q0` |
| 2 | next state, every (state,input) | all 4 states x 2 values of x | next state matches the derived equations |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 097` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_seq_circuit` — **PASS**

```text
TEST PASSED: 16 checks
tb/tb_seq_circuit.v:84: $finish called at 76000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 7 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Forcing internal flip-flop state directly is what makes *exhaustive*
  state-table verification possible for a circuit whose natural
  transitions might not reach every state from reset — a purely
  input-driven testbench could only check states actually reachable by
  some input sequence.

## 14. Common Mistakes

* Deriving the state table from the RTL's *variable names* rather than
  its actual gate equations (e.g. assuming `d1`/`d0` behave a certain
  way because of what they're called) — always trace the actual
  Boolean expression.
* Forcing a loop variable's bit-select directly in a `force` statement —
  this hit an Icarus Verilog tool limitation ("procedural continuous
  assignments... RHS... evaluated once") in an earlier version of this
  program's testbench; assigning the forced value to a plain `reg`
  first and forcing from that avoided it.

## 15. Possible Improvements

* Extend to a Mealy variant (`y` also depending on `x`) to practice the
  Moore/Mealy distinction directly on this same circuit.

## 16. What This Program Teaches

* Reading gate-level next-state/output logic and reconstructing it as a
  state table (or vice versa).
* Using `force`/`release` for exhaustive state-space testing independent
  of reachability from reset.

## 17. Industry Relevance

Analyzing an existing sequential circuit (reverse-engineering its state
table from a schematic, netlist, or unfamiliar RTL) is a routine task in
debugging, code review, and working with legacy hardware designs.

## 18. How to Run

```bash
python3 scripts/run.py 097            # compile, simulate, synthesize, lint
cd 05-sequential-logic/097-clocked-sequential-circuit-analysis && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/d_ff.v src/seq_circuit.v tb/tb_seq_circuit.v
vvp build/sim.vvp +vcd
```
