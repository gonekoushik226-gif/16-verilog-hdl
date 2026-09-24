# 051 — Binary-to-BCD Converter (Double Dabble)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Intermediate | `bin2bcd` | `src/bin2bcd.v` | `tb/tb_bin2bcd.v` |

## 1. Objective

Implement the classic shift-and-add-3 ("double dabble") binary-to-BCD
conversion algorithm as combinational logic, understanding why the add-3
correction is necessary and how a sequential algorithm can be unrolled into
a fixed-depth combinational circuit.

## 2. What the Design Does

`bin2bcd` converts an 8-bit binary value (`0`–`255`) into three separate
4-bit BCD digit outputs: `hundreds`, `tens`, `units`. Internally it
maintains a 20-bit shift register holding the three BCD nibbles above the
still-unconsumed binary bits, and for 8 iterations: corrects any BCD nibble
that has reached 5 or more by adding 3, then shifts the entire register
left by one bit. After 8 iterations the upper 12 bits hold the correct BCD
representation.

## 3. Why It Is Useful

BCD digits map directly onto decimal display and printing without a
division/modulo step, so binary-to-BCD conversion sits between an internal
binary datapath and any decimal-facing output (seven-segment displays,
LCDs, decimal serial protocols). Double dabble is the standard
division-free way to do this conversion in hardware.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `bin` | input | 8 | binary value to convert, `0`–`255` |
| `hundreds` | output | 4 | hundreds BCD digit, `0`–`2` |
| `tens` | output | 4 | tens BCD digit, `0`–`9` |
| `units` | output | 4 | units BCD digit, `0`–`9` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `shift_reg` | 20 | `{hundreds, tens, units, remaining_bin}` working register for the shift-and-add-3 algorithm |
| `i` | (loop var) | unrolled iteration count, 0 to 7 |

## 6. Architecture

```
shift_reg = { 4'h_ , 4'h_ , 4'h_ , bin[7:0] }
              hundreds tens  units  (12 bits)  (8 bits)

repeat 8 times:
  if hundreds >= 5: hundreds += 3
  if tens     >= 5: tens     += 3
  if units    >= 5: units    += 3
  shift_reg <<= 1
```

Each iteration's add-3 correction happens *before* that iteration's shift,
so a nibble that would otherwise overflow past 9 when doubled (e.g. 6 → 12,
which does not fit in one BCD digit) is pre-corrected to 9, and the shift
then correctly carries into the next digit instead of producing an invalid
BCD code.

## 7. Module Hierarchy and Connections

```
tb_bin2bcd
└── dut : bin2bcd
```

## 8. Verilog Concepts Used

* A `for` loop with a fixed, elaboration-time-known bound (`WIDTH = 8`)
  inside a combinational `always @(*)` block, unrolled into 8 stages of
  add-3-then-shift hardware rather than executed sequentially at run time.
* Part-select assignment into specific nibble ranges of a wider `reg`
  (`shift_reg[11:8]`, etc.).
* A single wide shift register modeling three separate decimal digits and
  the not-yet-consumed binary remainder simultaneously.

## 9. Source Code Explanation

```verilog
always @(*) begin
    shift_reg = {12'b0, bin};
    for (i = 0; i < WIDTH; i = i + 1) begin
        if (shift_reg[11:8]  >= 5) shift_reg[11:8]  = shift_reg[11:8]  + 4'd3;
        if (shift_reg[15:12] >= 5) shift_reg[15:12] = shift_reg[15:12] + 4'd3;
        if (shift_reg[19:16] >= 5) shift_reg[19:16] = shift_reg[19:16] + 4'd3;
        shift_reg = shift_reg << 1;
    end
end
```
* `shift_reg` starts as the 8-bit input right-justified in a 20-bit
  register, with all three BCD nibbles cleared to 0.
* Each of the 8 loop iterations first corrects every BCD nibble that has
  reached 5 or higher (adding 3 turns a would-be-invalid doubled value like
  `2×6=12` into `2×9=18`, i.e. a correct carry of 1 into the next digit
  plus remainder 8, matching how `15 = "15"` should split into tens=1,
  units=5), then shifts the whole 20-bit register left by one, moving the
  next (previously unconsumed) binary bit up into the units nibble's LSB
  and moving each nibble's own MSB up towards the next more significant
  digit.
* After all 8 shifts, every binary bit has been consumed and `shift_reg`'s
  upper 12 bits hold the final BCD digits, read out through the three
  continuous assignments.

## 10. Testbench Explanation

`tb_bin2bcd` sweeps all 256 possible 8-bit inputs and checks each against
an independent reference model computed with plain integer division and
modulo (`bin/100`, `(bin/10)%10`, `bin%10`) — a completely different
computational method from the RTL's shift-and-add-3 algorithm, so the two
cannot share a common mistake.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive 8-bit sweep | all 256 values `0`–`255` | `{hundreds,tens,units}` matches `bin/100`, `(bin/10)%10`, `bin%10` |

Notable individual cases covered by the sweep: `0` → `0,0,0`; `9` → `0,0,9`
(no add-3 correction ever triggers); `99` → `0,9,9`; `100` → `1,0,0`;
`255` → `2,5,5` (maximum input, every digit near its own maximum).

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 051` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_bin2bcd` — **PASS**

```text
exhaustive 8-bit sweep (256 values)...
done: 256 checks
TEST PASSED: 256 checks
tb/tb_bin2bcd.v:47: $finish called at 256000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 119 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The 20-bit register width (`8` input bits + `12` BCD bits) is exactly
  sized for this input range; a wider binary input needs a proportionally
  wider register and one more shift per extra bit, and possibly one more
  BCD digit if the input can exceed 999.
* Fully combinational: the `for` loop is unrolled by both Icarus Verilog
  and Yosys into 8 physical stages of add-3-then-shift hardware, not a
  runtime loop — gate depth grows with `WIDTH`, which matters for timing
  on a wide input.
* No reset or clock; the module recomputes the full conversion every time
  `bin` changes.

## 14. Common Mistakes

* Forgetting the add-3 correction entirely — without it, doubling a nibble
  already at or above 5 produces an invalid BCD code (e.g. `6 << 1 = 12`,
  which does not fit in one BCD digit and corrupts the decimal reading).
* Applying add-3 *after* the shift instead of before — the correction must
  happen while the nibble is still uncommitted to the shift, so its
  carry-out lands in the correct place once shifted.
* Sizing the shift register too narrow for the maximum possible converted
  value — a register that only fits 2 BCD digits would silently truncate
  the hundreds digit for any input at or above 100.

## 15. Possible Improvements

* Parameterize `WIDTH` and the number of BCD digits so wider binary inputs
  (e.g. 16-bit, up to 5 digits) reuse the same module.
* Add a clocked, multi-cycle version that performs one shift per clock
  (the historically original double-dabble hardware), trading latency for
  a much smaller combinational depth per cycle.

## 16. What This Program Teaches

* The shift-and-add-3 algorithm and why the add-3 correction is
  mathematically necessary, not an arbitrary fudge factor.
* Unrolling a sequential, iteration-based algorithm into fixed-depth
  combinational hardware with a `for` loop.
* Validating a non-trivial algorithm against a reference model computed a
  completely different way (division/modulo vs. shift-and-correct).

## 17. Industry Relevance

Binary-to-BCD conversion is a standard building block wherever an internal
binary datapath must drive a decimal-facing display, printer, or protocol;
double dabble remains the standard hardware algorithm because it avoids
the cost of a full binary divider.

## 18. How to Run

```bash
python3 scripts/run.py 051            # compile, simulate, synthesize, lint
cd 03-combinational-logic/051-binary-to-bcd-double-dabble && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bin2bcd.v tb/tb_bin2bcd.v
vvp build/sim.vvp +vcd
```
