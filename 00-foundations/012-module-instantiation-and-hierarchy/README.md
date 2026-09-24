# 012 — Module Instantiation and Hierarchy

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Elementary | `adder_2bit` | `src/half_adder.v`, `src/full_adder.v`, `src/adder_2bit.v` | `tb/tb_adder_2bit.v` |

## 1. Objective

Build a design from smaller modules, connect instances by name and by
position, and look inside the hierarchy from a testbench.

## 2. What the Design Does

`adder_2bit` adds two 2-bit numbers and a carry-in:
`{cout, sum} = a + b + cin` (0…7). It is built from two `full_adder`
instances; each full adder is built from two `half_adder` instances and an OR
gate.

## 3. Why It Is Useful

All non-trivial hardware is hierarchical. Splitting a design into modules
makes each piece testable on its own, reusable, and readable. The adder is
the smallest meaningful three-level hierarchy.

## 4. Interface

`adder_2bit`:

| Port | Dir | Width | Description |
|---|---|---|---|
| `a`, `b` | in | 2 | Operands |
| `cin` | in | 1 | Carry in |
| `sum` | out | 2 | Sum bits |
| `cout` | out | 1 | Carry out |

`full_adder`: `a, b, cin` → `sum, cout`. `half_adder`: `a, b` → `sum, carry`.

## 5. Internal Signals

| Signal | Module | Purpose |
|---|---|---|
| `carry_mid` | `adder_2bit` | carry from bit 0 to bit 1 |
| `sum_ab`, `carry_ab` | `full_adder` | outputs of the first half adder |
| `carry_c` | `full_adder` | carry of the second half adder |

## 6. Architecture

```
            adder_2bit
   a[0],b[0],cin ─► fa0 ─ sum[0]
                     │ cout = carry_mid
   a[1],b[1] ──────► fa1 ─ sum[1]
                     │ cout ─► cout

            full_adder
   a,b ─► ha_ab ─ sum_ab ─► ha_c ─ sum
            │ carry_ab   cin ─┘ │ carry_c
            └──────► OR ◄───────┘ ─► cout
```

## 7. Module Hierarchy and Connections

```
tb_adder_2bit
└── dut : adder_2bit
    ├── fa0 : full_adder        (named connections)
    │   ├── ha_ab : half_adder
    │   └── ha_c  : half_adder
    └── fa1 : full_adder        (positional connections)
        ├── ha_ab : half_adder
        └── ha_c  : half_adder
```

`fa0.cout` → `carry_mid` → `fa1.cin`. Inside each full adder,
`ha_ab.sum` → `sum_ab` → `ha_c.a`.

## 8. Verilog Concepts Used

* Module instantiation: `module_name instance_name ( connections );`.
* **Named** port connection `.port(signal)` and **positional** connection.
* Connecting single bits of a vector (`a[0]`) to ports.
* Hierarchical names in the testbench: `dut.fa0.ha_ab.sum`.

## 9. Source Code Explanation

`half_adder.v`: `sum = a ^ b; carry = a & b;` — the sum bit and carry of two
bits.

`full_adder.v`:

```verilog
half_adder ha_ab (.a(a), .b(b), .sum(sum_ab), .carry(carry_ab));
half_adder ha_c  (.a(sum_ab), .b(cin), .sum(sum), .carry(carry_c));
assign cout = carry_ab | carry_c;
```
First add `a + b`, then add `cin` to that partial sum. A carry comes either
from `a & b` or from `(a ^ b) & cin`; both cannot be 1 at once, so OR combines
them.

`adder_2bit.v`:

```verilog
full_adder fa0 (.a(a[0]), .b(b[0]), .cin(cin), .sum(sum[0]), .cout(carry_mid));
full_adder fa1 (a[1], b[1], carry_mid, sum[1], cout);
```
`fa0` uses named connections — order-independent and self-documenting.
`fa1` uses positional connections, which must follow the port declaration
order `(a, b, cin, sum, cout)` exactly. If someone later reorders the ports in
`full_adder.v`, `fa1` still compiles but becomes wrong, which is why coding
standards require named connections.

## 10. Testbench Explanation

* All 32 combinations of `{a, b, cin}` are applied.
* `{cout, sum}` is compared with the integer `a + b + cin`.
* The bench also checks two **internal** nets through hierarchical names:
  `dut.carry_mid` must equal "at least two of a[0], b[0], cin", and
  `dut.fa0.ha_ab.sum` must equal `a[0] ^ b[0]`. This verifies the connections
  inside the hierarchy, not only the top-level result.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | 32 input combinations | `{cout,sum} = a+b+cin` |
| 2 | internal carry | `carry_mid = majority(a0,b0,cin)` |
| 3 | internal half-adder sum | `fa0.ha_ab.sum = a0 ^ b0` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 012` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_adder_2bit` — **PASS**

```text
a  b cin | cout sum | carry_mid fa0.ha_ab.sum
00 00  1  |  0   01  |     0         0
00 10  1  |  0   11  |     0         0
01 00  1  |  0   10  |     1         1
01 10  1  |  1   00  |     1         1
10 00  1  |  0   11  |     0         0
10 10  1  |  1   01  |     0         0
11 00  1  |  1   00  |     1         1
11 10  1  |  1   10  |     1         1
TEST PASSED: 64 checks
tb/tb_adder_2bit.v:46: $finish called at 32000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 10 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

Yosys keeps the hierarchy and reports the whole design as 10 cells:
4 XOR + 4 AND (four half adders) + 2 OR (two full adders).

## 13. Design Considerations

* Each instance is a separate copy of the hardware: two full adders = two
  sets of gates.
* Hierarchy is preserved by default in Yosys; flattening lets the optimizer
  merge logic across module boundaries.
* Hierarchical references are for testbenches only; synthesizable RTL must
  communicate through ports.

## 14. Common Mistakes

* Positional connections in the wrong order.
* Forgetting to declare the internal wire (`carry_mid`) — with implicit nets
  it silently becomes a 1-bit wire (fine here, wrong for buses).
* Connecting a vector to a port of a different width — truncation or
  zero-extension with only a warning.
* Two instances with the same instance name.

## 15. Possible Improvements

* Generalise to N bits with `generate` (065).
* Replace the ripple carry with carry-lookahead (069).

## 16. What This Program Teaches

* Instantiation syntax and port connection styles.
* Building designs bottom-up.
* Verifying internal connections through hierarchical references.

## 17. Industry Relevance

SoCs are deep hierarchies of instantiated IP. Named port connections are
mandatory in nearly every company's coding standard, and hierarchical
references are used in testbenches for white-box checks and assertions bound
to internal signals.

## 18. How to Run

```bash
python3 scripts/run.py 012
cd 00-foundations/012-module-instantiation-and-hierarchy && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_adder_2bit.v
vvp build/sim.vvp
```
