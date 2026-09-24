# 049 — Binary ↔ Gray Code Converters

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | (none — two independent modules) | `src/bin2gray.v`, `src/gray2bin.v` | `tb/tb_gray_converters.v` |

## 1. Objective

Implement both directions of the binary/Gray-code conversion and prove, by
simulation, Gray code's defining property: consecutive values differ in
exactly one bit.

## 2. What the Design Does

`bin2gray` converts a `WIDTH`-bit binary value to reflected Gray code with
one XOR per bit against the next more-significant binary bit. `gray2bin`
inverts that transform with a ripple of XORs from the MSB down, since each
binary bit depends on every Gray bit from the top down to its own position.

## 3. Why It Is Useful

Gray code guarantees that incrementing or decrementing a counter changes
only one output bit at a time. That single-bit-change property removes the
possibility of a multi-bit "glitch" value being sampled mid-transition —
essential for counters crossing clock domains, rotary/absolute position
encoders, and Karnaugh-map-style adjacency arguments used throughout digital
design.

## 4. Interface

**`bin2gray`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `bin` | input | `WIDTH` | binary value |
| `gray` | output | `WIDTH` | reflected Gray code of `bin` |

**`gray2bin`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `gray` | input | `WIDTH` | Gray-coded value |
| `bin` | output | `WIDTH` | binary value that `bin2gray` would produce this `gray` from |

Parameters (both modules):

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | bus width |

## 5. Internal Signals

None in `bin2gray`. `gray2bin` uses a loop variable `i` (for-loop index)
inside its combinational `always` block; it carries no state between
evaluations.

## 6. Architecture

```
bin2gray:  gray = bin ^ (bin >> 1)                       [one XOR layer]

gray2bin:  bin[W-1] = gray[W-1]
           bin[i]   = bin[i+1] ^ gray[i]   for i = W-2 downto 0
                                                           [ripple XOR chain]
```

`gray2bin`'s chain is the direct algebraic inverse of `bin2gray`'s single
XOR layer: unrolling `bin[i] = bin[i+1] ^ gray[i]` shows
`bin[i] = gray[W-1] ^ gray[W-2] ^ ... ^ gray[i]`, a running (prefix) XOR
from the top bit down.

## 7. Module Hierarchy and Connections

```
tb_gray_converters
├── dut_b2g : bin2gray #(.WIDTH(8))
└── dut_g2b : gray2bin #(.WIDTH(8))
```

The testbench feeds `dut_b2g`'s output directly into `dut_g2b`'s input to
exercise the round trip; the two modules have no direct hardware connection
to each other beyond that.

## 8. Verilog Concepts Used

* Self-shift XOR (`bin ^ (bin >> 1)`) as a one-line combinational
  transform.
* A `for` loop inside a combinational `always @(*)` block, unrolled by the
  simulator/synthesizer into a fixed ripple of XOR gates (an `integer` loop
  index, not a hardware counter).
* A testbench reference model (`gray2bin_model`) implemented with a
  genuinely different algorithm (iterative shift-doubling) than the RTL's
  ripple chain, so a bug shared between the RTL and a copy-pasted model
  cannot hide.
* A real bug caught during development: the testbench originally reused the
  same module-level `integer i` inside a task already using `i` as its
  caller's loop variable, corrupting the outer loop and hanging the
  simulation — fixed by giving the task's own loop a separate local index.

## 9. Source Code Explanation

`bin2gray`:
```verilog
assign gray = bin ^ (bin >> 1);
```
* `bin >> 1` shifts every bit one position towards the LSB (with a 0
  shifted into the top); XORing it against `bin` itself makes
  `gray[i] = bin[i] ^ bin[i+1]` for every bit except the MSB, which keeps
  `bin[WIDTH-1]` unchanged (XORed with the shifted-in 0).

`gray2bin`:
```verilog
always @(*) begin
    bin[WIDTH-1] = gray[WIDTH-1];
    for (i = WIDTH - 2; i >= 0; i = i - 1)
        bin[i] = bin[i+1] ^ gray[i];
end
```
* The MSB of `bin` equals the MSB of `gray` directly (both bin2gray's
  formula and this loop agree there is no more-significant bit to XOR
  against).
* Each subsequent bit XORs the *already-computed* next-higher `bin` bit
  with its own `gray` bit — because `bin` is assigned to progressively as
  the loop runs, this correctly implements the running-XOR inverse without
  needing a separate accumulator variable.

## 10. Testbench Explanation

`tb_gray_converters` covers:

1. **Exhaustive round trip**: for all 256 values of an 8-bit `bin`,
   `check_roundtrip` converts to Gray with `dut_b2g`, checks the result
   against the `bin ^ (bin >> 1)` formula computed independently in the
   task, feeds it into `dut_g2b`, and checks the recovered binary value
   both equals the original `bin` and matches `gray2bin_model` — an
   independent shift-doubling implementation of the inverse, so the RTL and
   the check cannot share the same latent bug.
2. **One-bit-change property**: for every consecutive pair `(n, n+1)` in
   `0..255`, `check_one_bit_change` XORs their Gray codes and counts the
   set bits in the result, asserting the count is always exactly 1 — the
   property that makes Gray code useful for counters and encoders.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive round trip | all 256 binary values | `gray2bin(bin2gray(bin)) == bin`, matches independent model |
| 2 | One-bit-change property | all 255 consecutive pairs `(n, n+1)` | `gray(n) XOR gray(n+1)` has exactly one set bit |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 049` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_gray_converters` — **PASS**

```text
exhaustive bin->gray->bin round trip (256 values)...
  done: 512 checks, errors so far: 0
one-bit-change property across all consecutive pairs (255 pairs)...
  done: 767 checks total, errors so far: 0
TEST PASSED: 767 checks
tb/tb_gray_converters.v:99: $finish called at 1022000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 16 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Both converters are pure combinational logic — no reset or clock.
* `bin2gray` is O(1) gate depth (one XOR layer); `gray2bin`'s ripple chain
  has O(WIDTH) gate depth in this direct implementation, which is the
  standard trade-off for this construction (a shift-doubling version, as
  used only in the testbench reference model here, trades depth for width
  by XORing progressively larger shifted copies together).
* `WIDTH` is a `parameter`, so both modules synthesize a fixed-width XOR
  network with no runtime width selection cost.

## 14. Common Mistakes

* Implementing `gray2bin` as a bit-by-bit copy of `bin2gray`'s formula
  (`bin[i] = gray[i] ^ gray[i+1]`) — this does not invert the transform;
  the correct inverse needs the *running* XOR shown in §9, not a local one.
* Reusing a shared loop-index variable across nested tasks/loops in a
  testbench — the exact bug found and fixed while writing this program's
  bench (§8), which silently corrupted the outer loop and hung the
  simulation rather than producing a wrong-but-terminating result.
* Assuming Gray code preserves ordinary binary arithmetic — Gray-coded
  values cannot be added or compared with `+`/`>` directly; they must be
  converted back to binary first.

## 15. Possible Improvements

* Implement a shift-doubling `gray2bin` as the synthesizable RTL itself
  (trading gate depth for width) and compare synthesis area/depth against
  the ripple version.
* Parameterize a Gray-code counter (increment directly in Gray domain
  without converting through binary) as a follow-on program.

## 16. What This Program Teaches

* Deriving an inverse transform algebraically from a forward one, rather
  than guessing.
* Why writing an independent reference model (a different algorithm, not a
  copy of the RTL) in a testbench catches bugs a copied implementation
  would miss.
* A concrete example of a testbench-only bug (variable-scope collision)
  that produces a hang rather than a wrong answer, and how to diagnose one.

## 17. Industry Relevance

Gray code counters cross clock domains safely (each bit transitions
predictably, one at a time, so a coincidentally-sampled mid-transition
value is always adjacent to a valid one) and are standard in asynchronous
FIFO pointer design — used directly in this curriculum's asynchronous FIFO
program later on — as well as in rotary encoders and Karnaugh-map adjacency
in digital logic minimization.

## 18. How to Run

```bash
python3 scripts/run.py 049            # compile, simulate, synthesize, lint
cd 03-combinational-logic/049-binary-gray-converters && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bin2gray.v src/gray2bin.v tb/tb_gray_converters.v
vvp build/sim.vvp +vcd
```
