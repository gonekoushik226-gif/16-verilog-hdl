# 099 — Shift Register (SISO)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Beginner | `shift_siso` | `src/shift_siso.v` | `tb/tb_shift_siso.v` |

## 1. Objective

Chain `WIDTH` single-bit flip-flops into a serial delay line — the
simplest shift register, and the base every other shift-register variant
in this category (SIPO, PISO, universal) modifies.

## 2. What the Design Does

`shift_siso` shifts one bit in from `serial_in` every clock and shifts
one bit out to `serial_out` — a bit entering at cycle N appears on
`serial_out` exactly `WIDTH` cycles later.

## 3. Why It Is Useful

A pure shift register is the building block of serial communication
interfaces (UART, SPI), delay lines, and LFSR-based generators (program
103) — it turns "bits one at a time" into "bits available in registered
form," or the reverse.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `serial_in` | input | 1 | bit entering the register |
| `serial_out` | output | 1 | bit leaving the register |

Parameters: `WIDTH` (default 8).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `shreg` | `WIDTH` | the shift register's full state |

## 6. Architecture

```
shreg <= {shreg[WIDTH-2:0], serial_in}   (shift left, insert at LSB)
serial_out = shreg[WIDTH-1]              (MSB is the oldest bit, shifted out)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Concatenation-based shifting (`{shreg[WIDTH-2:0], serial_in}`), the
  standard idiom for a shift register in Verilog.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) shreg <= {WIDTH{1'b0}};
    else        shreg <= {shreg[WIDTH-2:0], serial_in};
end
assign serial_out = shreg[WIDTH-1];
```
Every cycle, all bits move one position toward the MSB, and `serial_in`
fills the vacated LSB — after `WIDTH` cycles, a given input bit has
moved all the way to `shreg[WIDTH-1]`, where it appears on `serial_out`.

## 10. Testbench Explanation

`tb_shift_siso` pushes a 40-bit random stream in, recording each bit in
a software queue, and checks each one reappears on `serial_out` exactly
`WIDTH` cycles later — the queue-index arithmetic follows the same
cycle-vs-edge derivation used in program 096's pipeline testbench.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | delay line | 40 random bits | each bit reappears on serial_out exactly WIDTH cycles later |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 099` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_shift_siso` — **PASS**

```text
TEST PASSED: 33 checks
tb/tb_shift_siso.v:63: $finish called at 406000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 8 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely a delay line; no parallel access to intermediate bits (see
  program 100 for parallel-out access).

## 14. Common Mistakes

* Off-by-one errors relating a testbench's loop-iteration counter to the
  number of clock edges actually elapsed when checking a fixed-latency
  delay — the same class of bug documented in program 096's README,
  guarded against here from the start.

## 15. Possible Improvements

* Add parallel output taps at every stage (this is exactly program
  100's SIPO).

## 16. What This Program Teaches

* The basic shift-register idiom and its fixed-latency delay-line
  behavior.

## 17. Industry Relevance

Serial delay lines appear in serial communication shift logic, simple
digital filters, and as the storage core of LFSR-based pseudo-random
generators (program 103).

## 18. How to Run

```bash
python3 scripts/run.py 099            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/099-shift-register-siso && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/shift_siso.v tb/tb_shift_siso.v
vvp build/sim.vvp +vcd
```
