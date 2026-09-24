# 127 — Combination Lock

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `combination_lock` | `src/combination_lock.v` | `tb/tb_combination_lock.v` |

## 1. Objective

Build a 4-digit code-entry FSM with a security feature beyond plain
sequence matching: a failure counter that locks the mechanism out for a
fixed period after too many consecutive wrong attempts.

## 2. What the Design Does

`combination_lock` accepts one digit per `enter` pulse. Digits matching
`CODE_0..CODE_3` in order advance through states `S0..S3` and finally to
`S_UNLOCKED`. A wrong digit at any position resets entry to `S0` and
increments a failure counter; on the `MAX_FAILS`-th consecutive failure,
the lock enters `S_LOCKOUT`, ignoring **all** input (even a subsequently
correct code) for `LOCKOUT_TIME` cycles, after which the failure counter
clears and normal entry resumes. A successful unlock also clears the
failure counter. `relock` returns an unlocked mechanism to `S0`.

## 3. Why It Is Useful

Lockout-after-failures is the standard defense against brute-force
guessing on any code-entry mechanism (PIN pads, alarm keypads, device
unlock screens) — this program shows the minimal FSM structure that
implements it correctly, including the easy-to-miss requirement that
lockout must ignore *even correct* input, not just wrong input.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `enter` | input | 1 | pulse: `digit_in` is valid this cycle |
| `digit_in` | input | 4 | the digit being entered |
| `relock` | input | 1 | pulse: return to `S0` from `S_UNLOCKED` |
| `unlocked` | output | 1 | Moore: mechanism unlocked |
| `locked_out` | output | 1 | Moore: in lockout, ignoring input |
| `fail_count_out` | output | 2 | current consecutive-failure count |

Parameters: `CODE_0..CODE_3` (default `3,1,4,1`), `MAX_FAILS` (3, must
fit in `fail_count`'s 2-bit width, i.e. `<= 3`), `LOCKOUT_TIME` (8
cycles).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 3 | `S0..S3`, `S_UNLOCKED`, `S_LOCKOUT` |
| `fail_count` | 2 | consecutive failed attempts since the last success or lockout |
| `lockout_cnt` | `$clog2(LOCKOUT_TIME+1)` | cycles elapsed in `S_LOCKOUT` |

## 6. Architecture

```
S0 --CODE_0--> S1 --CODE_1--> S2 --CODE_2--> S3 --CODE_3--> S_UNLOCKED
 |  \wrong          \wrong         \wrong         \wrong
 |   `-> on_mismatch (fail_count+1; S0, or S_LOCKOUT if fail_count reaches MAX_FAILS)
 `--------------------------------------------------------------'
S_LOCKOUT: counts LOCKOUT_TIME cycles, ignoring `enter`, then -> S0 (fail_count cleared)
S_UNLOCKED: stays unlocked until `relock` -> S0
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A `task automatic` (`on_mismatch`) called from within a combinational
  `always @(*)` block to share identical "wrong digit" handling logic
  across all four code-entry states, with `output` arguments driving the
  same `state_next`/`fail_count_next` regs the surrounding block already
  uses — avoiding four copies of the same lockout-threshold check.
* A failure counter whose value feeds back into next-state logic
  (`fc_next >= MAX_FAILS`), a small but genuine example of a
  counter-driven security policy rather than pure pattern matching.

## 9. Source Code Explanation

```verilog
task automatic on_mismatch(output [2:0] ns, output [1:0] fc_next);
    begin
        fc_next = fail_count + 1'b1;
        if (fc_next >= MAX_FAILS[1:0]) ns = S_LOCKOUT;
        else                            ns = S0;
    end
endtask
```
Called identically from all four `S0..S3` mismatch branches
(`on_mismatch(state_next, fail_count_next)`), this keeps the
lockout-threshold decision in exactly one place — changing `MAX_FAILS`
or the lockout trigger condition only requires editing this one task.

```verilog
S_LOCKOUT: begin
    if (lockout_cnt == LOCKOUT_TIME[CNT_W-1:0] - 1'b1) begin
        state_next       = S0;
        fail_count_next  = 2'd0;
        lockout_cnt_next = {CNT_W{1'b0}};
    end else begin
        lockout_cnt_next = lockout_cnt + 1'b1;
    end
end
```
`S_LOCKOUT` has no dependence on `enter` or `digit_in` at all — this is
what makes lockout unconditional: no sequence of button presses,
correct or not, can escape it before `LOCKOUT_TIME` cycles elapse.

## 10. Testbench Explanation

`tb_combination_lock` drives directed scenarios via `enter_digit` (one
digit per call) and checks `unlocked`/`locked_out`/`fail_count_out`
after each against expected values. Scenarios: (1) a fully correct
4-digit entry; (2) `relock`, then one wrong digit (fail_count=1, not
locked out) followed by a successful entry, confirming recovery works
below the lockout threshold and clears the counter; (3) exactly
`MAX_FAILS` consecutive wrong first-digit entries, confirming lockout
engages, that `fail_count_out` correctly holds `MAX_FAILS` (not 0) while
locked out, that a subsequently presented **fully correct** code is
still ignored during lockout, and that after the lockout period elapses
the lock returns to normal, accepting a correct entry again.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | correct entry | `3,1,4,1` | `unlocked=1` |
| 2 | one wrong digit, then correct | wrong digit, then `3,1,4,1` | recovers, unlocks, `fail_count` clears |
| 3 | lockout | `MAX_FAILS` wrong attempts | `locked_out=1`, `fail_count=MAX_FAILS` |
| 4 | lockout ignores correct code | correct `3,1,4,1` while locked out | still locked out, `unlocked=0` |
| 5 | lockout expiry | wait `LOCKOUT_TIME` cycles | returns to `S0`, `fail_count=0`, accepts entry again |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 127` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_combination_lock` — **PASS**

```text
TEST PASSED: 12 checks
tb/tb_combination_lock.v:121: $finish called at 356000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 105 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `fail_count` is only 2 bits wide, so `MAX_FAILS` must be `<= 3` for
  the `fc_next >= MAX_FAILS` comparison to behave correctly — a genuine
  width constraint worth documenting rather than silently relying on.
* Lockout deliberately does not distinguish "correct code presented
  during lockout" from "wrong code presented during lockout" — both are
  ignored identically, which is the entire point of a lockout (an
  attacker retrying the correct code by chance during lockout must not
  succeed).

## 14. Common Mistakes

* **A testbench-only mistake caught during development:** an early
  version of the lockout test expected `fail_count_out` to read 0 the
  moment lockout engages. In fact `fail_count` legitimately holds
  `MAX_FAILS` for the entire lockout duration (it records that the
  threshold *was* reached) and is only cleared when the lockout timer
  expires. The RTL was correct; the test's expected value was wrong and
  was fixed to check for `MAX_FAILS`, not 0, while locked out.
* Checking `enter` inside the `S_LOCKOUT` case (even just to ignore it
  explicitly) is unnecessary and risks accidentally wiring it back in
  during a later edit — omitting any reference to `enter`/`digit_in` in
  that state's logic is the simplest correct implementation.

## 15. Possible Improvements

* Make `LOCKOUT_TIME` scale with repeated lockouts (progressive
  backoff) instead of a fixed duration.
* Add a `wrong_digit` one-cycle pulse output for driving an external
  buzzer/LED on each failed attempt.

## 16. What This Program Teaches

* Implementing a failure counter that feeds back into FSM next-state
  logic to enforce a security policy.
* Factoring repeated per-state logic into a shared `task automatic`
  called from a combinational block.
* Verifying a *negative* requirement (lockout must reject even correct
  input) as explicitly as a positive one.

## 17. Industry Relevance

Attempt-lockout policies are mandatory in real access-control hardware
(PIN pads, hardware security modules, device unlock mechanisms) —
exactly the failure-counter-plus-timeout structure built here, usually
combined with additional protections (attempt logging, exponential
backoff) this simplified program omits.

## 18. How to Run

```bash
python3 scripts/run.py 127            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/127-combination-lock && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/combination_lock.v tb/tb_combination_lock.v
vvp build/sim.vvp +vcd
```
