# 096 — Pipeline Registers, Introduction

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Elementary | `pipeline3` | `src/pipe_stage.v`, `src/pipeline3.v` | `tb/tb_pipeline3.v` |

## 1. Objective

Chain plain register stages into a fixed-latency pipeline and measure
the two things that matter about one: latency (how long one item takes
to cross) and throughput (how often a new item can enter).

## 2. What the Design Does

`pipe_stage` is one generic `WIDTH`-bit register plus a `valid` bit.
`pipeline3` chains three of them: data entering on cycle N reaches the
output on cycle N+3, but a brand-new input can still be accepted on
every single cycle — the three stages operate independently and
concurrently, each only ever talking to its immediate neighbor.

## 3. Why It Is Useful

Pipelining is the standard technique for increasing throughput without
needing every operation to finish in one cycle: break work into stages,
register between them, and let different stages work on different items
simultaneously. This program isolates the *registering* half of that
idea (no actual computation happens in any stage) before later
programs add real logic between pipeline stages.

## 4. Interface

**`pipeline3`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `in_valid` | input | 1 | 1 when `in_data` is a real input this cycle |
| `in_data` | input | `WIDTH` | data entering the pipeline |
| `out_valid` | output | 1 | 1 when `out_data` is a real (not just reset-drained) output |
| `out_data` | output | `WIDTH` | data leaving the pipeline, 3 cycles after entering |

**`pipe_stage`**: same port shape, one stage.

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `v1`, `v2` | valid bits between stage1/stage2 and stage2/stage3 |
| `d1`, `d2` | data between stage1/stage2 and stage2/stage3 |

## 6. Architecture

```
in_data,in_valid -[pipe_stage 1]- d1,v1 -[pipe_stage 2]- d2,v2 -[pipe_stage 3]- out_data,out_valid
```
Each stage is an independent register bank; the only coupling between
stages is that stage N+1's input is stage N's output from the previous
cycle.

## 7. Module Hierarchy and Connections

```
pipeline3 #(.WIDTH(N))
├── stage1 : pipe_stage #(.WIDTH(N)) (in_data,  in_valid) -> d1, v1
├── stage2 : pipe_stage #(.WIDTH(N)) (d1, v1)             -> d2, v2
└── stage3 : pipe_stage #(.WIDTH(N)) (d2, v2)             -> out_data, out_valid
```

## 8. Verilog Concepts Used

* A minimal, reusable register-stage module instantiated multiple times
  to build a longer pipeline, exactly the way `rca_n` (program 065)
  chains adder cells.
* Carrying a `valid` bit alongside data through every stage, so a
  consumer can distinguish "real output" from "still draining after
  reset" without needing to know the pipeline's exact depth.

## 9. Source Code Explanation

`pipe_stage` is a two-signal D flip-flop bank (`out_valid`/`out_data`,
each just registering `in_valid`/`in_data`). `pipeline3` wires three of
them so each stage's output feeds the next stage's input, with no
combinational logic at all between them — this program is deliberately
about the registering/latency/throughput structure alone.

## 10. Testbench Explanation

`tb_pipeline3` pushes a distinct known value into the pipeline on every
cycle (recording each one plus its valid bit in a software queue),
checking `LATENCY=3` cycles later that the output matches the queued
entry from exactly that many cycles ago — including a stretch where
`in_valid` drops for several cycles, confirming the invalid bubble also
takes exactly 3 cycles to ripple through and reappear as `out_valid=0`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | continuous back-to-back | a new value every cycle for 20 cycles | each value reappears exactly 3 cycles later |
| 2 | invalid bubble | in_valid=0 for 4 cycles | out_valid=0 exactly 3 cycles later, for 4 cycles |
| 3 | resume | valid data again | pipeline resumes normal 3-cycle latency immediately |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 096` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_pipeline3` — **PASS**

```text
TEST PASSED: 28 checks
tb/tb_pipeline3.v:96: $finish called at 306000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 27 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Latency (3 cycles, fixed) and throughput (1 new item per cycle,
  unlimited) are independent properties of a pipeline — this design
  demonstrates both are achieved simultaneously simply by never letting
  one stage depend on more than its immediate neighbor.
* No backpressure/stall support here — every stage always accepts new
  data every cycle (see program 192's valid/ready handshake for a
  pipeline that can stall).

## 14. Common Mistakes

* Off-by-one errors when computing "which input corresponds to this
  cycle's output" — exactly the bug this program's own testbench
  originally had (comparing against the wrong queue index because the
  loop counter and "edges elapsed since reset" were offset by one),
  fixed by re-deriving the exact cycle relationship between when an
  input is pushed and when the corresponding output becomes checkable.
* Confusing a 3-stage pipeline's latency with a requirement that only
  one item can be "in flight" at a time — in fact all 3 stages hold
  different items simultaneously once the pipeline is full.

## 15. Possible Improvements

* Add a stall/flush control (program 247's pipeline-register-stage
  explores this further) or genuinely different processing at each
  stage instead of plain pass-through registers.

## 16. What This Program Teaches

* The latency-vs-throughput distinction in a pipelined datapath.
* Carrying a valid bit through a pipeline to track meaningful vs.
  draining/bubble data.

## 17. Industry Relevance

Every pipelined processor datapath (categories 13-15) and most
high-throughput streaming hardware (FIFOs, DSP chains, network packet
processors) are built from exactly this register-per-stage structure,
usually with real computation — not just pass-through — inserted between
stages.

## 18. How to Run

```bash
python3 scripts/run.py 096            # compile, simulate, synthesize, lint
cd 05-sequential-logic/096-pipeline-registers-intro && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/pipe_stage.v src/pipeline3.v tb/tb_pipeline3.v
vvp build/sim.vvp +vcd
```
