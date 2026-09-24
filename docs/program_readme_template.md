# NNN — Program Title

<!-- STATUS:BEGIN -->
(filled in by `python3 scripts/run.py NNN --update-docs`)
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench(es) |
|---|---|---|---|---|
| NN-category | Beginner | `module_name` | `src/a.v`, `src/b.v` | `tb/tb_module_name.v` |

## 1. Objective
One or two sentences: what the reader will be able to do after this program.

## 2. What the Design Does
Functional description of the implemented behaviour (truth table, timing,
protocol) — the actual design, not a generic description of the concept.

## 3. Why It Is Useful
Where this block appears in real systems.

## 4. Interface
| Port | Direction | Width | Description |
|---|---|---|---|

Parameters (if any):
| Parameter | Default | Description |
|---|---|---|

## 5. Internal Signals
| Signal | Width | Purpose |
|---|---|---|
(or "None — the output is a direct function of the inputs.")

## 6. Architecture
Block diagram (ASCII), datapath/control split, state diagram for FSMs,
timing diagram for protocols.

## 7. Module Hierarchy and Connections
Tree of instances and a description of which ports connect to what.

## 8. Verilog Concepts Used
Bullet list of the language constructs and why each is used.

## 9. Source Code Explanation
Line-by-line for small files (quote the code); per-module / per-block
explanation for larger designs.

## 10. Testbench Explanation
Structure of the bench: stimulus, reference model, checking, watchdog.

## 11. Test Cases and Expected Results
| # | Test | Stimulus | Expected result |
|---|---|---|---|

## 12. Actual Simulation Results
<!-- SIM-RESULTS:BEGIN -->
(filled in by `python3 scripts/run.py NNN --update-docs`)
<!-- SIM-RESULTS:END -->

## 13. Design Considerations
Timing, area, reset, synthesis inference, parameter limits.

## 14. Common Mistakes
Concrete mistakes and their symptoms.

## 15. Possible Improvements
Realistic extensions.

## 16. What This Program Teaches
Short list of the skills practised.

## 17. Industry Relevance
Where the idea is used in real products/flows (without overstating the
educational implementation).

## 18. How to Run
```bash
python3 scripts/run.py NNN            # compile, simulate, synthesize, lint
cd NN-category/NNN-program && iverilog -g2005 -o build/sim.vvp src/*.v tb/tb_x.v && vvp build/sim.vvp +vcd
```
