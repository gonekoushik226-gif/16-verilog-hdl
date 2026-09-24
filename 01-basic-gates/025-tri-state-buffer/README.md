# 025 — Tri-State Buffer and Shared Bus

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · Synthesis: not applicable · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `shared_bus` | `src/tristate_buffer.v`, `src/shared_bus.v` | `tb/tb_shared_bus.v` |

## 1. Objective

Introduce the third logic value used by real buses — high-impedance
(`1'bz`) — through a tri-state buffer, and show what happens electrically
(and in simulation) when two drivers share one wire.

## 2. What the Design Does

`tristate_buffer` drives `y = a` when `enable = 1`, and drives `y` to
high-impedance (`z`) when `enable = 0` — it electrically disconnects
instead of forcing a 0 or 1.

`shared_bus` connects **two** `tristate_buffer` instances to the same net
`bus`. Only one instance should be enabled at a time in a real design:

| `enable_a` | `enable_b` | `bus` |
|---|---|---|
| 0 | 0 | `z` (floating — no driver) |
| 1 | 0 | `data_a` |
| 0 | 1 | `data_b` |
| 1 | 1, `data_a == data_b` | that value (both agree) |
| 1 | 1, `data_a != data_b` | `x` (**contention** — undefined) |

## 3. Why It Is Useful

Shared buses (memory data buses, multi-drop I/O pins, JTAG chains, I²C/SPI
lines) are driven by exactly one active agent at a time, selected by an
enable/chip-select signal, while everyone else tri-states. This is the
oldest way to let many devices share one wire without a full crossbar.

## 4. Interface

**`tristate_buffer`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | Data to drive |
| `enable` | input | 1 | 1 = drive `a` onto `y`, 0 = high-impedance |
| `y` | output | 1 | `a` or `z` |

**`shared_bus`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_a`, `data_b` | input | 1 | Data from agent A / B |
| `enable_a`, `enable_b` | input | 1 | Drive-enable for agent A / B |
| `bus` | output | 1 | The shared net both agents drive |

No parameters.

## 5. Internal Signals

None beyond the shared net `bus` itself, which is a `wire` driven by two
independent primitive outputs (Verilog resolves multiple drivers on a
`wire` using 4-state resolution: 0 vs. 0 → 0, 1 vs. 1 → 1, z vs. anything
→ that thing, 0 vs. 1 → x).

## 6. Architecture

```
 data_a ──►┌──────────────┐
 enable_a─►│ tristate_buf A│──┐
           └──────────────┘  │
                              ├──► bus (shared net)
 data_b ──►┌──────────────┐  │
 enable_b─►│ tristate_buf B│──┘
           └──────────────┘
```

## 7. Module Hierarchy and Connections

```
tb_shared_bus
└── dut : shared_bus
    ├── u_drv_a : tristate_buffer (a=data_a, enable=enable_a, y=bus)
    └── u_drv_b : tristate_buffer (a=data_b, enable=enable_b, y=bus)
```

Both `tristate_buffer` instances connect their `y` port to the same net,
`bus`, which is how the sharing is expressed structurally.

## 8. Verilog Concepts Used

* The high-impedance literal `1'bz`.
* The `bufif1` gate-level primitive (drives its input only while its
  control input is 1, else outputs `z`).
* Multiple structural drivers resolving onto one `wire` (4-state wired
  resolution, no explicit resolution function needed for a plain `wire`).
* Case-equality (`!==`) comparison against `z`/`x` in the testbench.

## 9. Source Code Explanation

```verilog
module tristate_buffer (
    input  wire a,
    input  wire enable,
    output wire y
);
    bufif1 u_tri (y, a, enable);
endmodule
```
`bufif1(out, in, control)` is a 3-terminal primitive: it drives `in` onto
`out` when `control` is 1, and drives `z` when `control` is 0.

```verilog
module shared_bus (
    input  wire data_a, enable_a, data_b, enable_b,
    output wire bus
);
    tristate_buffer u_drv_a (.a(data_a), .enable(enable_a), .y(bus));
    tristate_buffer u_drv_b (.a(data_b), .enable(enable_b), .y(bus));
endmodule
```
Both instances' `y` ports connect to the same `bus` net. Verilog does not
error on this (it is legal and it is exactly how real tri-state buses are
built); the simulator resolves the combined value bit by bit.

## 10. Testbench Explanation

`tb_shared_bus` drives all 16 combinations of `{enable_a, data_a,
enable_b, data_b}` through a `for` loop. For each combination it computes
the expected `bus` value with the same priority table shown in §2 (no
driver → `z`; one driver → that driver's data; both drivers agreeing →
that value; both drivers disagreeing → `x`), waits `#1`, and compares with
`!==`. Every row is printed; a mismatch prints an `ERROR:` line. The run
ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

| # | `enable_a,data_a` | `enable_b,data_b` | Expected `bus` |
|---|---|---|---|
| 1 | 0,x | 0,x | `z` |
| 2 | 1,0 | 0,x | `0` |
| 3 | 1,1 | 0,x | `1` |
| 4 | 0,x | 1,0 | `0` |
| 5 | 0,x | 1,1 | `1` |
| 6 | 1,0 | 1,0 | `0` (agree) |
| 7 | 1,1 | 1,1 | `1` (agree) |
| 8 | 1,0 | 1,1 | `x` (contention) |
| 9 | 1,1 | 1,0 | `x` (contention) |

All 16 combinations of the 4 control/data inputs are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 025` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_shared_bus` — **PASS**

```text
en_a da | en_b db | bus
  0   0  |  0   0  |  z
  0   0  |  0   1  |  z
  0   0  |  1   0  |  0
  0   0  |  1   1  |  1
  0   1  |  0   0  |  z
  0   1  |  0   1  |  z
  0   1  |  1   0  |  0
  0   1  |  1   1  |  1
  1   0  |  0   0  |  0
  1   0  |  0   1  |  0
  1   0  |  1   0  |  0
  1   0  |  1   1  |  x
  1   1  |  0   0  |  1
  1   1  |  0   1  |  1
  1   1  |  1   0  |  x
  1   1  |  1   1  |  1
TEST PASSED: 16 checks
tb/tb_shared_bus.v:54: $finish called at 16000 (1ps)
```

Synthesis: not applicable — intentional multi-driver tri-state bus; Yosys generic synth rejects multi-driver nets with no tri-state cell to map onto
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This program is **simulation-verified only** (`program.conf` sets
  `SYNTH=no`). Yosys's generic `synth` runs `check -assert` on the design
  and treats *any* multi-driver wire as a reported problem, because it has
  no vendor tri-state/IO buffer cell to map the sharing onto — the same
  intentional structure that makes this program teach bus contention makes
  it fail the generic synthesis check. Real tri-state bus sharing must be
  enforced by design discipline (mutually exclusive enables) and is
  synthesized with technology-specific tri-state/IO cells, neither of
  which the generic flow used by this repository models.
* Modern FPGAs generally cannot implement internal tri-state buses at all
  (only at I/O pads); the same function is implemented on-chip with
  multiplexers. This program models the classic ASIC/board-level bus, and
  §15 notes the FPGA-friendly alternative.
* Icarus Verilog's 4-state resolution matches real bus electrical
  behaviour for the 0-vs-1 and single-driver cases; real contention can
  also, depending on drive strengths, produce an in-between voltage rather
  than a clean logic level — the simulator's `x` represents "undefined
  digital value", not necessarily the exact analog outcome.

## 14. Common Mistakes

* Enabling two drivers with the *same* data value and believing it is safe
  — it "works" logically here, but in real silicon it still causes
  crowbar current between the two output stages; only one enable should
  ever be active.
* Forgetting a default disabled state at reset, letting an FPGA/ASIC bus
  glitch to contention during power-up before the first enable decode
  settles.
* Reading `z` on a floating bus as if it were `0` — a `z` bus needs a
  pull-up/pull-down resistor (not modelled here) to have a defined idle
  value.

## 15. Possible Improvements

* Add a third driver to show N-way arbitration and glitch-free enable
  switching (make-before-break vs. break-before-make).
* Show the FPGA-safe replacement: a mux-based "internal tri-state" (select
  one of N data sources with a priority/one-hot select) instead of `z`.

## 16. What This Program Teaches

* The high-impedance value and the `bufif1` primitive.
* How multiple structural drivers on one net resolve in simulation.
* Why shared buses need disciplined, mutually exclusive enables.

## 17. Industry Relevance

Classic parallel buses (ISA, older memory interfaces), JTAG TDO chains,
I²C's open-drain-like sharing, and multi-drop RS-485 all rely on exactly
this discipline — the electrical contention modelled here is a real
failure mode, not just a simulation curiosity.

## 18. How to Run

```bash
python3 scripts/run.py 025
cd 01-basic-gates/025-tri-state-buffer && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/tristate_buffer.v src/shared_bus.v tb/tb_shared_bus.v
vvp build/sim.vvp +vcd
```
