# 100 — Shift Register (SIPO)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Beginner | `shift_sipo` | `src/shift_sipo.v` | `tb/tb_shift_sipo.v` |

## 1. Objective

Turn program 099's serial delay line into a serial-to-parallel
converter: after `WIDTH` bits have shifted in, the whole assembled word
is available at once.

## 2. What the Design Does

`shift_sipo` shifts `serial_in` into an internal register every cycle,
exposing the full `WIDTH`-bit contents continuously on `parallel_out`.
`msb_first` selects whether the first bit received ends up at the word's
MSB (bits shift left, entering at the LSB) or LSB (bits shift right,
entering at the MSB).

## 3. Why It Is Useful

Receiving data serially (a UART, SPI, or any bit-at-a-time protocol) but
needing to use it as a whole word is exactly what a SIPO register
provides — this is the receive-side shift register inside every serial
peripheral in category 10.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `serial_in` | input | 1 | bit entering the register |
| `msb_first` | input | 1 | 1 = first bit received becomes the MSB, 0 = LSB |
| `parallel_out` | output | `WIDTH` | the assembled word, continuously available |

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `shreg` | `WIDTH` | the assembling register |

## 6. Architecture

```
msb_first=1: shreg <= {shreg[WIDTH-2:0], serial_in}   (shift left, first bit ends at MSB)
msb_first=0: shreg <= {serial_in, shreg[WIDTH-1:1]}   (shift right, first bit ends at LSB)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* The same concatenation-shift idiom as program 099, applied in both
  directions depending on a runtime control signal.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         shreg <= {WIDTH{1'b0}};
    else if (msb_first) shreg <= {shreg[WIDTH-2:0], serial_in};
    else                shreg <= {serial_in, shreg[WIDTH-1:1]};
end
```
In MSB-first mode, the first bit received is pushed in at the LSB and
then shifted left every subsequent cycle, ending up at the MSB after
`WIDTH-1` more shifts — exactly how most serial protocols (e.g. SPI,
UART data framing) describe "MSB first."

## 10. Testbench Explanation

`tb_shift_sipo` shifts in known and random bytes in both `msb_first`
modes (feeding the bits in the corresponding order by hand in the
testbench), checking the fully-assembled `parallel_out` after `WIDTH`
cycles matches the original byte exactly.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | MSB-first, directed | 0xA5, 0x00, fed MSB-first | parallel_out matches after WIDTH cycles |
| 2 | LSB-first, directed | 0x3C, 0xFF, fed LSB-first | parallel_out matches after WIDTH cycles |
| 3 | random, both orders | 20 random bytes total | parallel_out matches every time |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 100` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_shift_sipo` — **PASS**

```text
TEST PASSED: 24 checks
tb/tb_shift_sipo.v:73: $finish called at 1926000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 16 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `parallel_out` is valid continuously, not just after exactly `WIDTH`
  cycles — a real consumer typically needs its own bit counter or framing
  signal to know when a full word has actually arrived (see program 175's
  UART transmitter/176's receiver for that framing logic).

## 14. Common Mistakes

* Mixing up which direction corresponds to "MSB first" — it depends on
  which end of the register the incoming bit enters, not just the shift
  direction alone.

## 15. Possible Improvements

* Add a bit counter and a `word_ready` pulse so a consumer does not need
  to track timing externally.

## 16. What This Program Teaches

* Serial-to-parallel assembly and the MSB-first/LSB-first convention.

## 17. Industry Relevance

Every serial receiver (UART, SPI, I2C) needs exactly this
serial-to-parallel assembly stage internally.

## 18. How to Run

```bash
python3 scripts/run.py 100            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/100-shift-register-sipo && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/shift_sipo.v tb/tb_shift_sipo.v
vvp build/sim.vvp +vcd
```
