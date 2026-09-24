# 101 — Shift Register (PISO)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Beginner | `shift_piso` | `src/shift_piso.v` | `tb/tb_shift_piso.v` |

## 1. Objective

Build the reverse of program 100's SIPO: capture a whole word in one
cycle, then serialize it out one bit per cycle — the transmit-side shift
register.

## 2. What the Design Does

`shift_piso` loads `parallel_in` into an internal register when `load=1`
and, when `shift_en=1`, shifts it out MSB-first on `serial_out`, one bit
per cycle, with 0 filling in behind each departing bit.

## 3. Why It Is Useful

Sending a parallel word over a serial link (again: UART, SPI) requires
exactly this parallel-to-serial conversion — this is the transmit shift
register inside every serial peripheral in category 10.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `load` | input | 1 | capture `parallel_in` this cycle |
| `shift_en` | input | 1 | shift out the next bit this cycle |
| `parallel_in` | input | `WIDTH` | word to serialize |
| `serial_out` | output | 1 | current MSB, shifted out one bit per cycle |

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `shreg` | `WIDTH` | the register being serialized |

## 6. Architecture

```
load:     shreg <= parallel_in
shift_en: shreg <= {shreg[WIDTH-2:0], 1'b0}     (shift left, 0 fills the LSB)
serial_out = shreg[WIDTH-1]                      (current bit to send)
```
`load` takes priority over `shift_en`, matching how a real transmitter
would refuse to shift mid-load.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Priority `if`/`else if` (load beats shift) inside a clocked block,
  same pattern as program 089's enable/reset priority.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)        shreg <= {WIDTH{1'b0}};
    else if (load)     shreg <= parallel_in;
    else if (shift_en) shreg <= {shreg[WIDTH-2:0], 1'b0};
end
assign serial_out = shreg[WIDTH-1];
```
Loading replaces the entire register in one cycle; shifting moves every
bit one position toward the MSB (which is what `serial_out` reads),
discarding the departed MSB and filling the vacated LSB with 0.

## 10. Testbench Explanation

`tb_shift_piso` loads a known byte, then shifts `WIDTH` times, checking
`serial_out` matches that byte's bits from MSB to LSB in order — for
directed corner values (`0x00`, `0xFF`, `0x81`, `0xA5`) and 10 random
bytes.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | directed bytes | 0xA5, 0x00, 0xFF, 0x81, loaded then shifted 8x | serial_out matches each bit MSB-first |
| 2 | random | 10 random bytes | same |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 101` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_shift_piso` — **PASS**

```text
TEST PASSED: 112 checks
tb/tb_shift_piso.v:66: $finish called at 1266000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 17 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* After `WIDTH` shifts the register reads all-zero; a real transmitter
  typically reloads before or exactly as the last bit is sent, which
  this testbench's `load_and_check` task mirrors by reloading at the
  start of every transfer.

## 14. Common Mistakes

* Allowing `shift_en` to take priority over `load` — would corrupt a
  freshly-loaded word if both happened to be asserted in the same cycle.

## 15. Possible Improvements

* Add a `busy`/`done` status flag tracking shift progress, avoiding the
  need for an external bit counter.

## 16. What This Program Teaches

* Parallel-to-serial conversion, the mirror operation of program 100's
  SIPO.

## 17. Industry Relevance

Every serial transmitter (UART, SPI) needs exactly this
parallel-to-serial shift stage internally.

## 18. How to Run

```bash
python3 scripts/run.py 101            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/101-shift-register-piso && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/shift_piso.v tb/tb_shift_piso.v
vvp build/sim.vvp +vcd
```
