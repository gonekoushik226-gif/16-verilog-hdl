# 052 — BCD-to-Excess-3 Converter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Beginner | `bcd_to_excess3` | `src/bcd_to_excess3.v` | `tb/tb_bcd_to_excess3.v` |

## 1. Objective

Implement the Excess-3 code conversion (BCD digit + 3) and practice
handling an input code space that is larger than the set of valid codes —
4 bits can represent 16 values, but only 10 (`0`–`9`) are valid BCD digits.

## 2. What the Design Does

`bcd_to_excess3` adds 3 to a 4-bit BCD digit to produce its Excess-3 code.
For the 6 codes (`10`–`15`) that are not valid BCD digits, it raises
`invalid` and drives `excess3` to 0 instead of producing a meaningless
result.

## 3. Why It Is Useful

Excess-3 is self-complementing (the 9's complement of a digit is obtained
by simply inverting every bit of its Excess-3 code), which made decimal
addition/subtraction and error checking simpler in early decimal computer
arithmetic units. The invalid-code handling here is a small, concrete
instance of the general principle that a converter must define behaviour
for out-of-domain inputs, not just the valid ones.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `bcd` | input | 4 | BCD digit to convert, valid range `0`–`9` |
| `excess3` | output | 4 | `bcd + 3`, valid only when `invalid = 0` |
| `invalid` | output | 1 | 1 when `bcd` is `10`–`15` (not a valid BCD digit) |

## 5. Internal Signals

None — the outputs are a direct function of the input.

## 6. Architecture

```
bcd[3:0] ──[bcd <= 9?]──yes──► excess3 = bcd + 3, invalid = 0
                    │
                    no──► excess3 = 0, invalid = 1
```

## 7. Module Hierarchy and Connections

```
tb_bcd_to_excess3
└── dut : bcd_to_excess3
```

## 8. Verilog Concepts Used

* A range check (`bcd <= 4'd9`) distinguishing a valid subset of a wider
  bit-vector's value space from the rest.
* An explicit `invalid` flag rather than letting an out-of-range input
  produce an unspecified or misleading numeric output.
* Default assignment for every output at the top of the combinational
  block, so both the valid and invalid branches leave no output
  unassigned.

## 9. Source Code Explanation

```verilog
always @(*) begin
    invalid = 1'b0;
    excess3 = 4'd0;
    if (bcd <= 4'd9) begin
        excess3 = bcd + 4'd3;
    end else begin
        invalid = 1'b1;
    end
end
```
* Both outputs default to their "invalid/idle" values (`excess3 = 0`,
  `invalid = 0`) before the range check runs, so the `if` branch only needs
  to set `excess3`, and the `else` branch only needs to set `invalid` —
  every path still ends with both outputs fully defined and no latch
  inferred.
* `bcd <= 4'd9` is the entire validity test: any 4-bit value from `10`
  (`4'b1010`) to `15` (`4'b1111`) falls into the `else` branch.

## 10. Testbench Explanation

`tb_bcd_to_excess3` sweeps all 16 possible 4-bit inputs — a genuinely
exhaustive test of the whole input space, not just the 10 valid digits —
checking both `excess3` and `invalid` against a reference model computed
the same way the specification is stated (`bcd + 3` when `bcd <= 9`,
otherwise `invalid`).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Valid BCD digits | `bcd = 0`–`9` | `excess3 = bcd+3`, `invalid = 0` |
| 2 | Invalid codes | `bcd = 10`–`15` | `excess3 = 0`, `invalid = 1` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 052` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_bcd_to_excess3` — **PASS**

```text
all 16 possible 4-bit inputs (10 valid BCD + 6 invalid):
TEST PASSED: 16 checks
tb/tb_bcd_to_excess3.v:46: $finish called at 16000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Excess-3's self-complementing property (`~excess3(d) == excess3(9-d)`)
  is a consequence of the `+3` offset centering the code range
  symmetrically around `7.5`; this design does not exploit or check that
  property, only produces the code.
* Purely combinational, no reset or clock.
* Driving `excess3 = 0` on an invalid input (rather than, say, leaving it
  as `bcd + 3` with a wrapped/overflowed value) makes the invalid case
  visibly distinct from any valid Excess-3 code, none of which is 0.

## 14. Common Mistakes

* Computing `bcd + 3` unconditionally without checking the valid range —
  for `bcd = 13` (`1101`), `13 + 3 = 16` overflows a 4-bit field to `0`,
  which is indistinguishable from a real (wrapped) result unless a
  separate `invalid` flag is provided.
* Treating the `invalid` output as optional or informational only — a
  downstream consumer that ignores it would silently accept whatever
  `excess3` value is present for an input that was never valid BCD.

## 15. Possible Improvements

* Add the inverse `excess3_to_bcd` converter (subtract 3, still with a
  range check on the Excess-3 side) as a companion module.
* Extend to multi-digit Excess-3 numbers with per-digit validity flags
  combined into one overall valid signal.

## 16. What This Program Teaches

* Implementing a fixed offset code conversion and recognizing its
  self-complementing property.
* Explicitly flagging out-of-domain inputs instead of letting them produce
  silently wrong results.
* The difference between "the bit width covers 16 values" and "the code
  only has 10 valid ones" — a recurring theme in BCD-adjacent designs.

## 17. Industry Relevance

Excess-3 is now mostly of historical/educational interest (used in some
early decimal computers), but the underlying lesson — validating that an
input code actually belongs to the code's valid subset before trusting a
computed result — applies directly to any real decoder for a sparse code
(BCD, one-hot, Gray, protocol opcodes).

## 18. How to Run

```bash
python3 scripts/run.py 052            # compile, simulate, synthesize, lint
cd 03-combinational-logic/052-bcd-to-excess3-converter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bcd_to_excess3.v tb/tb_bcd_to_excess3.v
vvp build/sim.vvp +vcd
```
