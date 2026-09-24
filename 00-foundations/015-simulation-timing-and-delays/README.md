# 015 — Simulation Timing and Delays

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · Synthesis: not applicable · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Intermediate | `delay_models` (simulation-only) | `src/delay_models.v` | `tb/tb_delay_models.v` |

## 1. Objective

Understand how simulated time works: `` `timescale ``, `#` delays, the
difference between inertial and transport delay, and when `$display`,
`$strobe` and `$monitor` print.

## 2. What the Design Does

`delay_models` delays its input by 5 ns in two different ways:

* `inertial_out` — `assign #5`: a change must remain stable for 5 ns to
  reach the output. The 2 ns pulse in the test is **filtered out**.
* `transport_out` — `transport_out <= #5 in_sig`: every change is scheduled
  5 ns later, so the 2 ns pulse **appears** at the output from 35 to 37 ns.

This module is a timing *model*; it is not meant for synthesis.

## 3. Why It Is Useful

Delays are used in testbenches (clock generation, stimulus timing), in
behavioural models of external devices (memories, sensors), and in
gate-level simulation with back-annotated timing. Misunderstanding them leads
to testbenches that pass for the wrong reason or to "fixes" that hide real
race conditions.

## 4. Interface

| Port | Dir | Width | Description |
|---|---|---|---|
| `in_sig` | in | 1 | Input waveform |
| `inertial_out` | out | 1 | `in_sig` delayed by 5 ns, short pulses filtered |
| `transport_out` | out | 1 | `in_sig` delayed by 5 ns, every edge kept |

## 5. Internal Signals

None.

## 6. Architecture

```
in_sig:        ____|‾‾‾‾‾‾‾‾‾‾|__________|‾‾|____________
               0   10         20         30 32
inertial_out:  ________|‾‾‾‾‾‾‾‾‾‾|___________________     (15–25; 2 ns pulse lost)
transport_out: ________|‾‾‾‾‾‾‾‾‾‾|__________|‾‾|______     (15–25 and 35–37)
```

## 7. Module Hierarchy and Connections

```
tb_delay_models
└── dut : delay_models
```

## 8. Verilog Concepts Used

* `` `timescale 1ns / 1ps `` — `#5` means 5 ns; times are rounded to 1 ps.
* Continuous-assignment delay `assign #5` (inertial).
* Intra-assignment delay on a non-blocking assignment `<= #5` (transport).
* `$monitor` / `$monitoroff`, `$display`, `$strobe`, `$timeformat`.
* Waiting until an absolute time with `#(t - $time)`.

## 9. Source Code Explanation

```verilog
assign #5 inertial_out = in_sig;
```
When `in_sig` changes, the simulator schedules the new value 5 ns later. If
`in_sig` changes again before then, the pending event is **cancelled**. That
is the inertial model: a real gate needs a minimum input pulse width to
switch its output.

```verilog
always @(in_sig)
    transport_out <= #5 in_sig;
```
Each change of `in_sig` evaluates the right-hand side immediately and queues
an update 5 ns later. Non-blocking assignments do not cancel each other, so
every pulse is reproduced (the transport model of a wire or delay line).

A blocking version (`#5 transport_out = in_sig;`) would behave differently
again: the `always` block would be stuck waiting for 5 ns and would miss
input changes during that time.

## 10. Testbench Explanation

* One `initial` block creates the stimulus: 0 at 0 ns, a 10 ns pulse at 10 ns
  and a 2 ns pulse at 30 ns.
* `$monitor` prints a line at every time step in which a listed signal
  changes; `$timeformat(-9, 0, " ns", 6)` prints times in ns.
* `check_at(t, …)` waits until absolute time `t` with `#(t - $time)` and
  compares both outputs. Checks are placed 1 ns before and after every
  expected edge, so an off-by-one-nanosecond delay would fail.
* At 1 ns both outputs must still be `x`: nothing has propagated yet.
* **`$display` vs `$strobe`:** after `nb_demo <= 1`, `$display` in the same
  time step prints the old value 0; `$strobe` prints at the end of the time
  step and shows 1.

## 11. Test Cases and Expected Results

| # | Time (ns) | inertial_out | transport_out | Reason |
|---|---|---|---|---|
| 1 | 1 | x | x | initial value not yet propagated |
| 2 | 6 | 0 | 0 | 0 arrives after 5 ns |
| 3 | 14 / 16 | 0 / 1 | 0 / 1 | rising edge at 10 appears at 15 |
| 4 | 24 / 26 | 1 / 0 | 1 / 0 | falling edge at 20 appears at 25 |
| 5 | 36 | 0 | 1 | 2 ns pulse: filtered vs transported |
| 6 | 38 | 0 | 0 | transported pulse ended at 37 |
| 7 | — | — | — | non-blocking update visible after the time step |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 015` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_delay_models` — **PASS**

```text
0 ns  in_sig=0 inertial_out=x transport_out=x
  5 ns  in_sig=0 inertial_out=0 transport_out=0
 10 ns  in_sig=1 inertial_out=0 transport_out=0
 15 ns  in_sig=1 inertial_out=1 transport_out=1
 20 ns  in_sig=0 inertial_out=1 transport_out=1
 25 ns  in_sig=0 inertial_out=0 transport_out=0
 30 ns  in_sig=1 inertial_out=0 transport_out=0
 32 ns  in_sig=0 inertial_out=0 transport_out=0
 35 ns  in_sig=0 inertial_out=0 transport_out=1
 37 ns  in_sig=0 inertial_out=0 transport_out=0
$display sees nb_demo=0 (old value)
$strobe  sees nb_demo=1 (new value)
TEST PASSED: 10 checks
tb/tb_delay_models.v:76: $finish called at 40000 (1ps)
```

Synthesis: not applicable — uses # delays to model timing; simulation-only by design
<!-- SIM-RESULTS:END -->

Synthesis and lint are disabled in `program.conf` because the module exists
only to model delays; synthesis tools ignore `#` delays.

## 13. Design Considerations

* Never rely on `#` delays for functionality in RTL: synthesis discards them,
  so simulation and hardware would disagree.
* Adding `#1` to RTL assignments "to fix a race" hides the real problem — use
  non-blocking assignments and drive testbench inputs away from the active
  clock edge instead.
* Choose a precision fine enough for the delays used; `#0.3` with a 1 ns
  precision rounds to 0.

## 14. Common Mistakes

* Expecting a short pulse to pass through `assign #d` (it is filtered).
* Mixing modules with different `` `timescale `` settings unknowingly — the
  same `#5` means different times in different files.
* Using `$display` to observe values just written with `<=` in the same time
  step (use `$strobe` or wait).
* Leaving `$monitor` running and flooding the log.

## 15. Possible Improvements

* Add `specify` blocks with path delays for gate-level-style modelling.
* Compare with a blocking intra-assignment delay to show missed events.

## 16. What This Program Teaches

* Simulation time units and precision.
* Inertial vs transport delay.
* Verilog's event regions as seen through `$display`/`$strobe`.

## 17. Industry Relevance

Gate-level simulation with SDF back-annotation uses these delay semantics
(including pulse rejection limits) to validate timing-sensitive behaviour.
Behavioural models of memories and PHYs use transport-style delays to
reproduce device timing.

## 18. How to Run

```bash
python3 scripts/run.py 015
cd 00-foundations/015-simulation-timing-and-delays && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/delay_models.v tb/tb_delay_models.v
vvp build/sim.vvp +vcd
```
