# 035 — Fully Parameterized N-to-1 Multiplexer

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Intermediate | `mux_n` | `src/mux_n.v` | `tb/tb_mux_n.v` |

## 1. Objective

Generalize the fixed-size muxes of 032–034 into a single module whose data
count `N` and element width `WIDTH` are both parameters, using a flattened
bus port and an indexed part-select instead of individually named data
inputs.

## 2. What the Design Does

`mux_n` selects one `WIDTH`-bit element out of `N` elements packed into a
single `N*WIDTH`-bit input bus `data`, using a `$clog2(N)`-bit `sel`:

```
y = element `sel` of data, i.e. data[sel*WIDTH +: WIDTH]
```

Element 0 occupies the least-significant `WIDTH` bits of `data`, element 1
the next `WIDTH` bits, and so on — the same packing convention used
whenever a bus of records is flattened for a port list.

## 3. Why It Is Useful

Verilog-2005 module ports cannot be declared as arrays, so any IP block
that needs an "array of buses" interface (register file read data, memory
bank selection, crossbar inputs) flattens it into one wide bus with this
exact `sel*WIDTH +: WIDTH` indexing convention. Learning to read and write
that convention is necessary before working with any real bus-based design
in this dialect.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `sel` | input | `$clog2(N)` | Index of the element to select (0 .. N-1) |
| `data` | input | `N*WIDTH` | `N` flattened `WIDTH`-bit elements, element `i` at bits `[i*WIDTH +: WIDTH]` |
| `y` | output | `WIDTH` | Selected element |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 8 | Bits per data element |
| `N` | 4 | Number of data elements; must be a power of 2 so every `sel` code is valid |

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
data = { element[N-1] | ... | element[1] | element[0] }
                                    │
                    sel ──► indexed part-select ──► y = element[sel]
```

A single indexed part-select is the entire design; there is no visible mux
tree in the RTL text, but synthesis still produces one (see section 13).

## 7. Module Hierarchy and Connections

```
tb_mux_n
├── dutA : mux_n #(.WIDTH(1), .N(4))   -- exhaustive instance
└── dutB : mux_n #(.WIDTH(8), .N(8))   -- random instance
```

The testbench instantiates `mux_n` twice with different `(WIDTH, N)` pairs,
each driven and checked independently.

## 8. Verilog Concepts Used

* `$clog2` used directly in a **port declaration** width (`[$clog2(N)-1:0]
  sel`), not just inside a `localparam` as in program 011.
* A flattened bus port representing an array of elements.
* The indexed part-select `+:` with a **variable, runtime base**
  (`sel*WIDTH`), as opposed to the constant bases used in program 005.
* Two independently parameterized instances of the same module.

## 9. Source Code Explanation

```verilog
module mux_n #(
    parameter WIDTH = 8,
    parameter N     = 4
) (
    input  wire [$clog2(N)-1:0] sel,
    input  wire [N*WIDTH-1:0]   data,
    output wire [WIDTH-1:0]     y
);
    assign y = data[sel*WIDTH +: WIDTH];
endmodule
```

* `$clog2(N)` computes the number of select bits needed for `N` elements at
  elaboration time, so `sel` is always exactly wide enough (e.g. `N=8` gives
  a 3-bit `sel`) with no manual width arithmetic at the instantiation site.
* `data` is declared `[N*WIDTH-1:0]`: one flat vector holding all `N`
  elements back-to-back.
* `data[sel*WIDTH +: WIDTH]` is an **indexed part-select**: it reads
  `WIDTH` contiguous bits starting at bit `sel*WIDTH`. Unlike a constant
  part-select (`data[7:0]`), the base here is the signal `sel`, so the
  window slides to a different element on every change of `sel` — this is
  the synthesizable equivalent of array indexing for a flattened bus.
* Because `N` is required to be a power of 2, every value `sel` can take
  (`0 .. N-1`) addresses a real element; there is no out-of-range case to
  guard against for the parameter sets used here.

## 10. Testbench Explanation

`tb_mux_n` instantiates two configurations:

1. `dutA` (`N=4, WIDTH=1`): the 6-bit combination `{sel, data}` is swept
   from 0 to 63 (all 64 states). Rather than duplicating the mux's own
   indexing logic as a separate reference model, the check re-reads the
   expected bit with the same `data[selA*WA +: WA]` expression from the
   known stimulus, confirming the DUT's slice matches what was driven.
2. `dutB` (`N=8, WIDTH=8`): 200 iterations each generate 8 independent
   random 8-bit elements, pack them into `dataB` with an explicit loop, and
   keep the unpacked values in a testbench-side array `elemB[]` used as the
   reference model; `sel` is then swept over all 8 elements per iteration
   and `y` is compared against `elemB[sel]`.

Every check increments `checks`; a mismatch increments `errors` and prints
an `ERROR:` line with `sel`, expected and actual values. The final line is
`TEST PASSED: 1664 checks` (64 exhaustive + 1600 random-driven) or a
`TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive, `N=4, WIDTH=1` | `{sel,data}` = 0..63 | `y` = the bit of `data` at position `sel` |
| 2 | Random, `N=8, WIDTH=8` | 200 random 8-element sets x 8 `sel` values | `y` = the 8-bit element at index `sel` |

All 64 states of the `N=4, WIDTH=1` instance (100% of its input space) plus
1600 randomized checks of the `N=8, WIDTH=8` instance are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 035` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_mux_n` — **PASS**

```text
N=4 WIDTH=1 exhaustive (64 combinations):
N=8 WIDTH=8 random (200 data sets x 8 sel values):
done: 1664 checks
TEST PASSED: 1664 checks
tb/tb_mux_n.v:69: $finish called at 1664000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 24 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Even though the RTL contains no explicit `case` or ternary chain, Yosys
  still synthesizes the variable-base part-select into a real N:1 mux per
  output bit (24 cells for `N=8, WIDTH=8` after generic mapping); simulation
  and synthesis agree because indexed part-select is fully synthesizable.
* `N` is documented as required to be a power of 2: with a non-power-of-2
  `N`, `$clog2(N)` still rounds up, leaving `sel` codes above `N-1` that
  would read past the end of `data` (undefined bits). A production version
  would add an explicit `sel < N` guard; this program keeps the two
  concerns (generic width vs. non-power-of-2 bounds checking) separate.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Assuming `+:` behaves like a Python slice with a stop index — its second
  operand is a **width**, not an end index; `data[sel*WIDTH +: WIDTH]` means
  "WIDTH bits starting at sel*WIDTH", not "up to WIDTH".
* Packing elements in the wrong order (`data = {element0, element1, ...}`)
  which reverses which end of the concatenation is bit 0; this design keeps
  element 0 in the least-significant bits, matching `sel = 0` intuitively.
* Using `N` values that are not powers of 2 without adding a bounds check on
  `sel`, silently reading undefined bits for the unused codes.

## 15. Possible Improvements

* Add an explicit `sel < N` bounds guard (via a ternary or `if`) to support
  arbitrary, non-power-of-2 `N` safely.
* Provide a matching `demux_n` (program 037) to show the inverse operation
  on a flattened bus.

## 16. What This Program Teaches

* Using `$clog2` to size a port, not just an internal register.
* Reading and writing a flattened-bus interface with indexed part-select.
* Verifying the same RTL text at two independently chosen `(N, WIDTH)`
  parameter sets in one testbench.

## 17. Industry Relevance

Flattened-bus, indexed-part-select multiplexing is the standard way
register files, memory bank arrays and crossbar switch inputs are exposed
on module ports in Verilog-2005 designs, since true 2D array ports are not
available until SystemVerilog.

## 18. How to Run

```bash
python3 scripts/run.py 035            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/035-parameterized-mux && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/mux_n.v tb/tb_mux_n.v
vvp build/sim.vvp +vcd
```
