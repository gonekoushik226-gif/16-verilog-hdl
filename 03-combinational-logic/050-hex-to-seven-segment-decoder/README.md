# 050 — Hex-to-Seven-Segment Decoder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Beginner | `hex_to_7seg` | `src/hex_to_7seg.v` | `tb/tb_hex_to_7seg.v` |

## 1. Objective

Implement the standard hexadecimal-digit-to-seven-segment-display lookup
table with a `case` statement, and practice reading/writing active-low
segment patterns.

## 2. What the Design Does

`hex_to_7seg` decodes a 4-bit hex nibble (`0`–`F`) into the seven segment
drive signals of a common-anode seven-segment display, ordered
`seg = {a,b,c,d,e,f,g}`. Because the display is common-anode, each segment
is turned **on** by driving its line **low** (`0`); `seg = 7'b0000000`
lights every segment (digit `8`).

## 3. Why It Is Useful

Seven-segment decoding is the canonical `case`-statement lookup-table
exercise, and the resulting block is a real, frequently-instantiated
peripheral in FPGA and microcontroller board support packages for
diagnostic and numeric displays.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `hex` | input | 4 | hex digit to display, `0x0`–`0xF` |
| `seg` | output | 7 | active-low segment drives, `{a,b,c,d,e,f,g}` |

## 5. Internal Signals

None — the output is a direct `case`-statement function of the input.

## 6. Architecture

```
                     ┌───┐
                     │ a │
                 ┌───┴───┴───┐
                 │f         b│
                 └───┬───┬───┘
                     │ g │
                 ┌───┴───┴───┐
                 │e         c│
                 └───┬───┬───┘
                     │ d │
                     └───┘
hex[3:0] ──[case lookup]──► seg[6:0] = {a,b,c,d,e,f,g}, active-low
```

## 7. Module Hierarchy and Connections

```
tb_hex_to_7seg
└── dut : hex_to_7seg
```

## 8. Verilog Concepts Used

* `case` statement as a direct hardware lookup table, with a `default` arm
  even though the 4-bit input already covers all 16 cases exhaustively
  (project coding standard: every `case` has a `default`).
* Active-low output convention: a segment lookup table where `0` means "on".
* Grouping a binary literal's bits with `_` separators for per-segment
  readability (`7'b0_0_0_0_0_0_1`), which the Verilog lexer ignores.

## 9. Source Code Explanation

```verilog
case (hex)
    4'h0: seg = 7'b0_0_0_0_0_0_1;   // a,b,c,d,e,f on; g off
    4'h1: seg = 7'b1_0_0_1_1_1_1;   // b,c on
    ...
    default: seg = 7'b1_1_1_1_1_1_1;
endcase
```
* Each case arm is the bitwise complement of the digit's standard
  active-high segment pattern (e.g. digit `0` lights segments a-f and
  leaves g dark; active-low that is `0000001` in `{a,b,c,d,e,f,g}` order).
* `default` sets every segment off (`1111111`, blank display) — never
  reached for a well-formed 4-bit `hex`, but present because the project's
  coding standard requires every `case` to have one, and because
  simulation can still drive `hex` to an unknown (`x`) value that must not
  produce an unpredictable segment pattern.

## 10. Testbench Explanation

`tb_hex_to_7seg` holds its own copy of the 16-entry lookup table (an
independent `expected_seg` function, not a call into the RTL) and checks
`hex_to_7seg`'s output for every one of the 16 possible hex digits — a
genuinely exhaustive test since the entire input space has only 16 values.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | All 16 hex digits | `hex = 0x0..0xF` | `seg` matches the standard active-low 7-segment table for each digit |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 050` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_hex_to_7seg` — **PASS**

```text
all 16 hex digits vs the standard 7-segment table:
TEST PASSED: 16 checks
tb/tb_hex_to_7seg.v:67: $finish called at 16000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 31 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Active-low output matches common-anode seven-segment display hardware
  directly; a common-cathode display would need the complement of every
  entry in this table.
* Purely combinational, no reset or clock; decode latency is a single
  `case` (mux tree) gate delay.
* The `default` arm intentionally blanks the display rather than showing a
  stale or arbitrary pattern for an out-of-range or unknown input.

## 14. Common Mistakes

* Mixing up active-high and active-low segment conventions — connecting
  this decoder to a common-cathode display without inverting every bit
  would light every segment except the intended ones.
* Getting the segment bit order wrong (`{a,b,c,d,e,f,g}` here) when wiring
  to a physical display whose pin order differs — a board-level wiring
  concern the decoder itself cannot detect.
* Omitting the `default` arm and relying on the input never going out of
  range — with a 4-bit input driven to `x` in simulation, a decoder
  without a default can produce a `case` mismatch that some tools resolve
  unpredictably; Yosys generic synthesis also treats an incomplete `case`
  in a `reg` assignment as a potential latch source.

## 15. Possible Improvements

* Add a hexadecimal vs. decimal-only mode (blank display for `A`-`F`).
* Add a dot-point pass-through output.
* Extend to a multi-digit multiplexed display driver, cycling digit select
  lines and segment data together.

## 16. What This Program Teaches

* Translating a real hardware truth table into a synthesizable `case`
  statement.
* Active-low signal conventions and why they matter for real display
  hardware wiring.
* Writing an independent lookup table in the testbench rather than
  re-deriving the DUT's own table.

## 17. Industry Relevance

Seven-segment decoders appear on nearly every FPGA/CPLD development board
and many embedded systems for low-cost numeric status display; the same
`case`-based lookup-table pattern generalizes directly to character LCD
and matrix display decoders.

## 18. How to Run

```bash
python3 scripts/run.py 050            # compile, simulate, synthesize, lint
cd 03-combinational-logic/050-hex-to-seven-segment-decoder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/hex_to_7seg.v tb/tb_hex_to_7seg.v
vvp build/sim.vvp +vcd
```
