# 135 — ROM as a `case` Lookup

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 08-memory | Beginner | `rom_case` | `src/rom_case.v` | `tb/tb_rom_case.v` |

## 1. Objective

Open the memory category with the simplest possible read-only memory: a
purely combinational `case` lookup, with no clock, no memory array
declaration, and no initialization file.

## 2. What the Design Does

`rom_case` maps a 4-bit `addr` to an 8-bit `data` value via a `case`
statement — a squares table (`data = addr * addr`). The output changes
combinationally, immediately following any change to `addr`, with no
clock involved at all.

## 3. Why It Is Useful

Small fixed lookup tables (trig tables, gamma-correction curves,
opcode-to-microcode maps) are extremely common in real RTL, and a
`case`-statement ROM is the most direct, most readable way to express
one when the table is small enough to write out by hand — before this
category moves on to array-based (`136`) and file-initialized (`137`)
approaches for larger tables.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `addr` | input | 4 | address, 0-15 |
| `data` | output | 8 | `addr * addr` |

## 5. Internal Signals

None — the output is a direct combinational function of the input.

## 6. Architecture

```
addr --> [16-entry case lookup] --> data
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A purely combinational `always @(*)` block with a `case` statement as
  the entire implementation of a memory — no `reg` array, no clock.
* A `default` arm even though `addr` is 4 bits and every one of the 16
  possible values is already listed — defensive completeness per
  CLAUDE.md §4, and free here since the `case` is already exhaustive.

## 9. Source Code Explanation

```verilog
always @(*) begin
    case (addr)
        4'd0:  data = 8'd0;
        4'd1:  data = 8'd1;
        ...
        4'd15: data = 8'd225;
        default: data = 8'd0;
    endcase
end
```
Each entry is `addr*addr`, written out as a literal constant rather than
computed with a multiplier — the entire point of a ROM being that the
computation happens once, at design time, not in hardware at run time.

## 10. Testbench Explanation

`tb_rom_case` is purely combinational too: it sweeps all 16 possible
`addr` values, waits `#1` for the combinational logic to settle, and
checks `data` against `addr*addr` computed independently by the
testbench's own multiplication — exhaustive coverage of the entire
address space.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | every address 0-15 | `data == addr*addr` for all 16 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 135` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_rom_case` — **PASS**

```text
TEST PASSED: 16 checks
tb/tb_rom_case.v:38: $finish called at 16000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 25 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* A `case`-statement ROM like this one only scales to small tables
  written out by hand; program 136 shows the array-plus-`$readmemh`
  approach that scales to far larger tables without listing every entry
  in the source.
* Being purely combinational, `rom_case` has zero read latency — useful
  for small tables, but real synthesized ROMs (especially large ones
  mapped to block RAM) are usually registered (program 137) for timing
  closure reasons.

## 14. Common Mistakes

* Forgetting the `default` arm — even on an exhaustively-listed 4-bit
  `case`, omitting it can still cause synthesis tools to infer an
  unintended latch if they cannot prove the `case` covers every
  possible value of `addr` (e.g., if `addr` had unlisted `x`/`z` states
  in some simulation contexts).
* Trying to synthesize a large table this way — a few dozen entries of
  hand-written `case` arms becomes unmanageable and error-prone compared
  to `$readmemh`-based initialization.

## 15. Possible Improvements

* Parameterize the address/data widths and generate the table
  programmatically (at Verilog elaboration time) for a different
  function, rather than hard-coding squares.

## 16. What This Program Teaches

* Implementing a small fixed lookup table directly as combinational
  logic.
* Recognizing when a `case`-based ROM is (and is not) the right tool,
  versus the array-based approaches later in this category.

## 17. Industry Relevance

Small combinational lookup tables implemented via `case` are common for
opcode decoding, small coefficient tables, and other fixed mappings
where the table is short enough to read directly in the RTL source.

## 18. How to Run

```bash
python3 scripts/run.py 135            # compile, simulate, synthesize, lint
cd 08-memory/135-rom-case && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/rom_case.v tb/tb_rom_case.v
vvp build/sim.vvp +vcd
```
