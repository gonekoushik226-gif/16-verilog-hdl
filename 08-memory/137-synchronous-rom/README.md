# 137 — Synchronous ROM

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 08-memory | Elementary | `sync_rom` | `src/sync_rom.v` (+ `data/rom.hex`) | `tb/tb_sync_rom.v` |

## 1. Objective

Turn program 136's combinational ROM read into a **registered** one —
the template real synthesis tools recognize for inferring dedicated
block-RAM/ROM resources, which have a registered output stage in
silicon.

## 2. What the Design Does

`sync_rom` is functionally identical to program 136's `rom_init` (same
16x8 array, same `$readmemh`-loaded contents) except the read is
captured in a register: `data <= mem[addr]` inside
`always @(posedge clk)`. `data` reflects `mem[addr]` one clock cycle
after `addr` is presented, not immediately.

## 3. Why It Is Useful

Most real FPGA and ASIC block-RAM primitives have a mandatory registered
output stage — a combinational-read ROM like program 135/136's either
gets mapped to slower distributed logic or requires an extra external
register anyway. Writing the RTL with the register already in the read
path is what lets synthesis tools map it directly onto dedicated,
efficient block memory.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `addr` | input | `ADDR_W` (4) | address, sampled on `posedge clk` |
| `data` | output | `DATA_W` (8) | `mem[addr]`, valid one cycle after `addr` |

Parameters: `ADDR_W` (4), `DATA_W` (8), `DEPTH` (16).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `mem` | `DEPTH` x `DATA_W` | the ROM array, loaded from `data/rom.hex` |

## 6. Architecture

```
posedge clk: data <= mem[addr]     (addr sampled the same edge)
```
One-cycle read latency: change `addr`, and `data` shows the new value
starting the cycle *after* the change.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A registered memory read (`data <= mem[addr]` in a clocked `always`
  block) — the block-RAM-inference idiom, contrasted directly with
  program 136's combinational `assign data = mem[addr]`.
* A deliberate, explicitly-documented deviation from this repository's
  default reset style: `data` has **no** reset at all, because forcing
  a reset value onto a block-RAM primitive's output register is either
  unsupported or costly on real FPGA architectures — see §13.

## 9. Source Code Explanation

```verilog
always @(posedge clk) begin
    data <= mem[addr];
end
```
This is the entire behavioral difference from program 136: the read is
now inside a clocked block using a non-blocking assignment, so `data`
updates one cycle after `addr` — genuinely registered, not merely
"looks the same but happens to be assigned in a clocked block."

## 10. Testbench Explanation

`tb_sync_rom` changes `addr` and checks `data` **twice** per address:
immediately after the change (before the next clock edge), where
`data` must still show the *previous* address's value — directly
proving the read is registered, not combinational — and again one
cycle later, where `data` must match the new address's value, read
independently from the same hex file into the testbench's own
reference array.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | not-yet-updated check | change `addr`, sample before the next edge | `data` still shows the previous address's value |
| 2 | one-cycle latency | sample one cycle after `addr` changes | `data` matches the new address's value |

Both checks run across all 16 addresses.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 137` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_sync_rom` — **PASS**

```text
TEST PASSED: 30 checks
tb/tb_sync_rom.v:58: $finish called at 156000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 33 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* **No reset on `data`, by design.** This repository's default reset
  style (CLAUDE.md §4) is asynchronous, active-low `rst_n` on all
  sequential logic — but real block-RAM primitives generally either
  have no output reset at all or only a synchronous one with real area/
  timing cost, and adding one here would often force a synthesis tool to
  fall back to distributed-logic implementation instead of inferring
  actual block RAM. Omitting it is the standard, intentional template
  for block-ROM inference, stated explicitly here rather than left as an
  unremarked inconsistency with the rest of the repository.
* `data`'s value is simulator-undefined (`x`) until the very first
  clock edge, since there is no reset to establish a known value
  earlier — the testbench's first read is deliberately taken only after
  priming with one clock edge first.

## 14. Common Mistakes

* Adding a reset to a block-RAM read register "for consistency" without
  realizing it can prevent block-RAM inference entirely on some target
  architectures — a real, not merely stylistic, synthesis consequence.
* Checking `data` immediately after changing `addr` and expecting the
  new value already — a mistake that would go unnoticed with a
  combinational ROM but produces a stale read here.

## 15. Possible Improvements

* Add an optional registered output-enable for power-gating the read
  path when idle.
* Compare Yosys's resource inference between this registered version
  and program 136's combinational one on a real target technology
  library (out of scope for the generic synthesis check used here).

## 16. What This Program Teaches

* The registered-read template real tools use to infer block RAM/ROM.
* Why reset style is sometimes deliberately *not* the repository
  default, and why that must be stated explicitly rather than silently
  deviated from.
* Directly testing for "not yet updated" as well as "eventually
  correct" to prove a genuine one-cycle latency, not just a
  same-cycle read with different syntax.

## 17. Industry Relevance

Registered-read ROM/RAM templates are the standard, portable way to
target block memory resources across FPGA vendors and ASIC memory
compilers; getting the exact idiom right (including the absence of an
output reset) is frequently the difference between efficient block-RAM
inference and an unexpectedly large distributed-logic implementation.

## 18. How to Run

```bash
python3 scripts/run.py 137            # compile, simulate, synthesize, lint
cd 08-memory/137-synchronous-rom && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/sync_rom.v tb/tb_sync_rom.v
vvp build/sim.vvp +vcd
```
