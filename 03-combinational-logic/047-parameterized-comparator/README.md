# 047 — Parameterized Signed/Unsigned Comparator

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 03-combinational-logic | Elementary | `comparator_n` | `src/comparator_n.v` | `tb/tb_comparator_n.v` |

## 1. Objective

Generalize the 4-bit comparator into a single width-generic module that can
also be told, at elaboration time, whether its inputs are two's-complement
signed or plain unsigned numbers, and see how much the interpretation
changes the result for the exact same bit pattern.

## 2. What the Design Does

`comparator_n` compares two `WIDTH`-bit buses `a` and `b` with one
relational expression each for `gt`/`lt`, choosing between `$signed()`-cast
and plain (unsigned) comparison based on the `SIGNED` parameter. Exactly one
of `gt`, `lt`, `eq` is 1 for any input pair.

## 3. Why It Is Useful

The same two's-complement bit pattern means a different number depending on
whether the surrounding datapath treats it as signed or unsigned (e.g.
`16'hFFFF` is `65535` unsigned but `-1` signed); a comparator, ALU, or sort
block must be told which interpretation applies. This program isolates that
one decision in a single parameter so its effect can be tested directly.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | `WIDTH` | operands to compare |
| `gt` | output | 1 | 1 when `a > b` under the selected interpretation |
| `lt` | output | 1 | 1 when `a < b` under the selected interpretation |
| `eq` | output | 1 | 1 when `a == b` |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 4 | bus width of `a` and `b` |
| `SIGNED` | 0 | 0 = unsigned compare, 1 = two's-complement signed compare |

## 5. Internal Signals

None — the outputs are a direct function of `a`, `b`, and the elaboration-time
`SIGNED` parameter.

## 6. Architecture

```
              SIGNED == 1 ──► $signed(a) ? $signed(b)  ──┐
a, b ─────────┤                                          ├─► gt / lt / eq
              SIGNED == 0 ──► a ? b (plain, unsigned)  ──┘
```

`SIGNED` is a parameter, not a runtime input, so exactly one branch of the
`if (SIGNED)` is retained per instance — the choice is made once, at
elaboration, not re-decided every cycle.

## 7. Module Hierarchy and Connections

```
tb_comparator_n
├── dutU4  : comparator_n #(.WIDTH(4),  .SIGNED(0))
├── dutS4  : comparator_n #(.WIDTH(4),  .SIGNED(1))
├── dutU16 : comparator_n #(.WIDTH(16), .SIGNED(0))
└── dutS16 : comparator_n #(.WIDTH(16), .SIGNED(1))
```

Four independent instances of the same RTL, differing only by parameter
override, run side by side against the same stimulus.

## 8. Verilog Concepts Used

* `parameter` used to select behaviour (not just width) at elaboration time.
* `$signed()` to reinterpret an unsigned `wire`/`reg` vector as
  two's-complement for the duration of one expression, without declaring
  the port itself `signed`.
* A single relational-operator pair (`>`, `<`) doing the entire comparison,
  contrasted with program 046's explicit bit-cascade approach.
* Multiple parameterized instances of one module compared against
  independently computed signed and unsigned reference models in the same
  testbench.

## 9. Source Code Explanation

```verilog
always @(*) begin
    gt = 1'b0; lt = 1'b0; eq = 1'b0;
    if (SIGNED) begin
        if ($signed(a) > $signed(b))      gt = 1'b1;
        else if ($signed(a) < $signed(b)) lt = 1'b1;
        else                               eq = 1'b1;
    end else begin
        if (a > b)      gt = 1'b1;
        else if (a < b) lt = 1'b1;
        else             eq = 1'b1;
    end
end
```

* All three outputs default to 0, then exactly one branch of the outer
  `if (SIGNED)` sets one of them — `SIGNED` is a `parameter`, so Yosys and
  Verilator both resolve it to a constant at elaboration and synthesize only
  the selected branch, not a runtime mux between two comparators.
* `$signed(a)` does not change how `a` is stored; it only tells the
  relational operator to treat the MSB as a sign bit for this comparison,
  which is why the same wire declaration works for both parameter values.

## 10. Testbench Explanation

`tb_comparator_n` instantiates all four `(WIDTH, SIGNED)` combinations and
drives each pair with:

1. **Exhaustive `WIDTH=4`**: all `16 × 16 = 256` pairs, checked against both
   the unsigned (`dutU4`) and signed (`dutS4`) instances in the same task —
   512 checks total, proving the two interpretations diverge exactly where
   expected (whenever the MSB of `a` or `b` differs between the two
   readings).
2. **Random `WIDTH=16`**: 3000 pairs from `$random(seed)` (default seed `1`,
   overridable with `+seed=<n>` per the project testbench standard),
   checked against both `dutU16` and `dutS16`.
3. **Directed sign-boundary corners**: `0x7FFF` vs `0x8000` (max positive vs
   min negative) and `0x0000` vs `0xFFFF` (`0` vs `-1`) — the exact bit
   patterns where unsigned and signed comparison give opposite answers.

The reference model recomputes both interpretations independently with
`$signed()`/plain relational operators on the same stimulus values, not by
reusing the DUT's own logic.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive 4-bit, unsigned | all 256 pairs | matches `a > b` / `<` / `==` on plain integers |
| 2 | Exhaustive 4-bit, signed | all 256 pairs | matches `$signed(a) > $signed(b)` etc. |
| 3 | Random 16-bit, both | 3000 pairs, seed=1 | both interpretations match their models |
| 4 | Sign-boundary corners | `0x7FFF`/`0x8000`, `0x0000`/`0xFFFF` | unsigned and signed results disagree exactly as expected |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 047` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_comparator_n` — **PASS**

```text
exhaustive WIDTH=4 sweep, unsigned + signed (256 pairs)...
  done: 512 checks, errors so far: 0
random WIDTH=16 sweep, unsigned + signed, seed=1 (3000 pairs)...
  done: 6512 checks total, errors so far: 0
directed WIDTH=16 sign-boundary corners...
  done: 6524 checks total, errors so far: 0
TEST PASSED: 6524 checks
tb/tb_comparator_n.v:105: $finish called at 3262000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 19 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `SIGNED` and `WIDTH` are both ordinary `parameter`s, so each instantiation
  synthesizes as a fixed-interpretation comparator; there is no runtime cost
  for the unused branch since it is elaborated away.
* Because ports are declared as plain (unsigned) `wire`/`reg`, `SIGNED=1`
  relies entirely on `$signed()` at the point of comparison rather than on
  `signed` port declarations — this keeps the module usable as a drop-in
  replacement for the unsigned case without changing any connecting wire's
  declared signedness.
* No reset or clock: purely combinational.

## 14. Common Mistakes

* Declaring the ports `input wire signed [WIDTH-1:0] a` instead of casting
  with `$signed()` locally — both work here, but the local-cast style keeps
  the module's external interface signedness-neutral, which matters once
  this comparator is instantiated inside a larger unsigned-by-default
  datapath.
* Forgetting that `SIGNED` only changes the *comparison*, not the values
  themselves: `16'hFFFF` is still the same 16 bits either way, only whether
  the comparator calls it `65535` or `-1` changes.
* Comparing `a > b` directly when `SIGNED=1` is intended — without
  `$signed()`, Verilog performs an unsigned comparison regardless of the
  parameter, silently producing the wrong answer for negative operands.

## 15. Possible Improvements

* Add a `ge`/`le` output pair derived from `gt`/`eq` and `lt`/`eq`.
* Make `SIGNED` a runtime input instead of a parameter for designs that must
  switch interpretation per-transaction (at the cost of always synthesizing
  both comparison paths).

## 16. What This Program Teaches

* Using a `parameter` to select behaviour, not just structural width.
* The precise effect of `$signed()` on relational operators, and why it
  must be applied explicitly rather than relying on port declarations.
* Building one reference model with two independently-computed
  interpretations of the same stimulus.

## 17. Industry Relevance

Signed/unsigned selectability is a standard feature of real ALUs and DSP
comparators (e.g. RISC-V's `SLT` vs `SLTU` instructions decode to exactly
this kind of signed/unsigned comparator selection); getting the
interpretation right at the boundary between signed and unsigned datapaths
is a common source of real hardware and software bugs.

## 18. How to Run

```bash
python3 scripts/run.py 047            # compile, simulate, synthesize, lint
cd 03-combinational-logic/047-parameterized-comparator && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/comparator_n.v tb/tb_comparator_n.v
vvp build/sim.vvp +vcd +seed=42
```
