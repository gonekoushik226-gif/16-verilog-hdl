# 130 — Four-Phase Handshake

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `hs_link` | `src/hs_sender.v`, `src/hs_receiver.v`, `src/hs_link.v` | `tb/tb_hs_link.v` |

## 1. Objective

Implement the classic four-phase (return-to-zero) `req`/`ack` handshake
as two cooperating FSMs — one on each side of the link — and prove the
protocol invariant holds on every single cycle, not just that data
eventually arrives correctly.

## 2. What the Design Does

`hs_sender` raises `req` once data is ready (phase 1). `hs_receiver`
latches the data and raises `ack` in response (phase 2). `hs_sender`
drops `req` in response to `ack` (phase 3). `hs_receiver` drops `ack` in
response to `req` dropping (phase 4), returning the link to idle. Each
side only ever reacts to the *other* side's signal — never advances on
its own — which is what makes this a true handshake rather than a fixed
timing schedule.

## 3. Why It Is Useful

Four-phase handshaking is the canonical protocol for reliable
point-to-point transfer between two independently-timed FSMs (or, in
its original asynchronous-circuit context, two circuits with no shared
clock at all): each phase is only ever entered in direct response to
the other side's previous phase, so the protocol is inherently
self-paced and cannot outrun either side.

## 4. Interface

**`hs_link`** (top level):

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `data_valid` | input | 1 | pulse: `data_in` is a new word to send |
| `data_in` | input | `WIDTH` | data to send |
| `busy` | output | 1 | sender mid-handshake; do not pulse `data_valid` |
| `data_out` | output | `WIDTH` | most recently received word |
| `data_ready` | output | 1 | one-cycle pulse: `data_out` just updated |

Parameters: `WIDTH` (8).

**`hs_sender`**: adds `ack` (in), `req` (out, held stable across a
transfer). **`hs_receiver`**: adds `req` (in), `ack` (out).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state` (sender) | 2 | `S_IDLE`, `S_REQ_HIGH`, `S_REQ_LOW` |
| `state` (receiver) | 1 | `S_IDLE`, `S_ACK_HIGH` |
| `req`, `ack` | 1 each | the handshake wires connecting the two FSMs |

## 6. Architecture

```
Sender:                          Receiver:
S_IDLE --data_valid--> S_REQ_HIGH   S_IDLE --req--> S_ACK_HIGH
S_REQ_HIGH --ack-------> S_REQ_LOW  S_ACK_HIGH --!req--> S_IDLE
S_REQ_LOW --!ack--------> S_IDLE

(req,ack) over one full transfer: 00 -> 10 -> 11 -> 01 -> 00
            phase:                    1     2     3     4
```

## 7. Module Hierarchy and Connections

```
hs_link
├── hs_sender    (u_tx) -- req, latched data_out -> hs_receiver
└── hs_receiver  (u_rx) -- ack -> hs_sender; data_in <- hs_sender's data_out
```

## 8. Verilog Concepts Used

* Two independently-clocked-but-shared-clock-domain FSMs communicating
  purely through two 1-bit wires (`req`, `ack`) plus a data bus — the
  RTL structure of a handshake protocol distilled to its essentials.
* Each state's transition condition is *the other module's output*, not
  a timer or an internal counter — the defining property of a handshake
  versus this category's earlier timed-phase controllers (123, 128).

## 9. Source Code Explanation

```verilog
// hs_sender.v
S_REQ_HIGH: begin
    req <= 1'b1;
    if (ack) begin
        req   <= 1'b0;
        state <= S_REQ_LOW;
    end
end
```
The sender only drops `req` once it has observed `ack` — it never
assumes the receiver is ready on any fixed schedule.

```verilog
// hs_receiver.v
S_ACK_HIGH: begin
    ack <= 1'b1;
    if (!req) begin
        ack   <= 1'b0;
        state <= S_IDLE;
    end
end
```
Symmetrically, the receiver only drops `ack` once `req` has already
dropped — completing the return-to-zero cycle in the correct order.

## 10. Testbench Explanation

`tb_hs_link` runs two independent checks on the INTEGRATED link. A
**white-box protocol monitor** samples `dut.req`/`dut.ack` (a
hierarchical reference into the design) every cycle and checks every
observed transition against the only two legal successors of each of
the four `(req,ack)` combinations — any other transition is a protocol
violation, checked on every single sampled cycle for the whole test, not
just around expected transfers. A **black-box data-integrity check**
sends 20 words back to back (each `send_word` call waits for `!busy`
before presenting the next one, so sends are correctly paced to the
receiver's actual four-phase completion time) and compares the received
sequence, captured via `data_ready`, against what was sent, in order.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | protocol compliance | every cycle of the whole run | `(req,ack)` only follows `00->10->11->01->00` |
| 2 | ordered transfers | 20 back-to-back words | all 20 received, in order, values match |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 130` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_hs_link` — **PASS**

```text
TEST PASSED: 127 checks
tb/tb_hs_link.v:146: $finish called at 1096000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 35 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Both FSMs run on the *same* clock here — a simplification appropriate
  for this category's FSM focus. A real four-phase handshake's main
  value is at true clock-domain boundaries (see category 15's CDC
  programs), where each side genuinely cannot assume anything about the
  other's timing; the protocol structure built here is identical either
  way.
* `busy` exists specifically so a sender-side client never presents a
  second `data_valid` mid-transfer, which the sender's `S_IDLE`-only
  acceptance of `data_valid` would otherwise simply ignore (not queue).

## 14. Common Mistakes

* Dropping `req` (or `ack`) based on a counter or fixed delay instead of
  the other side's actual signal — this reintroduces exactly the timing
  assumption a handshake protocol exists to avoid.
* Checking only that data arrives correctly, without directly verifying
  the handshake *sequence* itself — a design that happens to transfer
  data correctly by accident (e.g., racing `req` and `ack` on the same
  edge) can still violate the protocol in ways that only a true
  asynchronous implementation would expose; the white-box monitor in
  this testbench checks the sequence explicitly rather than trusting
  data correctness alone.

## 15. Possible Improvements

* Add a genuine two-clock-domain version with proper synchronizers
  (category 15 territory) to show the same protocol solving an actual
  CDC problem.
* Add a `nack`/timeout path for a receiver that cannot accept data.

## 16. What This Program Teaches

* Implementing a real handshake protocol as two reactive (not
  timer-driven) FSMs.
* Verifying a protocol's *sequencing invariant* directly via a
  hierarchical white-box monitor, not just its end-to-end data result.

## 17. Industry Relevance

Four-phase handshaking is the textbook basis for asynchronous circuit
design and appears throughout real bus protocols (as the conceptual
ancestor of `valid`/`ready` handshakes used in AXI-Stream and similar
interfaces, covered later in categories 10/11) wherever two sides must
transfer data without assuming a shared timing schedule.

## 18. How to Run

```bash
python3 scripts/run.py 130            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/130-four-phase-handshake && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_hs_link.v
vvp build/sim.vvp +vcd
```
