# 125 — Vending Machine

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `vending_machine` | `src/vending_machine.v` | `tb/tb_vending_machine.v` |

## 1. Objective

Build a coin-accumulating vending machine controller: a 2-state Moore
FSM (`S_IDLE` / `S_VEND`) wrapped around an 8-bit credit accumulator,
that vends and reports correct change as soon as enough credit has been
inserted.

## 2. What the Design Does

`vending_machine` accepts one-hot, one-cycle coin pulses (`coin_5`,
`coin_10`, `coin_25`) and adds their value to an internal `credit`
register while in `S_IDLE`. The moment `credit` would reach or exceed
`PRICE`, the machine moves to `S_VEND` on the next clock edge, asserting
`vend` for exactly one cycle and reporting `change = credit - PRICE`;
the cycle after that, `credit` resets to 0 and the machine returns to
`S_IDLE`, ready for the next purchase. While in `S_VEND`, any coin
presented is ignored — the machine cannot accept a new coin mid-vend.

## 3. Why It Is Useful

This is the category's first FSM combining state-based control with a
small arithmetic datapath (a running total) rather than a purely
structural state graph — the same pattern (FSM decides *when*, a
register/adder tracks *how much*) reappears in 126's elevator requests,
128's washing-machine phase counters, and the FSMD programs in category
12.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `coin_5`, `coin_10`, `coin_25` | input | 1 each | one-hot, one-cycle coin-insert pulses |
| `vend` | output | 1 | one-cycle pulse: item dispensed |
| `change` | output | 8 | change due, valid the same cycle as `vend` |
| `credit` | output | 8 | current accumulated credit (observability) |

Parameters: `PRICE` (default 45, in the same units as the coin values).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 1 | `S_IDLE` / `S_VEND` |
| `credit_r`, `credit_next` | 8 | accumulated credit |

## 6. Architecture

```
S_IDLE: credit_next = credit_r + (inserted coin value)
        if (credit_next >= PRICE) state_next = S_VEND
S_VEND: credit_next = 0; state_next = S_IDLE   (unconditional, 1 cycle)
```
`vend = (state==S_VEND)`, `change = (state==S_VEND) ? credit_r-PRICE : 0`
(Moore outputs).

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* An FSM whose next-state decision depends on a computed *next* value of
  a datapath register (`credit_next >= PRICE`) rather than only on
  registered state — a one-cycle look-ahead that lets the machine enter
  `S_VEND` on the very edge the qualifying coin is registered, with no
  extra latency cycle.
* A single unconditional-transition state (`S_VEND` always returns to
  `S_IDLE` after exactly one cycle) used deliberately as a short,
  fixed-length "busy" phase during which new inputs are ignored.

## 9. Source Code Explanation

```verilog
if (coin_5)       credit_next = credit_r + 8'd5;
else if (coin_10) credit_next = credit_r + 8'd10;
else if (coin_25) credit_next = credit_r + 8'd25;

if (credit_next >= PRICE[7:0])
    state_next = S_VEND;
```
The coin-value addition and the vend-threshold check both use
`credit_next` — the value credit *will* have after this coin is
registered — so a coin that completes the price triggers `S_VEND` on
the very next edge, not one cycle later. `PRICE` is sliced to `[7:0]` to
match the (possibly narrower) parameter's default 32-bit width without
a synthesis width-mismatch warning.

```verilog
S_VEND: begin
    credit_next = 8'd0;
    state_next  = S_IDLE;
end
```
Any coin pulse presented while `state == S_VEND` is silently ignored —
`credit_next` is forced to 0 unconditionally in this state, regardless
of `coin_5`/`coin_10`/`coin_25`. This is a deliberate, documented design
choice (see §13), not an oversight.

## 10. Testbench Explanation

`tb_vending_machine` maintains an independent `ref_credit` per
transaction and an `insert_coin` task that drives one coin, compares
`vend`/`change`/`credit` against the reference, and — critically —
reports back whether *this* coin triggered a vend via an `output
vended` argument (since `ref_credit` itself is reset to 0 by the task on
a vend, so a caller must never use `ref_credit` alone as a loop
condition). Directed cases: exact payment, overpayment with two coins,
nine small coins reaching the price exactly, mixed-denomination overpay,
and two consecutive purchases with no reset in between. A randomized
case runs 40 full transactions with random coin sequences (fixed seed),
using a `while (!vended)` loop keyed off the `vended` flag.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exact payment | 25+10+10=45 | `vend=1`, `change=0` |
| 2 | overpay, 2 coins | 25+25=50 | `vend=1`, `change=5` |
| 3 | many small coins | 9×5=45 | `vend=1`, `change=0` on the 9th coin |
| 4 | overpay, mixed coins | 25+10+25=60 | `vend=1`, `change=15` |
| 5 | back-to-back purchases | two full transactions, no reset between | both vend correctly |
| 6 | randomized | 40 random coin sequences | matches reference model exactly |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 125` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_vending_machine` — **PASS**

```text
TEST PASSED: 358 checks
tb/tb_vending_machine.v:159: $finish called at 2926000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 140 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Coins are assumed one-hot and one cycle wide — a real coin acceptor
  would need debouncing and pulse-shaping first (see program 154);
  modeling that is out of scope for this FSM-focused program.
* A coin presented during `S_VEND` is discarded, not queued. This was
  discovered as a **real, reproducible testbench bug** during
  development (documented in §14) precisely because a directed test
  case assumed otherwise; the fix confirmed the RTL's behavior was
  correct and the test's assumption was wrong.

## 14. Common Mistakes

* **A genuine bug found while writing this program's testbench:** an
  early version of test Case 4 inserted three 25-cent coins expecting
  overpay to 75 (with `PRICE=45`), but 25+25=50 already exceeds 45 —
  vend fires after the *second* coin, and the third coin lands while the
  machine is in `S_VEND` and is correctly discarded by the RTL. The
  testbench's own reference model didn't account for this, reporting a
  spurious credit mismatch. The fix was to use a mixed-denomination
  sequence (25+10+25=60) whose partial sums never cross `PRICE` early —
  a direct illustration of why a testbench's directed stimulus must be
  checked against the design's *actual* threshold, not just its
  intended final total.
* Assuming `credit` can be read as "total ever inserted" — it is
  reset every time a purchase completes, by design.

## 15. Possible Improvements

* Add a `refund`/cancel input that returns all inserted credit if the
  customer aborts before reaching `PRICE`.
* Support multiple item prices selected by an item-select input.

## 16. What This Program Teaches

* Combining an FSM's next-state decision with a look-ahead datapath
  value (`credit_next`) to avoid an extra reaction cycle.
* That a coin (or any input) arriving during a "busy" FSM state must
  have explicit, deliberate handling — silently discarding it is a valid
  choice, but only when it is a *chosen* one, verified by test.
* How an incorrect testbench assumption about exactly when a threshold
  is crossed can produce a false failure — and how to diagnose it by
  tracing the actual accumulated value against the design's real
  transition condition, not just the test's intended scenario.

## 17. Industry Relevance

Threshold-accumulator FSMs (credit/balance registers gating a state
transition) are everywhere in real payment, metering, and resource-pool
controllers — the same "does the running total cross a limit yet?"
question, with the same busy-state-ignores-new-input consideration this
program's real debugging session uncovered.

## 18. How to Run

```bash
python3 scripts/run.py 125            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/125-vending-machine && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/vending_machine.v tb/tb_vending_machine.v
vvp build/sim.vvp +vcd
```
