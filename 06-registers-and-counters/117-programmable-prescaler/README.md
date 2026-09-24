# 117 — Programmable Prescaler

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Intermediate | `prescaler` | `src/prescaler.v` | `tb/tb_prescaler.v` |

## 1. Objective

Turn program 116's fixed-`PERIOD` tick generator into a runtime-
configurable one — the divide ratio is a register value, settable while
the design is running, not fixed at compile time.

## 2. What the Design Does

`prescaler` counts `0..reload_val` and produces a one-cycle `tick`
pulse the cycle after the count reaches `reload_val`, dividing the
clock by `reload_val+1`. Unlike program 116's combinational `tick`,
this one is registered.

## 3. Why It Is Useful

Real timer/counter peripherals (and this program's name directly) are
almost always software-programmable — a CPU or configuration register
sets the divide ratio at runtime rather than it being fixed in the
hardware description, letting the same peripheral serve many different
timing requirements.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | prescaler enable |
| `reload_val` | input | `WIDTH` | divide by `reload_val+1` |
| `tick` | output | 1 | registered one-cycle pulse every `reload_val+1` cycles |

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `cnt` | `WIDTH` | counts `0..reload_val` |

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n)                cnt<=0; tick<=0
    else if (en)
        if (cnt == reload_val)  cnt<=0; tick<=1
        else                    cnt<=cnt+1; tick<=0
    else                        tick<=0
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A runtime input (`reload_val`) taking the place of a compile-time
  `parameter` for the divide ratio, contrasted directly with program
  116's fixed `PERIOD`.
* A registered (not combinational) status pulse — a deliberate design
  choice difference from program 116's `tick`, documented explicitly
  rather than left as an unremarked inconsistency between the two
  otherwise-similar programs.

## 9. Source Code Explanation

```verilog
if (cnt == reload_val) begin
    cnt  <= {WIDTH{1'b0}};
    tick <= 1'b1;
end else begin
    cnt  <= cnt + 1'b1;
    tick <= 1'b0;
end
```
Because `tick` is assigned inside the same clocked block as `cnt`
(rather than derived combinationally from it, as program 116's `tick`
is), it becomes visible one cycle *after* `cnt` reaches `reload_val` —
still exactly one cycle wide, just registered rather than combinational.
`reload_val=0` is a valid edge case: the counter never leaves 0, and
`tick` pulses every single cycle (divide-by-1).

## 10. Testbench Explanation

`tb_prescaler` runs several different runtime `reload_val` settings
(including 0, the divide-by-1 edge case, plus 3, 9, and 24), each from a
fresh reset, checking consecutive tick spacing matches `reload_val+1`
exactly, plus a hold check with `en=0`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | reload=0 | divide-by-1 | tick every cycle |
| 2 | reload=3 | divide-by-4 | tick every 4 cycles |
| 3 | reload=9 | divide-by-10 | tick every 10 cycles |
| 4 | reload=24 | divide-by-25 | tick every 25 cycles |
| 5 | hold | en=0 | no ticks |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 117` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_prescaler` — **PASS**

```text
TEST PASSED: 235 checks
tb/tb_prescaler.v:77: $finish called at 2356000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 49 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `reload_val` is sampled continuously (not latched on a separate
  "commit" signal), so changing it while the prescaler is running takes
  effect on the very next comparison — acceptable for many uses, but
  worth knowing if a use case needs the current count cycle to finish
  with the *old* ratio before adopting a new one.

## 14. Common Mistakes

* Changing `reload_val` mid-count and assuming the current cycle
  completes with the old ratio — with this design, the next `cnt ==
  reload_val` comparison always uses whatever `reload_val` currently is.
* Confusing this registered `tick` with program 116's combinational
  one when reusing code between the two — they differ by exactly one
  cycle of timing.

## 15. Possible Improvements

* Add a `reload_val` double-buffering scheme (latch the new value only
  at the next wrap) for glitch-free ratio changes mid-count.

## 16. What This Program Teaches

* Making a previously fixed-parameter design runtime-configurable.
* Registered vs. combinational status-pulse timing as a deliberate,
  documented design choice, not an incidental detail.

## 17. Industry Relevance

Programmable prescalers are standard in real timer/counter peripherals
(classic 8253/8254-style programmable interval timers, and virtually
every microcontroller's timer block) — software configures the divide
ratio via a register write, exactly as `reload_val` does here.

## 18. How to Run

```bash
python3 scripts/run.py 117            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/117-programmable-prescaler && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/prescaler.v tb/tb_prescaler.v
vvp build/sim.vvp +vcd
```
