# 045 — Memory-Map Address Decoder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Intermediate | `address_decoder` | `src/address_decoder.v` | `tb/tb_address_decoder.v` |

## 1. Objective

Implement a realistic memory-map address decoder that generates individual
chip-select signals for several address regions of different sizes, and an
explicit error flag for any address that falls in an unmapped gap —
closing out this category by combining decoding, priority, and range
comparison into one practical block.

## 2. What the Design Does

`address_decoder` classifies a 16-bit address into one of four mapped
regions or flags it as unmapped:

| Region | Address range | Size | Chip-select |
|---|---|---|---|
| ROM | `0x0000`–`0x1FFF` | 8 KiB | `cs_rom` |
| RAM | `0x2000`–`0x5FFF` | 16 KiB | `cs_ram` |
| PERIPH | `0x6000`–`0x6FFF` | 4 KiB | `cs_periph` |
| UART | `0x7000`–`0x70FF` | 256 B | `cs_uart` |
| (gap) | `0x7100`–`0xFFFF` | — | none; `error = 1` |

Exactly one of `{cs_rom, cs_ram, cs_periph, cs_uart, error}` is 1 for any
given `addr`; the regions are deliberately unequal in size and not aligned
to convenient power-of-two boundaries, unlike the `decoder2to4`/`decoder_n`
blocks earlier in this category.

## 3. Why It Is Useful

Every memory-mapped bus (CPU-to-peripheral, AXI/AHB/APB, or a simple
microcontroller address bus) needs exactly this block: turning a flat
address into "which device should respond" and catching addresses that
belong to no device — the latter is what makes an external watchdog or bus
fault visible instead of silently reading garbage from an unselected
device.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `addr` | input | `ADDR_WIDTH` | Address to decode |
| `cs_rom` | output | 1 | 1 when `addr` is in the ROM region |
| `cs_ram` | output | 1 | 1 when `addr` is in the RAM region |
| `cs_periph` | output | 1 | 1 when `addr` is in the PERIPH region |
| `cs_uart` | output | 1 | 1 when `addr` is in the UART region |
| `error` | output | 1 | 1 when `addr` matches none of the above |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `ADDR_WIDTH` | 16 | Width of the address bus |

## 5. Internal Signals

| Signal (`localparam`) | Purpose |
|---|---|
| `ROM_TOP` | Upper bound of the ROM region (lower bound is implicitly 0) |
| `RAM_BASE`, `RAM_TOP` | Bounds of the RAM region |
| `PERIPH_BASE`, `PERIPH_TOP` | Bounds of the PERIPH region |
| `UART_BASE`, `UART_TOP` | Bounds of the UART region |

## 6. Architecture

```
 addr ──┬─[addr <= ROM_TOP]───────────────────────► cs_rom
        ├─[RAM_BASE <= addr <= RAM_TOP]────────────► cs_ram
        ├─[PERIPH_BASE <= addr <= PERIPH_TOP]──────► cs_periph
        ├─[UART_BASE <= addr <= UART_TOP]──────────► cs_uart
        └─[none of the above]──────────────────────► error
```

An `if / else if` priority chain of range comparisons; since the regions
are non-overlapping by construction, the priority order does not change
which region a mapped address resolves to, but it does determine that an
address matching no range falls through to `error`.

## 7. Module Hierarchy and Connections

```
tb_address_decoder
└── dut : address_decoder #(.ADDR_WIDTH(16))
```

The testbench drives `addr` and observes all five outputs directly; there
is no further hierarchy.

## 8. Verilog Concepts Used

* Range comparisons (`>=`, `<=`) on a vector, contrasted with the exact
  bit-pattern matching (`case`/`casez`) used by every other decoder in this
  category.
* `if / else if / else` priority chain in a combinational `always @(*)`
  block, with a default assignment for every output.
* Recognizing and eliminating an always-true comparison
  (`addr >= 16'h0000` on an unsigned bus) instead of writing it and
  suppressing the resulting lint warning.
* A testbench reference `function` shared between directed boundary checks
  and an exhaustive sweep, via a common `check` task.

## 9. Source Code Explanation

```verilog
always @(*) begin
    cs_rom = 1'b0; cs_ram = 1'b0; cs_periph = 1'b0; cs_uart = 1'b0; error = 1'b0;

    if (addr <= ROM_TOP)
        cs_rom = 1'b1;
    else if (addr >= RAM_BASE && addr <= RAM_TOP)
        cs_ram = 1'b1;
    else if (addr >= PERIPH_BASE && addr <= PERIPH_TOP)
        cs_periph = 1'b1;
    else if (addr >= UART_BASE && addr <= UART_TOP)
        cs_uart = 1'b1;
    else
        error = 1'b1;
end
```

* All five outputs are defaulted to 0 before the `if` chain runs, so every
  branch only needs to set the one output it is responsible for — the
  chain is exhaustive (an `else` with no condition) so `error` is only ever
  1 when none of the four region checks matched.
* The ROM check is `addr <= ROM_TOP` with no lower-bound comparison: since
  `addr` is an unsigned vector and ROM starts at address 0, `addr >=
  16'h0000` can never be false, and Verilator's `UNSIGNED` lint check flags
  writing it anyway as a constant-valued comparison. Omitting it produces
  identical behaviour with cleaner, warning-free RTL.
* The remaining three regions need both bounds because their base
  addresses are nonzero.
* Because the four ranges are non-overlapping and contiguous-or-gapped by
  construction (verified exhaustively by the testbench), the `if/else if`
  priority never has to arbitrate between two regions that could both
  match the same address — priority here exists only to reach `error` as
  the catch-all case, not to resolve a genuine conflict.

## 10. Testbench Explanation

`tb_address_decoder` combines directed and exhaustive coverage:

1. **Directed boundary checks**: every region's base and top address is
   checked explicitly, along with the address immediately below/above each
   boundary — exactly where an off-by-one error in a range comparison
   (`<` vs. `<=`) would first become visible. The first unmapped address
   (`0x7100`) and the top of the address space (`0xFFFF`) are also checked.
2. **Exhaustive sweep**: since `ADDR_WIDTH = 16` gives exactly `2^16 =
   65536` possible addresses — at the project's documented exhaustive-space
   limit — every single address is applied via the shared `check` task.

Both phases use the same `check` task and `model` reference function; the
model independently re-derives the expected one-hot-or-error output from
the same range boundaries, written as a standalone `if/else if` chain
rather than reused from the DUT. A mismatch increments `errors` and prints
an `ERROR:` line with the address, expected and actual output vectors.
Console output stays compact: the exhaustive sweep prints nothing per
iteration (only on a mismatch), consistent with the project's testbench
standard for large designs. The final line is `TEST PASSED: 65546 checks`
(10 directed + 65536 exhaustive) or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | ROM boundaries | `0x0000`, `0x1FFF` | `cs_rom=1` |
| 2 | RAM boundaries | `0x2000`, `0x5FFF` | `cs_ram=1` |
| 3 | PERIPH boundaries | `0x6000`, `0x6FFF` | `cs_periph=1` |
| 4 | UART boundaries | `0x7000`, `0x70FF` | `cs_uart=1` |
| 5 | First unmapped address | `0x7100` | `error=1` |
| 6 | Top of address space | `0xFFFF` | `error=1` |
| 7 | Exhaustive sweep | every address `0x0000`–`0xFFFF` | matches the memory map for all 65536 addresses |

100% of the 16-bit address space is exercised, including every region
boundary.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 045` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_address_decoder` — **PASS**

```text
directed boundary checks:
  boundaries checked: 10, errors so far: 0
exhaustive sweep of all 65536 addresses...
done: 65546 checks
TEST PASSED: 65546 checks
tb/tb_address_decoder.v:71: $finish called at 65546000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 74 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Non-overlapping, differently-sized regions require genuine range
  comparisons rather than bit-slicing; Yosys generic synthesis produces
  74 cells for the four range checks plus output muxing/gating, more than
  any bit-slice-based decoder earlier in this category, reflecting the
  extra comparator hardware ranges require over simple equality checks.
* Leaving a gap between UART's top (`0x70FF`) and the end of the address
  space (`0xFFFF`) unmapped, and having `error` catch it, models a real
  system where not all of the address space is populated with real
  devices — accessing the gap should be visibly wrong, not silently
  answered by the wrong device.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Off-by-one boundaries (`addr < RAM_BASE` instead of `addr <= RAM_TOP` for
  the previous region, or vice versa) — exactly what the directed boundary
  tests in section 10 are designed to catch immediately.
* Writing a lower-bound comparison against 0 on an unsigned bus
  (`addr >= 16'h0000`) — always true, and flagged by lint tools as dead
  logic; recognizing and removing this is a real code-review habit, not
  just a style preference.
* Leaving overlapping ranges between two regions, which an `if/else if`
  chain would silently resolve by priority order alone, hiding a genuine
  memory-map bug instead of surfacing it — this design's ranges are
  constructed to be non-overlapping specifically to avoid relying on that
  fallback behaviour.

## 15. Possible Improvements

* Parameterize the region boundaries themselves (currently fixed
  `localparam`s) so the same RTL serves different memory maps.
* Add a registered (pipelined) version for use on a high-frequency bus
  where combinational decode would not meet timing.

## 16. What This Program Teaches

* Range-based address decoding as distinct from the bit-slice/shift-based
  decoding used earlier in this category.
* Recognizing and eliminating an always-true comparison on an unsigned bus
  instead of suppressing the resulting lint warning.
* Combining directed boundary testing (targeting the exact bug-prone
  locations) with full exhaustive coverage in one testbench.

## 17. Industry Relevance

Address decoders exactly like this one sit at the front of every
memory-mapped bus in real SoCs and microcontrollers (see the APB/AHB/AXI
bus-protocol programs later in this curriculum); getting region boundaries
and the unmapped-access error right is a frequent, high-consequence source
of bugs in real hardware bring-up.

## 18. How to Run

```bash
python3 scripts/run.py 045            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/045-address-decoder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/address_decoder.v tb/tb_address_decoder.v
vvp build/sim.vvp +vcd
```
