# 136 — ROM with `$readmemh` Initialization

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 08-memory | Elementary | `rom_init` | `src/rom_init.v` (+ `data/rom.hex`) | `tb/tb_rom_init.v` |

## 1. Objective

Replace program 135's hand-written `case` arms with the standard,
scalable way to initialize a ROM: a `reg` memory array loaded from an
external hex file via `$readmemh`.

## 2. What the Design Does

`rom_init` declares a 16-entry, 8-bit-wide `reg` array (`mem`) and
loads it at time 0 from `data/rom.hex` using `$readmemh`. `data` is a
plain combinational read (`assign data = mem[addr]`) — the file only
affects what the memory *contains*, not how it is read.

## 3. Why It Is Useful

`$readmemh`/`$readmemb` is how real designs initialize ROMs and
preloaded RAMs of any practical size — nobody hand-writes a `case`
statement for a 4KB lookup table. Keeping the data in a separate file
also lets the same RTL be reused with different contents without
touching the source.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `addr` | input | `ADDR_W` (4) | address |
| `data` | output | `DATA_W` (8) | `mem[addr]` |

Parameters: `ADDR_W` (4), `DATA_W` (8), `DEPTH` (16).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `mem` | `DEPTH` x `DATA_W` | the ROM array, loaded from `data/rom.hex` |

## 6. Architecture

```
data/rom.hex --[$readmemh, time 0]--> mem[0:15]
addr --> assign data = mem[addr]
```
`data/rom.hex` holds the ASCII codes for `"VERILOG-HDL-0136"` (16
characters, one hex byte per line) — chosen so the ROM's contents are
recognizable and easy to eyeball-verify, not just an arbitrary pattern.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A `reg` array (`mem [0:DEPTH-1]`) as a memory, the idiomatic Verilog
  representation of RAM/ROM that synthesis tools recognize and map to
  block memory resources.
* `$readmemh` in an `initial` block for file-based memory
  initialization — permitted in synthesizable RTL for ROM/RAM
  initialization per CLAUDE.md §4's exception to the "no `initial`
  blocks in synthesizable RTL" rule.
* A relative file path (`"data/rom.hex"`) resolved at simulation
  **runtime** against the working directory, not at compile time — the
  file need not even exist when `iverilog` compiles the design.

## 9. Source Code Explanation

```verilog
reg [DATA_W-1:0] mem [0:DEPTH-1];

initial begin
    $readmemh("data/rom.hex", mem);
end

assign data = mem[addr];
```
Three lines are the entire module: declare the array, load it once at
elaboration/time-0, and read it combinationally — everything else
(width, depth, exact contents) is external to this RTL.

## 10. Testbench Explanation

`tb_rom_init` reads the exact same `data/rom.hex` file into its own
independent `ref_mem` array via its own `$readmemh` call, then sweeps
every address and compares the DUT's `data` output against
`ref_mem[i]` — proving the DUT genuinely loaded the file's real
contents (not, say, all-zero or simulator-uninitialized `x` values that
happen to look plausible).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive vs. file | every address 0-15 | `data` matches the file's contents exactly |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 136` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_rom_init` — **PASS**

```text
TEST PASSED: 16 checks
tb/tb_rom_init.v:40: $finish called at 16000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 26 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The file path is relative to the simulation's working directory
  (`scripts/run.py` runs `vvp` from inside each program's own
  directory), so `"data/rom.hex"` resolves correctly without an
  absolute path — but this also means running the compiled `.vvp`
  binary from a different directory would fail to find the file.
* `$readmemh` expects plain hex digits, one or more values per line, no
  `0x` prefix and no explicit address annotations needed when the file
  supplies exactly `DEPTH` values starting at address 0 (as this one
  does).

## 14. Common Mistakes

* Forgetting that `$readmemh` reads *hex*, not decimal — supplying
  decimal values in the file silently loads wrong (though still
  hex-digit-valid-looking) data for many values.
* Using an absolute or incorrectly-relative path to the hex file,
  which works when run one way (e.g. from the repo root) and silently
  fails (loading `x`/uninitialized values) when run another way.

## 15. Possible Improvements

* Use `$readmemh`'s optional start/end address arguments to load only
  part of a larger array.
* Add a second file and a `generate`-based selection between two ROM
  contents at elaboration time.

## 16. What This Program Teaches

* The standard `$readmemh`-based ROM/RAM initialization idiom used
  throughout real synthesizable Verilog.
* Verifying loaded memory contents against an independent read of the
  same source file, not just against the RTL's own behavior.

## 17. Industry Relevance

Virtually every FPGA and ASIC design with a preloaded ROM or RAM
(firmware images, coefficient tables, lookup tables) uses this exact
`$readmemh`/`$readmemb` initialization pattern in simulation, paired
with vendor-specific mechanisms (e.g., `.mem`/`.coe` files) for the
actual bitstream/mask content in real hardware.

## 18. How to Run

```bash
python3 scripts/run.py 136            # compile, simulate, synthesize, lint
cd 08-memory/136-rom-readmemh && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/rom_init.v tb/tb_rom_init.v
vvp build/sim.vvp +vcd
```
