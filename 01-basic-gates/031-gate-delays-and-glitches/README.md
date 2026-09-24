# 031 — Gate Delays and Glitches

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · Synthesis: not applicable · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Intermediate | `hazard_circuit`, `hazard_free_circuit` | `src/hazard_circuit.v`, `src/hazard_free_circuit.v` | `tb/tb_hazard.v` |

## 1. Objective

Use explicit per-gate propagation delays to produce and observe a real
**static-1 hazard** (a momentary, unwanted glitch to 0 in a signal that
should stay logically 1), then fix it with the classical **consensus
term**, and prove both facts by counting glitches in simulation instead of
only reasoning about them on paper.

## 2. What the Design Does

Both circuits implement the same Boolean function,
`f(a,b,c) = ab + b'c`, but with different gate structures:

* `hazard_circuit`: exactly `y = ab + b'c`, built from `not`/`and`/`or`
  primitives with explicit delays (`not` 2ns, `and` 3ns, `or` 2ns).
* `hazard_free_circuit`: `y = ab + b'c + ac` — the same gates plus one
  redundant **consensus term** `ac`, with the same delays.

`ac` is algebraically redundant: for every one of the 8 input
combinations, `ab + b'c` already equals `ab + b'c + ac` (this is verified
exhaustively in §11). But when `a = c = 1` and `b` changes, `ac` is
constant at 1 throughout the transition, which holds the final OR gate's
output at 1 while the other two terms are switching — removing the
hazard that `hazard_circuit` exhibits in that same scenario.

## 3. Why It Is Useful

Static hazards are a real phenomenon in asynchronous and combinational
logic: a control signal, chip-select decode, or clock-gating enable that
glitches for a few nanoseconds can cause a downstream flip-flop to
capture the wrong value, or a clock gate to produce an unwanted extra
pulse. The consensus-term fix is the standard textbook technique for
removing them without changing the function.

## 4. Interface

Both modules share the same port list:

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b`, `c` | input | 1 | Function inputs |
| `y` | output | 1 | `ab + b'c` (plus the always-redundant `ac` term in `hazard_free_circuit`) |

No parameters.

## 5. Internal Signals

| Module | Signal | Purpose |
|---|---|---|
| both | `nb` | `b'`, delayed 2ns from any change on `b` |
| both | `t1` | `a & b`, delayed 3ns |
| both | `t2` | `b' & c`, delayed 3ns from `nb`/`c` |
| `hazard_free_circuit` | `t3` | consensus term `a & c`, delayed 3ns |

## 6. Architecture

```
hazard_circuit:
  b ──[NOT #2]── nb ──┐
  a ──────────────┐   ├──[AND #3]── t2 ──┐
                   ├───┼──[AND #3]── t1 ──┼──[OR #2]── y
  b ───────────────┘   │                  │
  c ────────────────────┘                  (only t1, t2)

hazard_free_circuit:  same t1, t2, plus
  a,c ──[AND #3]── t3 ──────────────────────┘ (added into the OR)
```

## 7. Module Hierarchy and Connections

```
tb_hazard
├── dut_h : hazard_circuit
│   ├── g_inv  : not #(2)  (nb, b)
│   ├── g_and1 : and #(3)  (t1, a, b)
│   ├── g_and2 : and #(3)  (t2, nb, c)
│   └── g_or   : or  #(2)  (y, t1, t2)
└── dut_f : hazard_free_circuit
    ├── g_inv  : not #(2)  (nb, b)
    ├── g_and1 : and #(3)  (t1, a, b)
    ├── g_and2 : and #(3)  (t2, nb, c)
    ├── g_and3 : and #(3)  (t3, a, c)      ← consensus term
    └── g_or   : or  #(2)  (y, t1, t2, t3)
```

## 8. Verilog Concepts Used

* Per-instance gate delays on primitives: `not #(2)`, `and #(3)`,
  `or #(2)` — the delay value is simulation timing, not logic.
* Inertial delay behaviour of built-in primitives (each gate's output is
  rescheduled a fixed time after its inputs change).
* A testbench `task` that samples signals on a fixed cadence and counts
  how many samples disagree with the expected steady-state value.
* Deliberately non-integer sample offsets (`#0.5`) to avoid a
  same-time-step race between the sampling process and the DUT's
  scheduled gate updates.

## 9. Source Code Explanation

```verilog
// hazard_circuit.v
not #(2) g_inv  (nb, b);
and #(3) g_and1 (t1, a, b);
and #(3) g_and2 (t2, nb, c);
or  #(2) g_or   (y, t1, t2);
```
With `a = c = 1` and `b` falling from 1 to 0: `t1 = a&b` switches off 3ns
after `b` changes. `t2 = b'&c` can only switch on after `nb` itself
switches (2ns after `b`), plus another 3ns through the second AND — 5ns
total. Between `t=3ns` and `t=5ns` **both** `t1` and `t2` are 0, so the OR
gate's inputs are briefly `(0,0)`; propagated through the OR's own 2ns
delay, `y` dips to 0 from `t=5ns` to `t=7ns` even though the function is
logically 1 the whole time. That dip is the static-1 hazard.

```verilog
// hazard_free_circuit.v
and #(3) g_and3 (t3, a, c);   // consensus term
or  #(2) g_or   (y, t1, t2, t3);
```
`t3 = a & c` does not depend on `b` at all, so while `a = c = 1` it never
changes when `b` toggles — it simply stays 1 and keeps the OR gate's
output at 1 through the entire transition described above.

## 10. Testbench Explanation

`tb_hazard` instantiates both circuits with shared `a, b, c` and runs two
phases:

1. **Equivalence phase** — sweeps all 8 input combinations, waits 20ns
   (longer than either circuit's longest delay path) for full settling,
   and checks both circuits' settled output against the independently
   written expression `(a & b) | (~b & c)`. This proves the consensus
   term never changes the function.
2. **Hazard phase** — holds `a = c = 1`, lets everything settle, then
   flips `b` from 1 to 0 (the hazardous direction derived in §9) and calls
   `sample_and_count`, a task that samples both outputs once per
   nanosecond (offset by 0.5ns to dodge exact delay boundaries) for 15ns
   and counts samples that read anything other than 1. It asserts
   `hazard_circuit` **does** glitch (`glitches_h` must be nonzero) and
   `hazard_free_circuit` **does not** (`glitches_f` must be zero). It then
   lets the circuits settle and repeats the measurement for `b` rising
   from 0 to 1 — the non-hazardous direction for this specific delay
   arrangement — asserting only that `hazard_free_circuit` still never
   glitches (the point being that removing the hazard does not depend on
   transition direction, even though the original hazard did).

Mismatches print an `ERROR:` line; the run ends with the standard
pass/fail line.

## 11. Test Cases and Expected Results

| # | Scenario | Expected |
|---|---|---|
| 1–8 | All `a,b,c` combinations, settled | `y = ab + b'c` in both circuits (16 checks) |
| 9 | `a=c=1`, `b: 1→0`, sampled for 15ns | `hazard_circuit` glitches ≥ 1 sample; `hazard_free_circuit` glitches = 0 |
| 10 | `a=c=1`, `b: 0→1`, sampled for 15ns | `hazard_free_circuit` glitches = 0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 031` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_hazard` — **PASS**

```text
Settled-value equivalence check (ab + b'c) for all a,b,c:
  a=0 b=0 c=0 | hazard=0 hazard_free=0
  a=0 b=0 c=1 | hazard=1 hazard_free=1
  a=0 b=1 c=0 | hazard=0 hazard_free=0
  a=0 b=1 c=1 | hazard=0 hazard_free=0
  a=1 b=0 c=0 | hazard=0 hazard_free=0
  a=1 b=0 c=1 | hazard=1 hazard_free=1
  a=1 b=1 c=0 | hazard=1 hazard_free=1
  a=1 b=1 c=1 | hazard=1 hazard_free=1
b: 1 -> 0 (hazardous direction, a=c=1)
  hazard_circuit glitch samples      = 2
  hazard_free_circuit glitch samples = 0
b: 0 -> 1 (non-hazardous direction for this circuit, a=c=1)
  hazard_circuit glitch samples      = 0
  hazard_free_circuit glitch samples = 0
TEST PASSED: 19 checks
tb/tb_hazard.v:98: $finish called at 231000 (1ps)
```

Synthesis: not applicable — teaches gate delays and hazards with explicit # delays, which are not synthesizable RTL by repository convention
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This program is **simulation-verified only** (`program.conf` sets
  `SYNTH=no`): `#` delays on gate primitives are a simulation-timing
  construct with no synthesis meaning, and are otherwise forbidden in this
  repository's RTL coding standard specifically because relying on them
  for function (rather than modelled purely for teaching, as here) is not
  portable across technologies or corners.
* The specific delay numbers (2ns/3ns) were chosen only to make the hazard
  window (2ns) comfortably wider than the simulation's time resolution
  (1ps, from `` `timescale 1ns / 1ps ``); the *existence* of the hazard
  depends on relative delays through the inverting vs. non-inverting
  paths, not on these particular values.
* Real hazards depend on layout- and corner-specific delays that RTL
  simulation (with generic or hand-picked delays) does not capture
  precisely — this program demonstrates the *mechanism*, not a
  timing-signoff result.

## 14. Common Mistakes

* Trusting a Boolean simplification that drops the consensus term (it is
  redundant for the *steady-state* truth table) without checking whether
  the signal feeds asynchronous or unclocked logic where the transient
  matters.
* Assuming a hazard appears on every transition of the changing variable —
  as shown here, it can be direction-dependent, appearing only when
  falling (or only when rising), based on the relative gate delays of the
  two paths.
* Sampling a delay-based testbench at exactly the delay values used in the
  DUT, which risks a same-time-step ordering race instead of a clean
  before/after read (addressed here with the `#0.5` sampling offset).

## 15. Possible Improvements

* Sweep the individual gate delays as parameters and find the exact
  crossover point where the hazard window closes.
* Extend to a static-0 hazard example (a product-of-sums circuit with the
  dual consensus term) for symmetry with this sum-of-products case.

## 16. What This Program Teaches

* That gate delays are a real, simulatable phenomenon with observable
  consequences, not just an abstraction.
* The static-1 hazard and the consensus-term fix, demonstrated rather than
  only stated.
* A glitch-counting testbench technique for detecting transient
  misbehaviour that a purely functional (zero-delay) testbench would never
  see.

## 17. Industry Relevance

Hazard analysis matters wherever combinational logic feeds something
without a synchronizing clock edge to mask glitches: asynchronous reset
trees, clock-gating enables, and legacy asynchronous FSM design all rely
on hazard-free logic; static timing analysis and gate-level simulation
with SDF-annotated delays are the modern, at-scale version of what this
program shows by hand.

## 18. How to Run

```bash
python3 scripts/run.py 031
cd 01-basic-gates/031-gate-delays-and-glitches && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/hazard_circuit.v src/hazard_free_circuit.v tb/tb_hazard.v
vvp build/sim.vvp +vcd
```
