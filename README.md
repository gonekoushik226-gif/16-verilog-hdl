# 16-verilog-hdl

A structured Verilog HDL and RTL-design library that goes from a single
logic gate to integrated, industry-entry-level RTL projects. Every program is
a complete, self-contained deliverable:

* synthesizable RTL (`src/`), split into real modules for hierarchical designs,
* a self-checking testbench (`tb/`),
* a README explaining the actual implementation line by line, with the
  recorded simulation output,
* automated verification: Icarus Verilog simulation, Yosys generic
  synthesis and Verilator lint through one script.

## Curriculum

| # | Category | Programs | Topics |
|---|---|---|---|
| 00 | [foundations](00-foundations/) | 001–016 | module structure, nets vs regs, operators, blocking/non-blocking, parameters, generate, testbench basics |
| 01 | [basic-gates](01-basic-gates/) | 017–031 | AND … XNOR, buffers, tri-state, modelling styles, universal gates, hazards |
| 02 | [multiplexers-encoders-decoders](02-multiplexers-encoders-decoders/) | 032–045 | muxes, demuxes, decoders, (priority) encoders, address decoding |
| 03 | [combinational-logic](03-combinational-logic/) | 046–061 | comparators, parity, code converters, shifters, barrel shifters, Hamming code |
| 04 | [arithmetic-circuits](04-arithmetic-circuits/) | 062–084 | adders (RCA, CLA, CSLA, CSKA, CSA), subtractors, multipliers, dividers, ALUs, fixed/floating point |
| 05 | [sequential-logic](05-sequential-logic/) | 085–097 | latches, flip-flops, reset styles, edge detection, pipeline registers |
| 06 | [registers-and-counters](06-registers-and-counters/) | 098–117 | shift registers, LFSRs, counters, clock dividers, tick generators |
| 07 | [finite-state-machines](07-finite-state-machines/) | 118–134 | Moore/Mealy, encodings, controllers, FSMD, safe FSMs |
| 08 | [memory](08-memory/) | 135–153 | ROM, RAM, dual-port RAM, register files, sync/async FIFOs, CAM, BIST, ECC |
| 09 | [digital-systems](09-digital-systems/) | 154–173 | debouncers, PWM, timers, displays, keypad, VGA timing, sensors |
| 10 | [communication](10-communication/) | 174–191 | UART, SPI, I²C, CRC, line coding, 8b/10b |
| 11 | [bus-protocols](11-bus-protocols/) | 192–209 | valid/ready, APB, AHB-Lite, AXI4-Lite/Stream/Full, Wishbone, bridges |
| 12 | [datapath-and-rtl](12-datapath-and-rtl/) | 210–235 | pipelining, sequential arithmetic, DSP filters, arbiters, CDC, resets |
| 13 | [processor-components](13-processor-components/) | 236–253 | PC, register file, ALU, decoder, control, hazard/forwarding, predictors |
| 14 | [processors](14-processors/) | 254–264 | 8-bit CPUs, 16-bit RISC, RV32I single/multi-cycle/pipelined |
| 15 | [advanced-rtl](15-advanced-rtl/) | 265–278 | caches, DMA, SDRAM controller, bus matrix, packet processing |
| 16 | [verification](16-verification/) | 279–292 | reference models, BFMs, random/constrained stimulus, scoreboards, coverage |
| 17 | [fpga-oriented-designs](17-fpga-oriented-designs/) | 293–308 | board-level designs: UART echo, VGA, displays, BRAM/DSP inference |
| 18 | [industry-entry-projects](18-industry-entry-projects/) | 309–324 | SoC, DMA engine, image pipeline, AES/SHA cores, Ethernet MAC, packet switch |

The full list with concepts, files and test plans is in
[`PROGRAM_CATALOG.md`](PROGRAM_CATALOG.md). Current progress is in
[`PROJECT_STATUS.md`](PROJECT_STATUS.md).

## Program layout

```
04-arithmetic-circuits/082-alu-8bit-hierarchical/
├── src/            RTL, one module per file
├── tb/             tb_*.v top-level testbenches (+ helper models)
├── program.conf    optional flow settings (synthesis top, flags)
└── README.md       explanation + recorded simulation results
```

## Running the designs

Requirements: Icarus Verilog (simulation), optionally Yosys (synthesis
check) and Verilator (lint).

```bash
sudo apt-get install -y iverilog yosys verilator

python3 scripts/run.py 017            # one program by number
python3 scripts/run.py --category 04  # one category
python3 scripts/run.py --all -j 4     # full regression
make regress                          # same, via make
```

To look at waveforms for one program:

```bash
cd 01-basic-gates/017-and-gate
iverilog -g2005 -o build/sim.vvp src/*.v tb/tb_and_gate.v
vvp build/sim.vvp +vcd      # writes build/*.vcd, open with GTKWave
```

## Verification status vocabulary

* **SIMULATION VERIFIED** — self-checking testbench passes in Icarus Verilog.
* **SYNTHESIS VERIFIED (Yosys generic synthesis)** — the RTL synthesizes with
  Yosys `synth` and passes `check -assert` with no unintended latches. This is
  not a timing sign-off.
* **FPGA HARDWARE VERIFIED** — not claimed for any program; the designs have
  not been run on a physical board.

The designs are educational reference implementations. Where a design
simplifies a real standard (for example AXI, SDRAM or IEEE-754), its README
lists exactly what is and is not implemented.
