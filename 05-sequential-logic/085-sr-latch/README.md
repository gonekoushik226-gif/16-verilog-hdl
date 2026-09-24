# 085 — SR Latch

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · Synthesis: not applicable · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `sr_latch` | `src/sr_latch.v` | `tb/tb_sr_latch.v` |

## 1. Objective

Build the most basic memory element — a cross-coupled NOR latch — and
see how genuine combinational feedback, not a clock, is what gives it
the ability to remember a value.

## 2. What the Design Does

`sr_latch` cross-couples two NOR gates: `q = NOR(r, qn)`, `qn = NOR(s,
q)`. Setting `s=1,r=0` forces `q=1`; `s=0,r=1` forces `q=0`; `s=0,r=0`
holds whatever value the feedback loop last settled on; `s=1,r=1` is the
forbidden state, forcing both outputs to 0 (breaking their normal
complementary relationship) for as long as it is held.

## 3. Why It Is Useful

Every other storage element in this category — latches, flip-flops,
registers — is ultimately built from this same idea: a loop of
combinational logic whose output feeds back into its own input, so the
circuit has more than one stable state and "remembers" which one it is
in.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `s` | input | 1 | set |
| `r` | input | 1 | reset |
| `q` | output | 1 | latch state |
| `qn` | output | 1 | complementary state (except in the forbidden state) |

## 5. Internal Signals

None beyond `q`/`qn` themselves — they are both output ports and
internal feedback signals simultaneously.

## 6. Architecture

```
      +-------[NOR g1]-------+
      |    r -->|            |
      +----q<---+            |
      |                      |
      +----qn<--+            |
      |    s -->|            |
      +-------[NOR g2]-------+
```
`g1`'s inputs are `r` and `qn`; `g2`'s inputs are `s` and `q` — each
gate's output is the other gate's second input, the defining feedback
loop of a latch.

## 7. Module Hierarchy and Connections

```
sr_latch
├── g1 : nor(q, r, qn)
└── g2 : nor(qn, s, q)
```
Two primitive gate instances, no submodules.

## 8. Verilog Concepts Used

* Gate-level primitive instantiation (`nor`) with genuine feedback
  between two instances — Icarus Verilog's event-driven simulator
  resolves this the same way real gates settle: repeatedly re-evaluating
  each gate until neither output changes.
* A circuit whose correct behavior depends on *memory* (the current
  state of the feedback loop), not just its current inputs — the first
  program in this repository where that is true.

## 9. Source Code Explanation

```verilog
nor g1 (q,  r, qn);
nor g2 (qn, s, q);
```
`g1` computes `q = ~(r | qn)`; `g2` computes `qn = ~(s | q)`. Because
each expression depends on the other gate's current output, there is no
non-circular way to write this as two independent `assign` statements —
the feedback *is* the mechanism, not an artifact to be removed.

## 10. Testbench Explanation

`tb_sr_latch` drives the classic sequence — reset, hold, set, hold,
reset, forbidden, exit via reset, set, hold — checking `q`/`qn` after
each stimulus has had time to settle. The forbidden state is entered and
then exited through an explicit reset (rather than releasing `s` and `r`
to `0,0` simultaneously), since that release is a genuine race condition
in real hardware whose outcome depends on gate delay mismatches this
zero-delay simulation does not model.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | reset | s=0,r=1 | q=0, qn=1 |
| 2 | hold | s=0,r=0 (after reset) | q=0, qn=1 (unchanged) |
| 3 | set | s=1,r=0 | q=1, qn=0 |
| 4 | hold | s=0,r=0 (after set) | q=1, qn=0 (unchanged) |
| 5 | forbidden | s=1,r=1 | q=0, qn=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 085` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_sr_latch` — **PASS**

```text
TEST PASSED: 9 checks
tb/tb_sr_latch.v:49: $finish called at 18000 (1ps)
```

Synthesis: not applicable — intentional combinational feedback loop (cross-coupled NOR gates) -- Yosys 'check -assert' flags this as a "logic loop" problem, which is exactly the SR latch's gate-level topology, not a design defect. See README.md section 13.
Lint (Verilator 5.020 `--lint-only`): warnings — UNOPTFLAT
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* **Synthesis is intentionally skipped for this program** (see
  `program.conf`, `SYNTH=no`): Yosys's `check -assert` pass reports the
  cross-coupled `nor` gates as a "logic loop" problem. That loop is not
  a bug — it is the literal, necessary topology of a gate-level SR latch
  — but generic Yosys synthesis has no way to distinguish an intentional
  memory-element feedback loop from an accidental combinational cycle,
  so it flags both identically. Simulation (Icarus Verilog) correctly
  models and verifies the intended behavior regardless.
* Verilator lint reports `UNOPTFLAT` for the same reason (a genuine
  cyclic dependency between `q` and `qn`) — expected and unavoidable for
  this circuit, not a bug to fix.

## 14. Common Mistakes

* Driving `s=1,r=1` and then releasing both to 0 simultaneously,
  expecting a well-defined outcome — real gate delay mismatches make
  this genuinely non-deterministic in hardware.
* Trying to describe this latch with two independent `assign`
  statements — the mutual dependency cannot be flattened into
  non-circular combinational logic; it needs either gate primitives (as
  here) or a behavioral latch description with an explicit hold case (as
  in program 086).

## 15. Possible Improvements

* Build the equivalent NAND-based (active-low set/reset) SR latch as a
  variant.

## 16. What This Program Teaches

* How feedback, not a clock, creates memory.
* Why the S=R=1 combination is forbidden, and what that means physically.

## 17. Industry Relevance

Cross-coupled gates are the literal transistor-level structure inside
every SRAM cell and every flip-flop's internal latches (see program
093's master-slave construction) — understanding this circuit is
foundational to understanding all digital memory.

## 18. How to Run

```bash
python3 scripts/run.py 085            # compile, simulate (synthesis skipped by design)
cd 05-sequential-logic/085-sr-latch && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/sr_latch.v tb/tb_sr_latch.v
vvp build/sim.vvp +vcd
```
