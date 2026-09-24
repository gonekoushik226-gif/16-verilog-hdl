# 013 — Generate Constructs

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top modules | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Intermediate | `bin2gray_gen`, `gray2bin_gen`, `configurable_adder` | `src/bin2gray_gen.v`, `src/gray2bin_gen.v`, `src/configurable_adder.v` | `tb/tb_generate_constructs.v` |

## 1. Objective

Use `generate` loops and `generate if` to build width-independent structures
and to choose between implementations at elaboration time.

## 2. What the Design Does

* `bin2gray_gen #(WIDTH)` — binary to Gray code: `gray[i] = bin[i+1] ^ bin[i]`,
  MSB copied.
* `gray2bin_gen #(WIDTH)` — Gray to binary: `bin[i] = bin[i+1] ^ gray[i]`,
  an XOR chain from the MSB downward.
* `configurable_adder #(WIDTH, ARCH)` — `ARCH = 0` builds an explicit
  ripple-carry chain with a generate loop; `ARCH = 1` uses `a + b + cin`.

## 3. Why It Is Useful

Real designs must work for any bus width or number of channels. `generate`
creates the right number of wires, assignments and instances from a
parameter, and `generate if` selects an architecture (for example an FPGA vs
ASIC variant, or a fast vs small implementation) without duplicating modules.

## 4. Interface

| Module | Parameters | Inputs | Outputs |
|---|---|---|---|
| `bin2gray_gen` | `WIDTH=4` | `bin[WIDTH-1:0]` | `gray[WIDTH-1:0]` |
| `gray2bin_gen` | `WIDTH=4` | `gray[WIDTH-1:0]` | `bin[WIDTH-1:0]` |
| `configurable_adder` | `WIDTH=8`, `ARCH=0` | `a`, `b` (`WIDTH`), `cin` | `sum` (`WIDTH`), `cout` |

## 5. Internal Signals

| Signal | Where | Purpose |
|---|---|---|
| `g_ripple.carry[WIDTH:0]` | `configurable_adder`, ARCH=0 only | carry chain; `carry[0]=cin`, `carry[WIDTH]=cout` |

## 6. Architecture

```
bin2gray:  bin[3]──────────────► gray[3]
           bin[3]^bin[2] ──────► gray[2]
           bin[2]^bin[1] ──────► gray[1]      (independent XORs: 1 level)
           bin[1]^bin[0] ──────► gray[0]

gray2bin:  gray[3] ─► bin[3] ─XOR gray[2]─► bin[2] ─XOR gray[1]─► bin[1] ─XOR gray[0]─► bin[0]
                                                           (chain: WIDTH-1 levels)

configurable_adder ARCH=0:  cin ► FA0 ► FA1 ► … ► FA(WIDTH-1) ► cout
```

## 7. Module Hierarchy and Connections

The three modules are independent. The testbench connects them:

```
tb_generate_constructs
├── u_b2g4 : bin2gray_gen #(4) ──gray4──► u_g2b4 : gray2bin_gen #(4)
├── u_b2g8 : bin2gray_gen #(8) ──gray8──► u_g2b8 : gray2bin_gen #(8)
├── u_ripple : configurable_adder #(.WIDTH(8), .ARCH(0))
└── u_behav  : configurable_adder #(.WIDTH(8), .ARCH(1))
```

## 8. Verilog Concepts Used

* `genvar` — elaboration-time loop variable (not a signal).
* `generate … endgenerate` with a `for` loop; each iteration creates
  hardware.
* Named generate blocks (`begin : g_bit`) — required for loops in
  Verilog-2005 good practice, and they create hierarchical scopes such as
  `g_bit[2]`.
* `generate if / else` on a parameter.
* A wire declared inside a generate block (`g_ripple.carry`).

## 9. Source Code Explanation

```verilog
assign gray[WIDTH-1] = bin[WIDTH-1];
genvar i;
generate
    for (i = 0; i < WIDTH - 1; i = i + 1) begin : g_bit
        assign gray[i] = bin[i + 1] ^ bin[i];
    end
endgenerate
```
For `WIDTH = 8` this unrolls into seven `assign` statements. The loop runs
at elaboration, before simulation starts; `i` does not exist in hardware.

```verilog
for (i = WIDTH - 2; i >= 0; i = i - 1) begin : g_bit
    assign bin[i] = bin[i + 1] ^ gray[i];
end
```
A decreasing loop. Each output bit uses the bit above it, so the decoder is a
chain whose delay grows with `WIDTH` — unlike the encoder.

```verilog
generate
    if (ARCH == 0) begin : g_ripple
        wire [WIDTH:0] carry;
        assign carry[0] = cin;
        genvar i;
        for (i = 0; i < WIDTH; i = i + 1) begin : g_stage
            assign sum[i]       = a[i] ^ b[i] ^ carry[i];
            assign carry[i + 1] = (a[i] & b[i]) | (carry[i] & (a[i] ^ b[i]));
        end
        assign cout = carry[WIDTH];
    end else begin : g_behavioral
        assign {cout, sum} = a + b + cin;
    end
endgenerate
```
Only one branch exists in the elaborated design. The ripple branch spells out
the full-adder equations per bit; the behavioural branch leaves the adder
structure to the synthesis tool (which may pick a faster architecture).

## 10. Testbench Explanation

* **Gray converters**: WIDTH 4 (all 16 values, first 8 printed) and WIDTH 8
  (all 256 values). The expected Gray code is `bin ^ (bin >> 1)` and the
  decoder output must restore the original value (round trip).
* **Adders**: all 2^17 combinations of `{cin, a, b}` for both architectures,
  compared with the 9-bit sum `a + b + cin`.
* Prints `u_ripple.g_ripple.carry` through a hierarchical name that passes
  through the generate block, showing how generate scopes appear.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | Gray, WIDTH 4, all values | `gray = bin ^ (bin>>1)`, round trip exact |
| 2 | Gray, WIDTH 8, all values | same |
| 3 | Adders, 131072 combinations | both architectures equal `a+b+cin` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 013` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_generate_constructs` — **PASS**

```text
bin  gray back
0000 0000 0000
0001 0001 0001
0010 0011 0010
0011 0010 0011
0100 0110 0100
0101 0111 0101
0110 0101 0110
0111 0100 0111
Gray converters: WIDTH=4 and WIDTH=8 checked exhaustively
Adders: ripple (generate-for) and behavioral checked for all 131072 input combinations
u_ripple.g_ripple.carry after last vector = 111111111
TEST PASSED: 131344 checks
tb/tb_generate_constructs.v:78: $finish called at 131344000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 46 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

**Lint note:** Verilator reports `UNOPTFLAT` for `gray2bin_gen.bin` and
`g_ripple.carry` because bits of one vector depend on other bits of the same
vector. This is not a combinational loop — it only means Verilator cannot
schedule the vector as one unit. `program.conf` disables that single warning
(`LINT_FLAGS=-Wno-UNOPTFLAT`). Splitting the chain into separate per-bit wires
would also silence it.

## 13. Design Considerations

* Generate loops create structure; ordinary `for` loops inside `always`
  blocks create logic too, but cannot instantiate modules or declare wires
  per iteration.
* The Gray decoder has `WIDTH − 1` XOR levels in series; for wide counters
  this can become a timing path (asynchronous FIFOs use it — see 147).
* Name every generate block: unnamed blocks get tool-generated names
  (`genblk1`) that break hierarchical references and waveform scripts.

## 14. Common Mistakes

* Using an `integer` instead of `genvar` for a generate loop.
* Omitting the block label (`begin : name`).
* Assigning the same bit from two iterations (multiple drivers).
* Off-by-one loop bounds leaving `gray[WIDTH-1]` undriven.
* Expecting `generate if` to switch at run time — it is decided once, at
  elaboration.

## 15. Possible Improvements

* Add a carry-lookahead option (`ARCH = 2`) — see 069/070.
* Generate a parameterized array of module instances (used in 065 and 234).

## 16. What This Program Teaches

* `genvar`, generate-for and generate-if.
* Width-independent structural descriptions.
* Hierarchical names inside generate scopes.

## 17. Industry Relevance

Parameterized IP (FIFOs, crossbars, CRC engines, SIMD lanes) relies on
generate loops. Architecture selection through generate-if is how IP vendors
ship one RTL code base for several technologies.

## 18. How to Run

```bash
python3 scripts/run.py 013
cd 00-foundations/013-generate-constructs && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_generate_constructs.v
vvp build/sim.vvp
```
