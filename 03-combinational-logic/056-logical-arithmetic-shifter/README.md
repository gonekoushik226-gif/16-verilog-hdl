# 056 — Logical/Arithmetic Shifter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | `shifter` | `src/shifter.v` | `tb/tb_shifter.v` |

## 1. Objective

Build a single-stage shifter that switches between left, logical-right, and
arithmetic-right shift under runtime control, using Verilog's native
`<<`, `>>`, and `>>>` operators directly.

## 2. What the Design Does

`shifter` shifts `data` by `shamt` bit positions. `left` selects the
direction (1 = left, 0 = right); `arith` selects, for a right shift only,
whether the vacated high bits are filled with the sign bit (`arith = 1`,
arithmetic shift) or with zeros (`arith = 0`, logical shift). A left shift
always fills vacated low bits with zeros — there is no "arithmetic left
shift" distinction in two's-complement arithmetic.

## 3. Why It Is Useful

Shift operations implement multiplication/division by powers of two,
bit-field extraction and packing, and sign-preserving scaling of signed
values — a shifter with runtime-selectable mode is exactly what a real ALU
needs to support its shift-family instructions (`SLL`, `SRL`, `SRA` in
RISC-V, for example) from one piece of hardware.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `data` | input | `WIDTH` | value to shift |
| `shamt` | input | `$clog2(WIDTH)` | shift amount, `0`–`WIDTH-1` |
| `left` | input | 1 | 1 = shift left, 0 = shift right |
| `arith` | input | 1 | right shift only: 1 = arithmetic (sign-extend), 0 = logical (zero-fill) |
| `result` | output | `WIDTH` | shifted value |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | data width |

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
             left=1 ──────────► result = data << shamt
data,shamt ──┤
             left=0, arith=0 ─► result = data >> shamt          (logical)
             left=0, arith=1 ─► result = $signed(data) >>> shamt (arithmetic)
```

## 7. Module Hierarchy and Connections

```
tb_shifter
└── dut : shifter #(.WIDTH(8))
```

## 8. Verilog Concepts Used

* The three shift operators (`<<`, `>>`, `>>>`) and the semantic
  difference between `>>` (always zero-fills) and `>>>` (sign-extends only
  when applied to a value Verilog treats as `signed`).
* `$signed()` to make `>>>` behave as a true arithmetic shift on an
  otherwise plain (unsigned) `reg`/`wire` — without it, `>>>` on an
  unsigned operand degenerates to the same zero-fill behaviour as `>>`.
* Runtime mode-select inputs (`left`, `arith`) rather than elaboration-time
  parameters, since a real datapath must switch shift mode per operation.

## 9. Source Code Explanation

```verilog
always @(*) begin
    if (left)
        result = data << shamt;
    else if (arith)
        result = $signed(data) >>> shamt;
    else
        result = data >> shamt;
end
```
* `data << shamt` is identical for logical and arithmetic left shift in
  two's complement (both simply shift in zeros at the LSB end), so `arith`
  is only consulted in the `else` (right-shift) branch.
* `$signed(data)` reinterprets `data`'s MSB as a sign bit for the duration
  of the `>>>` operation; Verilog's `>>>` only sign-extends when its left
  operand is a signed expression, which is precisely why the plain
  (unsigned-declared) `data` must be cast here rather than relying on
  `>>>` alone.

## 10. Testbench Explanation

`tb_shifter` covers:

1. **Directed patterns × all shift amounts × all 3 modes**: six hand-picked
   8-bit patterns (all-zero, all-one, MSB-only-set / negative, MSB-clear /
   positive, and two alternating patterns) at every shift amount `0`–`7`
   in every mode — 144 checks that specifically probe the boundary between
   logical and arithmetic right shift (the MSB-set pattern is where the two
   modes diverge).
2. **Random data × all shift amounts × all 3 modes**: 500 random 8-bit
   values from `$random(seed)` (default seed `1`, overridable with
   `+seed=<n>`), each shifted by every amount in every mode — 12000
   additional checks.

The reference model computes `d << sh`, `$signed(d) >>> sh`, or `d >> sh`
directly with plain Verilog operators in the checking task, mirroring the
specification rather than the RTL's particular branch structure.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Directed patterns, left shift | 6 patterns × 8 shift amounts | matches `data << shamt` |
| 2 | Directed patterns, logical right | 6 patterns × 8 shift amounts | matches `data >> shamt` (zero-filled) |
| 3 | Directed patterns, arithmetic right, negative | `10000000` × 8 shift amounts | high bits fill with 1 (sign-extended) |
| 4 | Directed patterns, arithmetic right, positive | `01111111` × 8 shift amounts | high bits fill with 0 (same as logical here) |
| 5 | Random data, all modes | 500 values × 8 amounts × 3 modes, seed=1 | matches reference model |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 056` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_shifter` — **PASS**

```text
directed patterns x all shift amounts x all 3 modes...
  done: 144 checks, errors so far: 0
random data x all shift amounts x all 3 modes, seed=1...
  done: 12144 checks total, errors so far: 0
TEST PASSED: 12144 checks
tb/tb_shifter.v:86: $finish called at 12144000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 75 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This is a single combinational shift stage (`shamt` fully decoded in one
  step), not the multi-stage barrel-shifter structure built in the next
  program — synthesis tools typically still implement it as a barrel
  shifter internally, but the RTL here expresses the *behaviour*, not the
  structure.
* Purely combinational, no reset or clock.
* `shamt` is sized to `$clog2(WIDTH)` bits, so it can only express shift
  amounts up to `WIDTH-1` — a shift amount of exactly `WIDTH` (which would
  logically clear the whole value, or fill it entirely with the sign bit
  arithmetically) is outside this port's representable range by
  construction.

## 14. Common Mistakes

* Using `>>>` on a plain unsigned `reg`/`wire` and expecting sign
  extension — without `$signed()`, `>>>` on an unsigned operand behaves
  exactly like `>>`, a frequent source of silent bugs.
* Believing "arithmetic shift" applies to left shifts too — there is no
  such distinction in two's complement; only right shift needs to choose
  between sign-extension and zero-fill.
* Forgetting that `result` must still be declared `reg` (assigned inside
  `always @(*)`) even though the module has no state — a purely
  combinational function can still need `reg` for the Verilog procedural
  assignment syntax.

## 15. Possible Improvements

* Add a `shamt` wide enough to select a full-width shift (clearing the
  result, or filling entirely with the sign bit) rather than capping at
  `WIDTH-1`.
* Add a funnel-shift mode that also accepts a second word to shift bits in
  from, useful for multi-word shift chains.

## 16. What This Program Teaches

* The precise difference between Verilog's `>>` and `>>>` operators and
  why `$signed()` is required for `>>>` to behave arithmetically.
* Structuring a single module around runtime mode-select inputs instead of
  elaboration-time parameters, appropriate when the mode must change every
  operation.

## 17. Industry Relevance

Every general-purpose ISA's shift instruction family (logical/arithmetic,
left/right) is implemented by exactly this kind of mode-selectable
shifter inside the ALU; understanding the sign-extension subtlety here is
directly relevant to writing correct signed shift RTL in real processor
and DSP datapaths.

## 18. How to Run

```bash
python3 scripts/run.py 056            # compile, simulate, synthesize, lint
cd 03-combinational-logic/056-logical-arithmetic-shifter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/shifter.v tb/tb_shifter.v
vvp build/sim.vvp +vcd +seed=42
```
