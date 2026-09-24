# 110 — Ring Counter (Self-Correcting)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Elementary | `ring_counter` | `src/ring_counter.v` | `tb/tb_ring_counter.v` |

## 1. Objective

Build a one-hot rotating counter whose feedback logic actively recovers
to a valid state after any invalid power-up condition, rather than
relying on reset alone.

## 2. What the Design Does

`ring_counter` holds exactly one `1` bit that rotates one position every
enabled cycle. The feedback entering the LSB is not a plain wraparound
of the discarded MSB; it is the NOR of every *other* bit — a formula
that both continues a valid one-hot rotation correctly and, from any
invalid (not-exactly-one-bit) state, converges back to one-hot within a
few cycles.

## 3. Why It Is Useful

Ring counters are used as simple one-hot sequencers (each bit directly
enables one step of a sequence, e.g. an LED chaser or a simple timing
generator). Without self-correction, a ring counter that powers up in an
invalid state (all-zero, or multiple bits set) stays invalid forever —
plain rotation preserves whatever bit pattern it started with.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `en` | input | 1 | rotate enable |
| `q` | output | `WIDTH` | one-hot state |

Parameters: `WIDTH` (default 4).

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `feedback` | NOR of `q[WIDTH-2:0]` (every bit except the one about to be discarded) |

## 6. Architecture

```
feedback = ~(q[WIDTH-2] | q[WIDTH-3] | ... | q[0])
q <= {q[WIDTH-2:0], feedback}     (shift left, feedback enters LSB)
```
Worked trace (WIDTH=4, `q[3]q[2]q[1]q[0]`), starting from valid one-hot
`1000`: `feedback=~(0|0|0)=1` -> next `0001`. From `0001`:
`feedback=~(0|0|1)=0` -> next `0010`. Continuing: `0010->0100->1000`,
a clean 4-cycle one-hot rotation. From an invalid all-zero state `0000`:
`feedback=~(0|0|0)=1` -> next `0001`, immediately valid. From an invalid
multi-bit state `1010`: `feedback=~(0|1|0)=0` -> next `0100`, already
valid again in one cycle.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A self-correcting feedback equation derived and verified by hand
  (worked trace above) before being coded, rather than a plain
  wraparound shift — the same "derive, then verify" discipline used for
  program 077's Baugh-Wooley multiplier.
* Hierarchical `force`/`release` in the testbench to inject specific
  invalid states directly, the same technique as program 097.

## 9. Source Code Explanation

```verilog
wire feedback = ~(|q[WIDTH-2:0]);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  q <= {{(WIDTH-1){1'b0}}, 1'b1};
    else if (en) q <= {q[WIDTH-2:0], feedback};
end
```
`|q[WIDTH-2:0]` is an OR-reduction of every bit except the MSB (the bit
that is about to be shifted out and discarded); its complement is 1
exactly when all of those bits are already 0 — which is true both in a
valid one-hot state whose single 1 is at the MSB, and in the invalid
all-zero state.

## 10. Testbench Explanation

`tb_ring_counter` checks two full periods of normal rotation stay
one-hot, then uses hierarchical `force` to directly inject three invalid
states — all-zero, two bits set, and all-ones — checking recovery to a
valid one-hot state within `WIDTH` cycles after each, and that normal
rotation resumes correctly afterward.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | normal rotation | 2 full periods | always exactly one bit set |
| 2 | recovery from all-zero | forced `q=0000` | one-hot within WIDTH cycles |
| 3 | recovery from multi-bit | forced `q=1010` | one-hot within WIDTH cycles |
| 4 | recovery from all-ones | forced `q=1111` | one-hot within WIDTH cycles |
| 5 | resumes correctly | continued rotation after recovery | stays one-hot |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 110` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_ring_counter` — **PASS**

```text
TEST PASSED: 17 checks
tb/tb_ring_counter.v:83: $finish called at 246000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 6 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This self-correction handles the common textbook cases (all-zero and
  small multi-bit-set states) within a small, bounded number of cycles,
  verified directly rather than merely asserted; it is not a formally
  proven correction for every possible invalid state at every width, but
  the same NOR-feedback principle generalizes.
* Purely combinational feedback logic feeding a synchronous register —
  no combinational feedback *loop* the way program 085's SR latch has,
  since the feedback only reads `q`'s current registered value.

## 14. Common Mistakes

* Using a plain wraparound shift (`q <= {q[WIDTH-2:0], q[WIDTH-1]}`)
  instead of the NOR-based feedback — rotates correctly from a valid
  one-hot state but never recovers from an invalid one.
* Including the MSB itself in the NOR feedback expression — would make
  the feedback depend on the very bit being discarded, breaking the
  self-correction property.

## 15. Possible Improvements

* Extend the self-correction argument to a rigorous proof (or exhaustive
  simulation) covering every possible invalid state, not just the three
  representative cases tested here.

## 16. What This Program Teaches

* Deriving and verifying self-correcting feedback logic by hand before
  implementing it.
* The distinction between a design that is merely reset-correct and one
  that is robust to any power-up state.

## 17. Industry Relevance

Self-correcting (or "self-starting") counters matter in real hardware
because power-up state is not always guaranteed to match a design's
reset value — radiation-induced upsets, incomplete reset propagation, or
simulation/emulation mismatches can all leave a register in an
unexpected state, and self-correcting logic recovers from that without
needing an explicit reset pulse.

## 18. How to Run

```bash
python3 scripts/run.py 110            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/110-ring-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/ring_counter.v tb/tb_ring_counter.v
vvp build/sim.vvp +vcd
```
