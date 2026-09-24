# 002 — Wires and Continuous Assignment

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `wire_assign_demo` | `src/wire_assign_demo.v` | `tb/tb_wire_assign_demo.v` |

## 1. Objective

Use nets (`wire`), vectors, intermediate signals and continuous assignments
to build combinational logic, and protect the design against misspelled
signal names with `` `default_nettype none ``.

## 2. What the Design Does

For a 3-bit input `in_bits` the module produces four results at once:

| `in_bits` | `majority` | `parity` | `reversed` | `zero_ext` |
|---|---|---|---|---|
| 000 | 0 | 0 | 000 | 0000 |
| 011 | 1 | 0 | 110 | 0011 |
| 100 | 0 | 1 | 001 | 0100 |
| 111 | 1 | 1 | 111 | 0111 |

* `majority` — 1 when at least two of the three bits are 1.
* `parity` — 1 when an odd number of bits are 1.
* `reversed` — the same bits in the opposite order.
* `zero_ext` — the input widened to 4 bits with a leading 0.

## 3. Why It Is Useful

Most RTL is a network of wires and small expressions. Majority voting is used
in fault-tolerant logic (see 059), parity in error detection (see 048), bit
reversal when converting between MSB-first and LSB-first interfaces, and zero
extension whenever narrow values feed wider datapaths.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `in_bits` | input | 3 | Input vector, bit 2 is the most significant |
| `majority` | output | 1 | At least two input bits are 1 |
| `parity` | output | 1 | Odd number of 1s |
| `reversed` | output | 3 | `{in_bits[0], in_bits[1], in_bits[2]}` |
| `zero_ext` | output | 4 | `{1'b0, in_bits}` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `pair_01` | 1 | `in_bits[0] & in_bits[1]` |
| `pair_12` | 1 | `in_bits[1] & in_bits[2]` |
| `pair_02` | 1 | `in_bits[0] & in_bits[2]` |
| `odd_ones` | 1 | XOR of the three bits (declared with a net declaration assignment) |

## 6. Architecture

```
in_bits[0] --+----------------+
in_bits[1] --|--+   AND pairs |      +----+
in_bits[2] --|--|--+  pair_01-+----->|    |
             |  |  |  pair_12-+----->| OR |---> majority
             |  |  |  pair_02-+----->|    |
             |  |  |                 +----+
             +--+--+--> XOR3 (odd_ones) -----> parity
             re-wiring only ---------------------> reversed, zero_ext
```

`reversed` and `zero_ext` contain no gates at all: they are just a different
arrangement of wires (and a constant 0).

## 7. Module Hierarchy and Connections

```
tb_wire_assign_demo
└── dut : wire_assign_demo
```

## 8. Verilog Concepts Used

* **Vectors** — `wire [2:0] in_bits` is a 3-bit bus; `in_bits[1]` selects one bit.
* **Explicit net declarations** for intermediate signals (`wire pair_01;`).
* **Continuous assignment** (`assign`) — each statement describes permanent
  hardware; statement order is irrelevant.
* **Net declaration assignment** — `wire odd_ones = …;` declares and drives a
  net in one statement (equivalent to a declaration plus an `assign`).
* **Concatenation** `{ }` — builds a vector from pieces.
* **`` `default_nettype none ``** — turns off implicit net creation.

## 9. Source Code Explanation

```verilog
`default_nettype none
```
By default Verilog silently creates a 1-bit `wire` for any undeclared name
used in a port connection or on the left of an `assign`. A typo such as
`assign majoirty = …` would then compile and leave the real output undriven.
With `none`, an undeclared name is a compile error. The directive stays
active for every file compiled afterwards, so the file ends with
`` `default_nettype wire `` to restore the default for other code (for
example, testbenches that rely on it).

```verilog
wire pair_01;
wire pair_12;
wire pair_02;
assign pair_01 = in_bits[0] & in_bits[1];
assign pair_12 = in_bits[1] & in_bits[2];
assign pair_02 = in_bits[0] & in_bits[2];
assign majority = pair_01 | pair_12 | pair_02;
```
Majority of three = "some pair is all ones". Naming the pair terms makes the
structure visible in waveforms and keeps each expression short. Synthesis is
free to restructure them; the names do not force a particular netlist.

```verilog
wire odd_ones = in_bits[0] ^ in_bits[1] ^ in_bits[2];
assign parity = odd_ones;
```
XOR of an odd number of 1s is 1, so this is odd parity. The first line is a
net declaration assignment. (The reduction operator `^in_bits` would do the
same in one token — see 006.)

```verilog
assign reversed = {in_bits[0], in_bits[1], in_bits[2]};
assign zero_ext = {1'b0, in_bits};
```
In a concatenation the **leftmost** element becomes the most significant bits.
So `reversed[2] = in_bits[0]` and `zero_ext = 0,b2,b1,b0`. Writing `1'b0`
(sized) instead of `0` matters: an unsized `0` inside `{}` is illegal.

## 10. Testbench Explanation

The bench loops over all eight input values. For each it computes the
expected outputs **arithmetically** — `ones = i[0] + i[1] + i[2]`, majority is
`ones >= 2`, parity is `ones % 2 == 1` — so the checker does not reuse the
RTL's gate equations and can catch an error in them. All four outputs are
compared with `!==` and one truth-table row is printed per input.

## 11. Test Cases and Expected Results

| # | Stimulus | Expected |
|---|---|---|
| 1–8 | every `in_bits` value 000…111 | majority = (ones ≥ 2), parity = odd(ones), reversed bit order, zero_ext = {0,in} |

Exhaustive: the complete input space is covered.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 002` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_wire_assign_demo` — **PASS**

```text
in_bits | majority parity reversed zero_ext
  000   |    0        0      000      0000
  001   |    0        1      100      0001
  010   |    0        1      010      0010
  011   |    1        0      110      0011
  100   |    0        1      001      0100
  101   |    1        0      101      0101
  110   |    1        0      011      0110
  111   |    1        1      111      0111
TEST PASSED: 8 checks
tb/tb_wire_assign_demo.v:59: $finish called at 80000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 7 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Intermediate wires are free in hardware; use them for readability.
* A `wire` can have only one continuous driver in synthesizable logic;
  two `assign`s to the same net create contention (`x` in simulation, an
  error in synthesis).
* The bit-reversal and zero-extension cost no logic cells, which is why Yosys
  reports only the gates for majority and parity.

## 14. Common Mistakes

* **Typos creating implicit nets** — without `` `default_nettype none `` a
  misspelled name compiles to a new floating wire.
* **Forgetting to restore `` `default_nettype wire ``** — later files that
  depend on implicit nets (common in legacy code) stop compiling.
* **Reversing the concatenation order** — `{a, b}` puts `a` in the upper bits.
* **Unsized constants in concatenations** — `{0, in_bits}` is an error; write
  `{1'b0, in_bits}`.
* **Driving one wire from two `assign` statements.**

## 15. Possible Improvements

* Replace the three-input XOR with the reduction operator `^in_bits`.
* Generalise to N bits with a parameter (see 029 and 055).

## 16. What This Program Teaches

* Declaring and using nets and vectors.
* Writing combinational logic with `assign`.
* Bit selects and concatenation.
* Using `` `default_nettype none `` as a safety net.

## 17. Industry Relevance

Many coding standards (lowRISC, OpenTitan and most company guidelines)
require `` `default_nettype none `` in RTL files precisely because implicit
nets have caused real silicon bugs. Continuous assignments with named
intermediate wires are the dominant style for datapath glue logic.

## 18. How to Run

```bash
python3 scripts/run.py 002
cd 00-foundations/002-wires-and-continuous-assignment && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/wire_assign_demo.v tb/tb_wire_assign_demo.v
vvp build/sim.vvp +vcd
```
