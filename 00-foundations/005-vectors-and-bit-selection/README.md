# 005 — Vectors and Bit Selection

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Beginner | `bit_manipulator` | `src/bit_manipulator.v` | `tb/tb_bit_manipulator.v` |

## 1. Objective

Select, rearrange and extend bits of a 32-bit vector using bit selects, fixed
and indexed part selects, concatenation and replication.

## 2. What the Design Does

For `data_in = 32'h1234_56F8`:

| Output | Expression | Value |
|---|---|---|
| `msb` | `data_in[31]` | 0 |
| `lsb` | `data_in[0]` | 0 |
| `low_byte` | `data_in[7:0]` | `f8` |
| `high_byte` | `data_in[31 -: 8]` | `12` |
| `sel_byte` | `data_in[byte_sel*8 +: 8]` | `f8`, `56`, `34`, `12` for `byte_sel` 0–3 |
| `byte_swap` | bytes reversed | `f8563412` |
| `sext_byte` | low byte sign-extended | `fffffff8` |
| `rotl8` | rotate left 8 | `3456f812` |

## 3. Why It Is Useful

Buses carry packed fields: instruction encodings, packet headers, byte lanes of
a 32-bit memory. Extracting a byte, swapping endianness between a big-endian
network and a little-endian CPU, and sign-extending a loaded byte are
operations every processor and bus interface performs.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_in` | input | 32 | Source word |
| `byte_sel` | input | 2 | Byte index for `sel_byte` (0 = bits 7:0) |
| `msb`, `lsb` | output | 1 | Bit 31, bit 0 |
| `low_byte` | output | 8 | Bits 7:0 |
| `high_byte` | output | 8 | Bits 31:24 |
| `sel_byte` | output | 8 | Byte selected by `byte_sel` |
| `byte_swap` | output | 32 | Byte order reversed |
| `sext_byte` | output | 32 | `data_in[7:0]` sign-extended |
| `rotl8` | output | 32 | `data_in` rotated left by 8 bits |

## 5. Internal Signals

None.

## 6. Architecture

Everything except `sel_byte` is pure wiring (no gates). `sel_byte` is an
8-bit 4:1 multiplexer controlled by `byte_sel` — the only logic Yosys reports.

## 7. Module Hierarchy and Connections

```
tb_bit_manipulator
└── dut : bit_manipulator
```

## 8. Verilog Concepts Used

* Vector declaration `[31:0]` (MSB first, "little-endian bit numbering").
* Bit select `v[i]`, part select `v[msb:lsb]` (constant bounds).
* Indexed part select `v[base +: width]` and `v[base -: width]` — `base` may
  be a variable, `width` must be constant.
* Concatenation `{a, b}` and replication `{n{bit}}`.

## 9. Source Code Explanation

```verilog
assign msb = data_in[31];
assign lsb = data_in[0];
assign low_byte  = data_in[7:0];
```
Constant selects: just wires.

```verilog
assign high_byte = data_in[31 -: 8];
```
`-:` counts **down** from the base: bits 31, 30, …, 24. Equivalent to
`data_in[31:24]`.

```verilog
assign sel_byte = data_in[byte_sel * 8 +: 8];
```
`+:` counts **up** from the base: bits `base+7 … base`. The ordinary
`data_in[byte_sel*8+7 : byte_sel*8]` is illegal because both bounds of a
normal part select must be constants; the indexed form fixes the width and
lets the start move. Synthesis builds a multiplexer.

```verilog
assign byte_swap = {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
```
The first element of a concatenation goes to the most significant position,
so byte 0 lands in bits 31:24 — an endianness swap.

```verilog
assign sext_byte = {{24{data_in[7]}}, data_in[7:0]};
```
Replicates the byte's sign bit 24 times above it. `8'hF8` (−8) becomes
`32'hFFFF_FFF8` (still −8); `8'h7F` becomes `32'h0000_007F`.

```verilog
assign rotl8 = {data_in[23:0], data_in[31:24]};
```
Rotation: the top byte wraps around to the bottom. No bits are lost, unlike a
shift.

## 10. Testbench Explanation

The `check_all` task recomputes every output with **shifts and masks**
(`(data_in >> (8*byte_sel)) & 32'hFF`, `(data_in << 8) | (data_in >> 24)`, …)
instead of part selects, so it is an independent model. The bench runs:

1. the directed word `32'h1234_56F8` for all four `byte_sel` values, printing
   each output,
2. sign-extension corners `0x7F`, `0x80`, all ones, all zeros,
3. 500 random words with random `byte_sel`.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | directed word, `byte_sel` 0–3 | `f8`, `56`, `34`, `12` |
| 2 | `0x7F` / `0x80` | `sext_byte` = `0000007f` / `ffffff80` |
| 3 | all ones / zeros | swap and rotate unchanged |
| 4 | 500 random words | all outputs match the shift/mask model |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 005` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_bit_manipulator` — **PASS**

```text
data_in   = 123456f8
byte_sel=0 -> sel_byte=f8
byte_sel=1 -> sel_byte=56
byte_sel=2 -> sel_byte=34
byte_sel=3 -> sel_byte=12
msb=0 lsb=0 low_byte=f8 high_byte=12
byte_swap=f8563412 sext_byte=fffffff8 rotl8=3456f812
TEST PASSED: 508 checks
tb/tb_bit_manipulator.v:77: $finish called at 508000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 24 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Rewiring is free in hardware; only data-dependent selection costs logic.
* Declaring vectors consistently as `[MSB:0]` avoids confusion; mixing
  `[0:31]` and `[31:0]` in one design is a classic source of bugs.

## 14. Common Mistakes

* **Variable part selects with `:`** — `v[i*8+7:i*8]` does not compile; use
  `v[i*8 +: 8]`.
* **Wrong direction of `+:`/`-:`** — `v[7 +: 8]` is bits 14:7, not 7:0.
* **Sign-extending with zeros** — `{24'b0, byte}` is zero extension; negative
  bytes change value.
* **Out-of-range selects** return `x` in simulation and are flagged by lint.

## 15. Possible Improvements

* Generalise the byte extraction to any field width with parameters.
* Add half-word selection and sign extension (used in 238 and 246).

## 16. What This Program Teaches

* Every form of bit and part selection.
* Endianness conversion.
* Sign extension by replication.
* Rotation vs shift.

## 17. Industry Relevance

Load/store units sign-extend bytes and half-words; network interfaces swap byte
order (`htonl`); instruction decoders slice immediate fields out of a 32-bit
word — all with exactly these constructs.

## 18. How to Run

```bash
python3 scripts/run.py 005
cd 00-foundations/005-vectors-and-bit-selection && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/bit_manipulator.v tb/tb_bit_manipulator.v
vvp build/sim.vvp
```
