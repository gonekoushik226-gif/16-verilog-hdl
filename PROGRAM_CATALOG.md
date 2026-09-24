# Program Catalog

The complete planned curriculum. Each program lives in
`<category>/<NNN>-<name>/` (see `CLAUDE.md` §3). Numbers are stable; new
programs are appended with the next free number. Implementation status is
tracked in `PROJECT_STATUS.md`, not here.

**Difficulty scale:** Beginner → Elementary → Intermediate → Advanced → Expert.

**Structure:** *Single* = one RTL module; *Multi (n)* = n interconnected RTL
modules. Source files are listed under `src/`; the testbench column describes
the planned `tb/tb_*.v` bench(es). Files marked *(tb)* are testbench-side
helper models.

**Why this order:** multiplexers/decoders come before general combinational
blocks and arithmetic because shifters, comparators and the ALU are built
from them. Purely combinational arithmetic stays in `04`; sequential
(multi-cycle) arithmetic such as shift-add multipliers and dividers is in
`12-datapath-and-rtl`, after registers, counters and FSMs have been covered.

---

## 00-foundations

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 001 | `first-module` | Beginner | `module`/`endmodule`, ANSI port list, `` `timescale ``, `assign`, first testbench, `$display`, `$finish` | Single | `first_module.v` | exhaustive 1-bit input, self-check |
| 002 | `wires-and-continuous-assignment` | Beginner | `wire`, vectors, intermediate nets, multiple `assign`, `` `default_nettype none `` | Single | `wire_assign_demo.v` | exhaustive 3-bit input vs expected |
| 003 | `reg-and-procedural-blocks` | Beginner | `reg`, `always @(*)`, `always @(posedge clk)`, `initial` in TB only, procedural vs continuous | Single | `procedural_demo.v` | combinational checks + clocked register checks |
| 004 | `number-literals-and-logic-values` | Beginner | sized/unsized literals, bases, `_` separators, 4-state logic (0/1/x/z), x-propagation, `==` vs `===` | Single | `literal_constants.v` | constant checks, x/z checks with `===` |
| 005 | `vectors-and-bit-selection` | Beginner | bit/part select, indexed part-select `+:`/`-:`, concatenation, replication, byte swap | Single | `bit_manipulator.v` | directed + random vectors vs expected |
| 006 | `bitwise-logical-reduction-operators` | Beginner | `& \| ^ ~`, `&& \|\| !`, reduction `&a \|a ^a` | Single | `operator_unit.v` | exhaustive 4-bit operand pairs |
| 007 | `arithmetic-relational-shift-operators` | Beginner | `+ - * / %`, result width and carry, relational/equality, logical vs arithmetic shift | Single | `arith_ops.v` | exhaustive 4-bit operands vs integer model |
| 008 | `signed-numbers-and-twos-complement` | Elementary | `signed`, `$signed/$unsigned`, sign extension, overflow, mixed-sign pitfalls | Single | `signed_ops.v` | exhaustive 4-bit signed operands |
| 009 | `conditional-statements` | Elementary | `?:`, `if/else`, `case`, `casez`, `default`, priority vs parallel logic | Single | `conditional_demo.v` | exhaustive inputs |
| 010 | `blocking-vs-nonblocking` | Elementary | `=` vs `<=`, event scheduling, shift-register collapse, register swap | Multi (2) | `shift_nonblocking.v`, `shift_blocking.v` | both driven with same stream, compare latency |
| 011 | `parameters-and-localparams` | Elementary | `parameter`, `localparam`, `#()` override, `$clog2`, width-generic code | Multi (2) | `param_counter.v`, `param_top.v` | three widths instantiated and checked |
| 012 | `module-instantiation-and-hierarchy` | Elementary | named vs positional ports, hierarchy, hierarchical references in TB | Multi (3) | `half_adder.v`, `full_adder.v`, `adder_2bit.v` | exhaustive + hierarchical probe of internal nets |
| 013 | `generate-constructs` | Intermediate | `genvar`, generate-for, generate-if, named generate blocks | Multi (3) | `bin2gray_gen.v`, `gray2bin_gen.v`, `configurable_adder.v` | exhaustive for two parameter sets |
| 014 | `functions-and-tasks` | Intermediate | `function` in RTL, `automatic`, `task` in TB for stimulus/checking | Single | `func_demo.v` | task-based stimulus and checks |
| 015 | `simulation-timing-and-delays` | Intermediate | `` `timescale `` units/precision, `#` delays, inertial vs transport delay, `$monitor/$strobe` (non-synthesizable) | Single | `delay_models.v` | timed checks at exact simulation times |
| 016 | `testbench-fundamentals` | Intermediate | clock/reset generation, stimulus/response, self-checking, error counting, VCD on request, watchdog | Single | `saturating_counter.v` | full template bench with reference model |

## 01-basic-gates

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 017 | `and-gate` | Beginner | AND truth table, `assign`, `&` | Single | `and_gate.v` | exhaustive truth table |
| 018 | `or-gate` | Beginner | OR truth table, `\|` | Single | `or_gate.v` | exhaustive truth table |
| 019 | `not-gate` | Beginner | inversion, `~`, x/z behaviour | Single | `not_gate.v` | exhaustive + x/z input |
| 020 | `nand-gate` | Beginner | NAND, De Morgan | Single | `nand_gate.v` | exhaustive truth table |
| 021 | `nor-gate` | Beginner | NOR, De Morgan | Single | `nor_gate.v` | exhaustive truth table |
| 022 | `xor-gate` | Beginner | XOR, parity/difference detection | Single | `xor_gate.v` | exhaustive truth table |
| 023 | `xnor-gate` | Beginner | XNOR, equality detection | Single | `xnor_gate.v` | exhaustive truth table |
| 024 | `buffer-gate` | Beginner | `buf` primitive, multiple-output primitives, why buffers exist | Single | `buffer_gate.v` | exhaustive + x/z |
| 025 | `tri-state-buffer` | Beginner | `1'bz`, `bufif1`, shared bus, contention | Multi (2) | `tristate_buffer.v`, `shared_bus.v` | high-Z, single driver, contention (x) cases |
| 026 | `gate-modeling-styles` | Beginner | gate-level primitives vs dataflow vs behavioral for the same function | Multi (3) | `majority_gate_level.v`, `majority_dataflow.v`, `majority_behavioral.v` | exhaustive, all three compared |
| 027 | `nand-universal-gate` | Elementary | NAND universality: NOT/AND/OR/XOR from NAND only | Multi (6) | `nand2.v`, `nand_not.v`, `nand_and.v`, `nand_or.v`, `nand_xor.v`, `nand_universal_top.v` | exhaustive vs native operators |
| 028 | `nor-universal-gate` | Elementary | NOR universality | Multi (6) | `nor2.v`, `nor_not.v`, `nor_and.v`, `nor_or.v`, `nor_xnor.v`, `nor_universal_top.v` | exhaustive vs native operators |
| 029 | `parameterized-multi-input-gates` | Elementary | reduction operators, `parameter N` | Single | `multi_input_gates.v` | exhaustive for N=3 and N=8 |
| 030 | `boolean-function-implementation` | Elementary | truth table → canonical SOP/POS → K-map minimization, equivalence | Multi (3) | `func_sop.v`, `func_pos.v`, `func_minimized.v` | exhaustive equivalence vs truth table |
| 031 | `gate-delays-and-glitches` | Intermediate | gate delays, static-1 hazard, consensus term (simulation only) | Multi (2) | `hazard_circuit.v`, `hazard_free_circuit.v` | glitch counting on input transition |

## 02-multiplexers-encoders-decoders

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 032 | `mux-2to1` | Beginner | selection, `?:`, `WIDTH` parameter | Single | `mux2to1.v` | exhaustive (1-bit), random (8-bit) |
| 033 | `mux-4to1` | Beginner | hierarchical mux from 2:1 muxes | Multi (2) | `mux2to1.v`, `mux4to1.v` | exhaustive |
| 034 | `mux-8to1-case` | Beginner | `case`-based mux, `default` | Single | `mux8to1.v` | exhaustive select × random data |
| 035 | `parameterized-mux` | Intermediate | N:1 mux, flattened bus ports, `$clog2`, indexed part-select | Single | `mux_n.v` | multiple N/WIDTH instances, random data |
| 036 | `demux-1to4` | Beginner | demultiplexing, one active output | Single | `demux1to4.v` | exhaustive |
| 037 | `demux-parameterized` | Elementary | 1:N demux with loops | Single | `demux_n.v` | all selects, two parameter sets |
| 038 | `decoder-2to4` | Beginner | binary → one-hot, enable | Single | `decoder2to4.v` | exhaustive |
| 039 | `decoder-3to8-cascaded` | Elementary | building bigger decoders from smaller ones | Multi (2) | `decoder2to4.v`, `decoder3to8.v` | exhaustive |
| 040 | `decoder-parameterized` | Elementary | N→2^N decoder, shift-based one-hot | Single | `decoder_n.v` | exhaustive for N=3,4 |
| 041 | `encoder-8to3` | Beginner | one-hot → binary, valid flag, invalid input handling | Single | `encoder8to3.v` | all one-hot + invalid codes |
| 042 | `priority-encoder-4to2` | Beginner | priority, `casez`/if-chain | Single | `priority_encoder4to2.v` | exhaustive |
| 043 | `priority-encoder-parameterized` | Intermediate | N-bit priority encoder with `for` loop, MSB/LSB priority | Single | `priority_encoder_n.v` | exhaustive N=8, random N=16 |
| 044 | `mux-based-logic-implementation` | Elementary | Shannon expansion, implementing functions with muxes | Multi (2) | `mux4to1.v`, `mux_function.v` | exhaustive vs truth table |
| 045 | `address-decoder` | Intermediate | memory-map decoding, chip selects, unmapped-access error | Single | `address_decoder.v` | region boundaries, unmapped addresses |

## 03-combinational-logic

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 046 | `magnitude-comparator` | Elementary | 1-bit comparator cell, cascading into 4-bit (7485-style) | Multi (2) | `comparator1.v`, `comparator4.v` | exhaustive 4-bit pairs |
| 047 | `parameterized-comparator` | Elementary | signed/unsigned comparison, `parameter SIGNED` | Single | `comparator_n.v` | exhaustive 4-bit, random 16-bit, signed/unsigned |
| 048 | `parity-generator-checker` | Beginner | even/odd parity, reduction XOR, error detection | Multi (2) | `parity_generator.v`, `parity_checker.v` | exhaustive + single-bit error injection |
| 049 | `binary-gray-converters` | Elementary | Gray code, XOR chains | Multi (2) | `bin2gray.v`, `gray2bin.v` | exhaustive round-trip, one-bit-change property |
| 050 | `hex-to-seven-segment-decoder` | Beginner | lookup via `case`, active-low segments | Single | `hex_to_7seg.v` | all 16 digits vs table |
| 051 | `binary-to-bcd-double-dabble` | Intermediate | shift-and-add-3 algorithm, loops in combinational logic | Single | `bin2bcd.v` | exhaustive 8-bit |
| 052 | `bcd-to-excess3-converter` | Beginner | code conversion, invalid-code flag | Single | `bcd_to_excess3.v` | all 16 inputs |
| 053 | `one-hot-to-binary-converter` | Elementary | OR-tree encoding, one-hot check | Single | `onehot_to_bin.v` | all one-hot + invalid codes |
| 054 | `leading-zero-counter` | Intermediate | priority scan vs tree structure | Multi (2) | `lzc_loop.v`, `lzc_tree.v` | exhaustive 8-bit, random 32-bit, both compared |
| 055 | `population-count` | Elementary | counting ones, adder tree | Single | `popcount.v` | exhaustive 8-bit, random 32-bit |
| 056 | `logical-arithmetic-shifter` | Elementary | `<<`, `>>`, `>>>`, shift direction/type control | Single | `shifter.v` | all shift amounts, random data |
| 057 | `barrel-shifter` | Intermediate | logarithmic mux stages with `generate` | Single | `barrel_shifter.v` | all amounts × random data vs operator model |
| 058 | `barrel-rotator` | Intermediate | rotate left/right, double-width trick | Single | `barrel_rotator.v` | all amounts × random data |
| 059 | `majority-voter-tmr` | Elementary | triple modular redundancy voting, disagreement flag | Single | `tmr_voter.v` | injected single/double faults |
| 060 | `thermometer-code-converter` | Elementary | thermometer ↔ binary, bubble detection | Multi (2) | `bin2therm.v`, `therm2bin.v` | exhaustive round-trip, bubble codes |
| 061 | `hamming-7-4-codec` | Intermediate | parity-check matrix, syndrome, single-error correction | Multi (2) | `hamming74_encoder.v`, `hamming74_decoder.v` | all data × every single-bit error |

## 04-arithmetic-circuits

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 062 | `half-adder` | Beginner | sum/carry, XOR/AND | Single | `half_adder.v` | exhaustive |
| 063 | `full-adder` | Beginner | full adder from two half adders | Multi (2) | `half_adder.v`, `full_adder.v` | exhaustive |
| 064 | `ripple-carry-adder-4bit` | Beginner | structural chaining of full adders | Multi (2) | `full_adder.v`, `rca4.v` | exhaustive 4-bit + cin |
| 065 | `ripple-carry-adder-parameterized` | Elementary | generate-for adder chain | Multi (2) | `full_adder.v`, `rca_n.v` | exhaustive 4-bit, random 32-bit |
| 066 | `half-subtractor` | Beginner | difference/borrow | Single | `half_subtractor.v` | exhaustive |
| 067 | `full-subtractor` | Beginner | full subtractor from half subtractors | Multi (2) | `half_subtractor.v`, `full_subtractor.v` | exhaustive |
| 068 | `adder-subtractor` | Elementary | two's complement subtraction with XOR + carry-in, carry/overflow/zero/negative flags | Multi (2) | `full_adder.v`, `add_sub.v` | exhaustive 4-bit signed/unsigned |
| 069 | `carry-lookahead-adder-4bit` | Intermediate | generate/propagate, lookahead equations | Single | `cla4.v` | exhaustive |
| 070 | `carry-lookahead-adder-16bit` | Advanced | hierarchical CLA: 4-bit blocks + lookahead unit, group P/G | Multi (4) | `pg_cell.v`, `cla4_block.v`, `lookahead_unit.v`, `cla16.v` | random + corner cases vs `+` |
| 071 | `carry-select-adder` | Intermediate | speculative sums, mux selection by carry | Multi (3) | `full_adder.v`, `rca_n.v`, `csla.v` | random + carry-chain corner cases |
| 072 | `carry-skip-adder` | Intermediate | block propagate, skip mux | Multi (3) | `full_adder.v`, `skip_block.v`, `cska.v` | random + full-propagate cases |
| 073 | `carry-save-adder` | Intermediate | 3:2 compressors, multi-operand addition | Multi (3) | `full_adder.v`, `csa_layer.v`, `three_operand_adder.v` | random three-operand sums |
| 074 | `bcd-adder` | Intermediate | decimal correction (+6), cascading digits | Multi (2) | `bcd_digit_adder.v`, `bcd_adder.v` | exhaustive digit pairs, 4-digit random |
| 075 | `incrementer-decrementer` | Elementary | half-adder chains, wrap-around | Single | `inc_dec.v` | exhaustive 8-bit |
| 076 | `array-multiplier-4x4` | Intermediate | partial products, adder array | Multi (3) | `half_adder.v`, `full_adder.v`, `array_multiplier4.v` | exhaustive |
| 077 | `signed-multiplier-baugh-wooley` | Advanced | two's complement multiplication, Baugh-Wooley partial products | Single | `baugh_wooley_mult.v` | exhaustive 4-bit, random 8-bit |
| 078 | `wallace-tree-multiplier` | Advanced | carry-save reduction tree, final CPA | Multi (3) | `half_adder.v`, `full_adder.v`, `wallace_mult4.v` | exhaustive |
| 079 | `radix4-booth-multiplier` | Advanced | modified Booth recoding, signed partial products | Multi (2) | `booth_encoder.v`, `booth_radix4_mult.v` | exhaustive 6-bit, random 16-bit |
| 080 | `combinational-array-divider` | Advanced | restoring division as a subtract/select array | Multi (2) | `div_cell_row.v`, `array_divider.v` | exhaustive 6-bit, divide-by-zero flag |
| 081 | `alu-4bit` | Elementary | opcode decoding, arithmetic + logic, flags | Single | `alu4.v` | all opcodes × exhaustive operands |
| 082 | `alu-8bit-hierarchical` | Intermediate | hierarchical ALU: arithmetic, logic, shift units, flag logic, result mux | Multi (5) | `alu8.v`, `arith_unit.v`, `logic_unit.v`, `shift_unit.v`, `flag_unit.v` | all opcodes × random + corner operands |
| 083 | `fixed-point-arithmetic` | Intermediate | Q-format, rounding, saturation | Multi (3) | `fxp_add_sat.v`, `fxp_mul.v`, `fxp_unit.v` | random + overflow corners vs real-number model |
| 084 | `floating-point-adder` | Expert | IEEE-754 single: align, add, normalize, round-to-nearest-even (educational subset) | Multi (4) | `fp_unpack.v`, `fp_align.v`, `fp_normalize_round.v`, `fp_adder.v` | directed IEEE cases + random vs `$bitstoreal` model |

## 05-sequential-logic

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 085 | `sr-latch` | Beginner | cross-coupled NOR latch, forbidden state, feedback | Single | `sr_latch.v` | set/reset/hold/forbidden sequence |
| 086 | `d-latch` | Beginner | level-sensitive storage, transparency | Single | `d_latch.v` | transparent vs hold phases |
| 087 | `d-flip-flop` | Beginner | edge-triggered storage, `posedge` | Single | `d_ff.v` | sampling on edges only |
| 088 | `d-flip-flop-reset-variants` | Elementary | sync vs async reset, active-low reset | Multi (3) | `dff_async_reset.v`, `dff_sync_reset.v`, `dff_async_reset_n.v` | reset timing differences checked |
| 089 | `d-flip-flop-with-enable` | Beginner | clock enable, hold | Single | `dff_en.v` | enable/hold sequences |
| 090 | `jk-flip-flop` | Beginner | JK behaviour (hold/set/reset/toggle) | Single | `jk_ff.v` | all JK combinations |
| 091 | `t-flip-flop` | Beginner | toggle, divide-by-2 | Single | `t_ff.v` | toggle sequences |
| 092 | `sr-flip-flop` | Beginner | clocked SR, invalid input handling | Single | `sr_ff.v` | all SR combinations |
| 093 | `master-slave-d-flip-flop` | Elementary | two latches forming an edge-triggered flip-flop | Multi (2) | `d_latch.v`, `ms_dff.v` | compared against behavioural DFF |
| 094 | `flip-flop-conversions` | Elementary | JK/T from D, D from JK: excitation tables | Multi (4) | `d_ff.v`, `jk_from_d.v`, `t_from_d.v`, `d_from_jk.v` | each conversion vs characteristic equation |
| 095 | `edge-detector` | Elementary | rising/falling/any-edge pulse from registered history | Single | `edge_detector.v` | pulse width = 1 cycle, all edge types |
| 096 | `pipeline-registers-intro` | Elementary | register stages, latency, throughput | Multi (2) | `pipe_stage.v`, `pipeline3.v` | latency measurement, data integrity |
| 097 | `clocked-sequential-circuit-analysis` | Intermediate | deriving state equations/table from a gate+DFF circuit | Multi (2) | `d_ff.v`, `seq_circuit.v` | exhaustive state/input table vs derived equations |

## 06-registers-and-counters

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 098 | `n-bit-register` | Beginner | parallel load register, enable, reset | Single | `register_n.v` | load/hold/reset |
| 099 | `shift-register-siso` | Beginner | serial-in serial-out delay | Single | `shift_siso.v` | delayed bit stream |
| 100 | `shift-register-sipo` | Beginner | serial-to-parallel conversion | Single | `shift_sipo.v` | byte assembly, MSB/LSB first |
| 101 | `shift-register-piso` | Beginner | parallel-to-serial, load vs shift | Single | `shift_piso.v` | serialize bytes |
| 102 | `universal-shift-register` | Elementary | hold/shift-left/shift-right/load (74194) | Single | `universal_shift_reg.v` | every mode |
| 103 | `lfsr-random-generator` | Intermediate | Fibonacci vs Galois LFSR, maximal-length polynomial | Multi (2) | `lfsr_fibonacci.v`, `lfsr_galois.v` | period = 2^N−1, no lock-up |
| 104 | `binary-up-counter` | Beginner | increment, wrap-around | Single | `up_counter.v` | full count cycle |
| 105 | `up-down-counter` | Beginner | direction control | Single | `up_down_counter.v` | up/down/wrap |
| 106 | `loadable-counter` | Elementary | load, enable, terminal count | Single | `loadable_counter.v` | load/enable/tc |
| 107 | `modulo-n-counter` | Elementary | parameterized modulus, `$clog2` | Single | `mod_n_counter.v` | several moduli |
| 108 | `bcd-decade-counter` | Elementary | 0–9 counting, carry out | Single | `bcd_counter.v` | full decade + carry |
| 109 | `cascaded-bcd-counter` | Intermediate | cascading counters by enable chaining (000–999) | Multi (2) | `bcd_counter.v`, `bcd_counter_3digit.v` | full 1000-count cycle |
| 110 | `ring-counter` | Elementary | one-hot rotation, self-start | Single | `ring_counter.v` | sequence + recovery |
| 111 | `johnson-counter` | Elementary | twisted ring, 2N states, decoding | Single | `johnson_counter.v` | sequence + decode |
| 112 | `gray-code-counter` | Intermediate | single-bit-change counting | Single | `gray_counter.v` | one-bit-change property, full cycle |
| 113 | `ripple-counter` | Elementary | asynchronous counter, ripple delay (why it is avoided) | Multi (2) | `t_ff.v`, `ripple_counter.v` | count sequence, transient states |
| 114 | `clock-divider-even` | Elementary | divide by 2N, 50% duty | Single | `clock_divider_even.v` | period/duty measurement |
| 115 | `clock-divider-odd` | Intermediate | divide by odd N with 50% duty (both edges) | Single | `clock_divider_odd.v` | period/duty measurement |
| 116 | `tick-generator` | Elementary | clock-enable pulses instead of derived clocks | Single | `tick_generator.v` | pulse spacing and width |
| 117 | `programmable-prescaler` | Intermediate | run-time reload value, terminal pulse | Single | `prescaler.v` | several reload values |

## 07-finite-state-machines

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 118 | `moore-sequence-detector` | Elementary | Moore FSM, overlapping detection of `1011` | Single | `seq_detector_moore.v` | streams with overlaps vs model |
| 119 | `mealy-sequence-detector` | Elementary | Mealy FSM, output timing vs Moore | Single | `seq_detector_mealy.v` | same streams, one-cycle-earlier check |
| 120 | `fsm-state-encoding-styles` | Intermediate | binary vs Gray vs one-hot for one FSM | Multi (3) | `fsm_binary.v`, `fsm_gray.v`, `fsm_onehot.v` | three encodings compared cycle by cycle |
| 121 | `divisible-by-three-fsm` | Elementary | remainder tracking FSM on a serial number | Single | `div_by_3_fsm.v` | random serial numbers vs `%` |
| 122 | `serial-adder-fsm` | Intermediate | Mealy serial adder, carry state | Single | `serial_adder.v` | random operands, bit-serial |
| 123 | `traffic-light-controller` | Elementary | timed Moore FSM | Single | `traffic_light.v` | full cycle timing |
| 124 | `traffic-light-with-pedestrian` | Intermediate | FSM + timer module, request latching | Multi (3) | `timer.v`, `pedestrian_request.v`, `traffic_controller.v` | requests at various phases |
| 125 | `vending-machine` | Intermediate | coin accumulation, vend + change | Single | `vending_machine.v` | coin sequences, change amounts |
| 126 | `elevator-controller` | Advanced | request registers, direction logic, door timing | Multi (3) | `request_register.v`, `door_timer.v`, `elevator_controller.v` | multi-request scenarios |
| 127 | `combination-lock` | Intermediate | code-entry FSM, lockout after failures | Single | `combination_lock.v` | correct/incorrect/lockout |
| 128 | `washing-machine-controller` | Intermediate | phase sequencing with timer, pause/abort | Multi (2) | `phase_timer.v`, `washing_machine.v` | complete cycle, lid-open pause |
| 129 | `parking-lot-counter` | Intermediate | two-sensor direction FSM + occupancy counter | Multi (2) | `car_direction_fsm.v`, `parking_lot.v` | entries, exits, aborted passes, full |
| 130 | `four-phase-handshake` | Intermediate | req/ack protocol FSMs on both sides | Multi (3) | `hs_sender.v`, `hs_receiver.v`, `hs_link.v` | ordered transfers, protocol check |
| 131 | `gcd-fsmd` | Intermediate | FSM + datapath (FSMD), start/done | Multi (3) | `gcd_datapath.v`, `gcd_controller.v`, `gcd_top.v` | random pairs vs Euclid model |
| 132 | `safe-fsm-recovery` | Advanced | illegal-state detection and recovery, one-hot error | Single | `safe_fsm.v` | forced illegal states via hierarchical `force` |
| 133 | `hierarchical-fsm-microwave` | Advanced | nested FSMs, main/sub controller | Multi (3) | `countdown_timer.v`, `door_monitor.v`, `microwave_controller.v` | cooking, door-open pause, cancel |
| 134 | `stepper-motor-controller` | Intermediate | full/half-step sequencing, direction, speed divider | Single | `stepper_controller.v` | phase sequences both directions |

## 08-memory

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 135 | `rom-case` | Beginner | ROM as combinational `case` lookup | Single | `rom_case.v` | every address |
| 136 | `rom-readmemh` | Elementary | memory arrays, `$readmemh` initialization | Single | `rom_init.v` (+ `data/rom.hex`) | every address vs file |
| 137 | `synchronous-rom` | Elementary | registered read (block-ROM inference) | Single | `sync_rom.v` (+ `data/`) | one-cycle read latency |
| 138 | `single-port-ram-async-read` | Elementary | write port, asynchronous read (distributed RAM) | Single | `ram_sp_async.v` | write/read patterns |
| 139 | `single-port-ram-sync-read` | Intermediate | read-first / write-first / no-change modes | Multi (3) | `ram_sp_read_first.v`, `ram_sp_write_first.v`, `ram_sp_no_change.v` | collision behaviour per mode |
| 140 | `byte-enable-ram` | Intermediate | byte-lane write enables | Single | `ram_byte_en.v` | partial writes |
| 141 | `simple-dual-port-ram` | Intermediate | one write + one read port | Single | `ram_sdp.v` | concurrent read/write |
| 142 | `true-dual-port-ram` | Intermediate | two independent R/W ports, collisions | Single | `ram_tdp.v` | both ports, same-address cases |
| 143 | `register-file` | Intermediate | 2-read/1-write register file | Single | `register_file.v` | random ops vs model |
| 144 | `synchronous-fifo-counter` | Intermediate | FIFO with occupancy counter, full/empty | Single | `fifo_sync_counter.v` | fill/drain, overflow/underflow attempts |
| 145 | `synchronous-fifo-parameterized` | Intermediate | extra-MSB pointers, almost-full/empty, count | Single | `fifo_sync.v` | random push/pop vs queue model |
| 146 | `fwft-fifo` | Advanced | first-word-fall-through output stage | Multi (2) | `fifo_sync.v`, `fifo_fwft.v` | zero-latency head, random traffic |
| 147 | `asynchronous-fifo` | Advanced | Gray pointers, 2-FF synchronizers, CDC-safe full/empty | Multi (5) | `async_fifo.v`, `fifo_mem.v`, `wptr_full.v`, `rptr_empty.v`, `sync_2ff.v` | unrelated clocks, random traffic, ordering |
| 148 | `lifo-stack` | Elementary | push/pop pointer, overflow/underflow | Single | `lifo_stack.v` | push/pop sequences vs model |
| 149 | `content-addressable-memory` | Advanced | parallel match, priority match index | Multi (2) | `cam.v`, `priority_encoder_n.v` | write, search hit/miss, multiple hits |
| 150 | `ping-pong-buffer` | Intermediate | double buffering, bank swap | Multi (2) | `ram_sdp.v`, `ping_pong_buffer.v` | continuous write/read of frames |
| 151 | `sram-controller` | Advanced | external asynchronous SRAM timing FSM | Multi (2) | `sram_controller.v` + `async_sram_model.v` (tb) | reads/writes, wait states |
| 152 | `memory-bist-march` | Advanced | March C- algorithm, fault detection | Multi (3) | `ram_sp_async.v`, `mbist_controller.v`, `mbist_top.v` | good memory + injected stuck-at fault |
| 153 | `ecc-memory-secded` | Advanced | Hamming SECDED encode/decode around a RAM | Multi (4) | `secded_encoder.v`, `secded_decoder.v`, `ram_sp_async.v`, `ecc_memory.v` | single/double error injection |

## 09-digital-systems

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 154 | `button-debouncer` | Elementary | synchronizer + stable-time counter | Single | `debouncer.v` | bouncy input model |
| 155 | `pwm-generator` | Elementary | counter compare, duty/period | Single | `pwm_generator.v` | duty measurement 0–100 % |
| 156 | `programmable-timer` | Intermediate | one-shot/auto-reload, interrupt flag | Single | `programmable_timer.v` | modes, reload, irq clear |
| 157 | `watchdog-timer` | Intermediate | kick/timeout, reset pulse, window | Single | `watchdog_timer.v` | kick in time, missed kick |
| 158 | `seven-segment-display-controller` | Intermediate | time-multiplexed digits, refresh | Multi (3) | `hex_to_7seg.v`, `refresh_counter.v`, `seven_seg_controller.v` | digit scan order, segments |
| 159 | `led-pattern-controller` | Elementary | pattern modes, speed control | Multi (2) | `tick_generator.v`, `led_patterns.v` | each pattern sequence |
| 160 | `keypad-scanner` | Intermediate | 4×4 matrix scan, debounce, key code | Multi (2) | `keypad_scanner.v` + `keypad_model.v` (tb) | every key press |
| 161 | `stopwatch` | Intermediate | cascaded BCD counters, start/stop/lap | Multi (3) | `tick_generator.v`, `bcd_counter.v`, `stopwatch.v` | start/stop/reset timing |
| 162 | `digital-clock` | Intermediate | hh:mm:ss, 24-hour wrap, time set | Multi (3) | `tick_generator.v`, `mod_counter.v`, `digital_clock.v` | rollover 23:59:59 → 00:00:00, set |
| 163 | `frequency-counter` | Intermediate | gate time, counting unknown frequency | Multi (2) | `gate_timer.v`, `frequency_counter.v` | several input frequencies |
| 164 | `pulse-width-measurement` | Intermediate | input capture, period and high time | Single | `pulse_capture.v` | known waveforms |
| 165 | `servo-controller` | Elementary | 50 Hz PWM, 1–2 ms pulse from position | Single | `servo_pwm.v` | pulse widths per position |
| 166 | `quadrature-encoder-decoder` | Intermediate | A/B phase decoding, direction, position counter | Single | `quadrature_decoder.v` | CW/CCW sequences, glitches |
| 167 | `ps2-keyboard-receiver` | Intermediate | PS/2 frame, falling-edge sampling, parity | Single | `ps2_receiver.v` + `ps2_device_model.v` (tb) | scan codes, parity error |
| 168 | `lcd-controller-hd44780` | Advanced | init sequence, command/data writes, enable timing | Single | `lcd_controller.v` | captured bus transactions |
| 169 | `vga-sync-generator` | Intermediate | 640×480@60 timing, hsync/vsync, pixel coordinates | Single | `vga_sync.v` | line/frame timing measurement |
| 170 | `tone-generator` | Elementary | frequency division for audio, note table | Single | `tone_generator.v` | period per note |
| 171 | `ultrasonic-sensor-interface` | Intermediate | trigger pulse, echo width measurement, distance | Single | `ultrasonic_ranger.v` + `hcsr04_model.v` (tb) | several distances, timeout |
| 172 | `sigma-delta-dac` | Intermediate | first-order ΔΣ modulation, 1-bit DAC | Single | `sigma_delta_dac.v` | density of ones vs input |
| 173 | `ws2812-led-driver` | Advanced | single-wire timed protocol, GRB bit timing, reset | Single | `ws2812_driver.v` | decoded bits vs sent colors |

## 10-communication

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 174 | `baud-rate-generator` | Elementary | fractional/integer baud ticks, 16× oversampling | Single | `baud_generator.v` | tick spacing for several rates |
| 175 | `uart-transmitter` | Intermediate | 8N1 framing, shift out, busy/ready | Single | `uart_tx.v` | line decoded by TB receiver model |
| 176 | `uart-receiver` | Intermediate | 16× oversampling, mid-bit sampling, framing error | Single | `uart_rx.v` | TB-generated frames, bad stop bit, baud skew |
| 177 | `uart-transceiver-with-fifos` | Advanced | complete UART: baud gen + TX/RX + FIFOs | Multi (5) | `baud_generator.v`, `uart_tx.v`, `uart_rx.v`, `fifo_sync.v`, `uart_top.v` | loopback bursts, FIFO full |
| 178 | `configurable-uart` | Advanced | data bits 5–8, parity none/even/odd, 1/2 stop bits | Multi (3) | `uart_tx_cfg.v`, `uart_rx_cfg.v`, `uart_cfg_top.v` | every configuration, parity error |
| 179 | `spi-master` | Intermediate | CPOL/CPHA modes 0–3, clock divider, chip select | Single | `spi_master.v` + `spi_slave_model.v` (tb) | all four modes, full-duplex data |
| 180 | `spi-slave` | Intermediate | slave-side shift register, sclk synchronization | Multi (2) | `spi_slave.v`, `sync_2ff.v` | TB master in all modes |
| 181 | `i2c-master` | Advanced | START/STOP, address, ACK/NACK, open-drain | Single | `i2c_master.v` + `i2c_slave_model.v` (tb) | write, read, NACK |
| 182 | `i2c-slave` | Advanced | address match, register pointer, clock stretching (none) | Multi (2) | `i2c_slave.v`, `sync_2ff.v` | TB master transactions |
| 183 | `crc-serial-generator` | Intermediate | serial LFSR CRC, polynomial parameter | Single | `crc_serial.v` | CRC-8/CRC-16 known vectors |
| 184 | `crc32-parallel` | Advanced | byte-wide parallel CRC-32 (Ethernet) | Single | `crc32_d8.v` | "123456789" check value, random vs bitwise model |
| 185 | `manchester-codec` | Intermediate | Manchester encoding/decoding, clock recovery | Multi (2) | `manchester_encoder.v`, `manchester_decoder.v` | loopback streams |
| 186 | `nrzi-bit-stuffing` | Intermediate | NRZI, USB-style bit stuffing/unstuffing | Multi (2) | `nrzi_stuff_tx.v`, `nrzi_unstuff_rx.v` | long-ones runs, loopback |
| 187 | `lfsr-scrambler` | Intermediate | self-synchronizing scrambler/descrambler | Multi (2) | `scrambler.v`, `descrambler.v` | loopback, self-sync after error |
| 188 | `one-wire-master` | Advanced | 1-Wire reset/presence, read/write slots | Single | `onewire_master.v` + `onewire_device_model.v` (tb) | presence, write/read bytes |
| 189 | `i2s-transmitter` | Intermediate | audio serial, LRCLK/BCLK, MSB-first | Single | `i2s_tx.v` | TB decodes left/right samples |
| 190 | `packet-framer-deframer` | Advanced | SOF, length, payload, checksum, error detection | Multi (2) | `packet_framer.v`, `packet_deframer.v` | loopback, corrupted packets |
| 191 | `8b10b-encoder-decoder` | Expert | 5b/6b + 3b/4b coding, running disparity, K-codes | Multi (2) | `enc_8b10b.v`, `dec_8b10b.v` | all 256 data + K28.5, disparity |

## 11-bus-protocols

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 192 | `valid-ready-handshake` | Intermediate | valid/ready rules, backpressure | Multi (2) | `stream_source.v`, `stream_sink.v` | random stalls, protocol checks |
| 193 | `register-slice-skid-buffer` | Advanced | fully-registered valid/ready with skid buffer | Single | `skid_buffer.v` | random backpressure, no loss/duplication |
| 194 | `apb-slave-register-bank` | Intermediate | APB3 setup/access, PREADY, PSLVERR | Single | `apb_slave_regs.v` | TB APB master tasks |
| 195 | `apb-master` | Intermediate | APB transaction FSM from a command interface | Multi (2) | `apb_master.v`, `apb_slave_regs.v` | writes/reads with wait states |
| 196 | `apb-interconnect` | Intermediate | address decode, PSEL fan-out, read mux | Multi (3) | `apb_interconnect.v`, `apb_slave_regs.v`, `apb_system.v` | multi-slave access, unmapped error |
| 197 | `ahb-lite-slave-sram` | Advanced | AHB-Lite address/data phases, HREADY, HSIZE | Single | `ahb_sram.v` | single/burst, byte/half/word |
| 198 | `ahb-lite-master` | Advanced | pipelined address/data phase master | Multi (2) | `ahb_master.v`, `ahb_sram.v` | back-to-back transfers |
| 199 | `ahb-to-apb-bridge` | Advanced | protocol conversion, wait insertion | Multi (3) | `ahb_to_apb.v`, `apb_slave_regs.v`, `bridge_system.v` | AHB accesses to APB slaves |
| 200 | `axi4-lite-slave` | Advanced | five channels, independent AW/W, BRESP/RRESP | Single | `axi_lite_slave.v` | AW-before-W, W-before-AW, backpressure |
| 201 | `axi4-lite-master` | Advanced | AXI-Lite master from simple command port | Multi (2) | `axi_lite_master.v`, `axi_lite_slave.v` | random accesses |
| 202 | `axi4-stream-fifo` | Intermediate | AXIS tvalid/tready/tlast, FIFO buffering | Multi (2) | `fifo_sync.v`, `axis_fifo.v` | packets with random stalls |
| 203 | `axi4-stream-width-converter` | Advanced | 32→8 and 8→32 with tkeep/tlast | Multi (2) | `axis_downsizer.v`, `axis_upsizer.v` | round-trip packets |
| 204 | `axi4-burst-memory-slave` | Expert | AXI4 INCR/WRAP bursts, IDs, WSTRB | Single | `axi_burst_ram.v` | bursts of all lengths |
| 205 | `wishbone-slave` | Intermediate | Wishbone B4 classic cycle, ACK/ERR | Single | `wb_slave_regs.v` | single/block cycles |
| 206 | `multi-master-bus-arbiter` | Advanced | shared-bus arbitration, grant hold, fairness | Multi (3) | `rr_arbiter.v`, `bus_mux.v`, `shared_bus.v` | contention, fairness counts |
| 207 | `apb-gpio-peripheral` | Intermediate | memory-mapped GPIO, direction, interrupts | Multi (2) | `apb_gpio.v`, `sync_2ff.v` | register access, edge interrupts |
| 208 | `axi-lite-to-apb-bridge` | Advanced | AXI-Lite slave → APB master conversion | Multi (3) | `axi_lite_to_apb.v`, `apb_slave_regs.v`, `bridge_top.v` | AXI accesses end-to-end |
| 209 | `register-block-field-types` | Advanced | RW/RO/W1C/W1S/RC fields, interrupt status/enable | Single | `reg_block.v` | each field type semantics |

## 12-datapath-and-rtl

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 210 | `parameterized-delay-line` | Elementary | generate-built register chain, depth parameter | Single | `delay_line.v` | latency for several depths |
| 211 | `pipelined-adder` | Intermediate | splitting a carry chain across pipeline stages | Multi (2) | `pipe_add_stage.v`, `pipelined_adder.v` | streaming random operands |
| 212 | `pipelined-multiplier` | Intermediate | pipelined partial-product accumulation, valid pipeline | Single | `pipelined_multiplier.v` | streaming random operands |
| 213 | `shift-add-multiplier` | Intermediate | sequential multiplier FSMD, start/done | Multi (3) | `mult_datapath.v`, `mult_controller.v`, `shift_add_multiplier.v` | exhaustive 6-bit, random 16-bit |
| 214 | `booth-multiplier-sequential` | Advanced | radix-2 Booth, signed sequential | Single | `booth_multiplier.v` | exhaustive 6-bit signed |
| 215 | `restoring-divider` | Intermediate | sequential restoring division | Single | `restoring_divider.v` | exhaustive 8/4-bit, divide by zero |
| 216 | `non-restoring-divider` | Advanced | non-restoring algorithm, remainder correction | Single | `nonrestoring_divider.v` | random + corners |
| 217 | `integer-square-root` | Advanced | digit-by-digit square root | Single | `isqrt.v` | exhaustive 16-bit sampled |
| 218 | `mac-unit` | Intermediate | multiply-accumulate, saturation, clear | Single | `mac_unit.v` | dot products vs model |
| 219 | `fir-filter` | Advanced | direct-form FIR, coefficient array, impulse/step response | Multi (2) | `fir_tap.v`, `fir_filter.v` | impulse, step, random vs model |
| 220 | `moving-average-filter` | Intermediate | running sum with circular buffer | Single | `moving_average.v` | known sequences |
| 221 | `cic-decimator` | Advanced | integrator/comb stages, decimation | Multi (3) | `cic_integrator.v`, `cic_comb.v`, `cic_decimator.v` | DC gain, step response |
| 222 | `cordic-sin-cos` | Advanced | iterative CORDIC rotation, arctan table | Single | `cordic.v` | angles vs `$sin/$cos` tolerance |
| 223 | `dds-nco` | Intermediate | phase accumulator, sine LUT | Multi (2) | `phase_accumulator.v`, `dds.v` (+ `data/sine.hex`) | output frequency and samples |
| 224 | `fixed-priority-arbiter` | Elementary | request/grant, priority chain | Single | `fixed_priority_arbiter.v` | exhaustive requests |
| 225 | `round-robin-arbiter` | Intermediate | rotating priority, fairness | Single | `round_robin_arbiter.v` | fairness counts, starvation check |
| 226 | `two-flop-synchronizer` | Intermediate | metastability, MTBF, why multi-bit buses are unsafe | Multi (2) | `sync_2ff.v`, `sync_bus_unsafe.v` | cross-clock sampling |
| 227 | `pulse-synchronizer` | Intermediate | toggle-based pulse CDC | Single | `pulse_sync.v` | pulses between unrelated clocks |
| 228 | `handshake-cdc-synchronizer` | Advanced | multi-bit CDC with req/ack | Multi (2) | `sync_2ff.v`, `cdc_handshake.v` | data integrity across clocks |
| 229 | `reset-synchronizer` | Intermediate | async assert, sync deassert | Single | `reset_sync.v` | deassertion alignment |
| 230 | `clock-gating-cell` | Intermediate | latch-based ICG vs clock enable, glitch-free gating | Multi (2) | `clock_gate.v`, `gated_register.v` | gated clock glitch check |
| 231 | `credit-flow-control` | Advanced | credit counter, receiver buffer, no-overflow guarantee | Multi (3) | `credit_sender.v`, `credit_receiver.v`, `credit_link.v` | random drain rates |
| 232 | `bitonic-sorting-network` | Advanced | compare-exchange network with generate | Multi (2) | `compare_exchange.v`, `bitonic_sort8.v` | random sets vs sort |
| 233 | `histogram-engine` | Advanced | read-modify-write RAM hazard handling | Multi (2) | `ram_sdp.v`, `histogram.v` | streams with repeats vs model |
| 234 | `systolic-matrix-multiplier` | Expert | processing elements, skewed data flow | Multi (2) | `systolic_pe.v`, `systolic_array.v` | random matrices vs model |
| 235 | `run-length-encoder` | Intermediate | streaming compression, run counter | Multi (2) | `rle_encoder.v`, `rle_decoder.v` | round-trip streams |

## 13-processor-components

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 236 | `program-counter` | Elementary | PC increment, branch/jump target, stall | Single | `program_counter.v` | sequencing, stall, redirect |
| 237 | `instruction-memory` | Elementary | word-addressed ROM from byte address | Single | `instruction_memory.v` (+ `data/`) | fetch every word |
| 238 | `data-memory` | Intermediate | byte/half/word access, sign extension | Single | `data_memory.v` | every size/alignment |
| 239 | `risc-register-file` | Intermediate | 32×32, x0 hard-wired, write-through bypass | Single | `regfile.v` | random ops vs model, x0 |
| 240 | `risc-v-alu` | Intermediate | RV32I ALU ops, SLT/SLTU, shifts | Multi (3) | `adder_sub.v`, `shifter32.v`, `rv_alu.v` | all ops random + corners |
| 241 | `alu-control` | Elementary | funct3/funct7 → ALU operation | Single | `alu_control.v` | every RV32I encoding |
| 242 | `immediate-generator` | Elementary | I/S/B/U/J immediate formats | Single | `imm_gen.v` | encoded instructions vs expected |
| 243 | `instruction-decoder` | Intermediate | field extraction, instruction class | Single | `instr_decoder.v` | every opcode |
| 244 | `main-control-unit` | Intermediate | single-cycle control signals | Single | `control_unit.v` | every instruction type |
| 245 | `branch-unit` | Elementary | BEQ/BNE/BLT/BGE/BLTU/BGEU | Single | `branch_unit.v` | random operands all conditions |
| 246 | `load-store-unit` | Intermediate | alignment, byte enables, misalignment exception | Single | `load_store_unit.v` | all sizes/offsets |
| 247 | `pipeline-register-stage` | Intermediate | stall/flush/bubble insertion | Single | `pipe_reg.v` | stall, flush priority |
| 248 | `hazard-detection-unit` | Intermediate | load-use detection, stall generation | Single | `hazard_unit.v` | instruction pairs |
| 249 | `forwarding-unit` | Intermediate | EX/MEM and MEM/WB forwarding | Single | `forwarding_unit.v` | dependency scenarios |
| 250 | `branch-predictor-bht` | Advanced | 2-bit saturating counters, indexed BHT | Single | `bht_predictor.v` | loop pattern accuracy |
| 251 | `branch-target-buffer` | Advanced | tagged BTB, hit/miss, update | Single | `btb.v` | insert/lookup/replace |
| 252 | `interrupt-controller` | Intermediate | pending/enable/priority, claim/complete | Single | `interrupt_controller.v` | simultaneous IRQs, masking |
| 253 | `csr-unit` | Advanced | machine-mode CSRs, CSRRW/S/C, trap entry | Single | `csr_unit.v` | CSR ops, trap/mret |

## 14-processors

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 254 | `accumulator-cpu-8bit` | Advanced | fetch/decode/execute, accumulator ISA, multi-cycle control | Multi (5) | `acc_alu.v`, `acc_control.v`, `acc_datapath.v`, `acc_memory.v`, `acc_cpu.v` | programs (sum, loop) with final-state checks |
| 255 | `cpu-8bit-with-stack` | Advanced | CALL/RET, stack pointer, flags, conditional branches | Multi (6) | `cpu8_alu.v`, `cpu8_regs.v`, `cpu8_control.v`, `cpu8_datapath.v`, `cpu8_memory.v`, `cpu8.v` | recursive/subroutine programs |
| 256 | `risc16-single-cycle` | Advanced | 16-bit RISC ISA, single-cycle datapath | Multi (7) | `r16_pc.v`, `r16_imem.v`, `r16_regfile.v`, `r16_alu.v`, `r16_control.v`, `r16_dmem.v`, `r16_cpu.v` | assembled programs, register/memory checks |
| 257 | `risc16-multi-cycle` | Advanced | multi-cycle control FSM, shared memory | Multi (6) | `r16m_regfile.v`, `r16m_alu.v`, `r16m_control.v`, `r16m_datapath.v`, `r16m_memory.v`, `r16m_cpu.v` | same programs, cycle counts |
| 258 | `rv32i-single-cycle` | Expert | RV32I base ISA (no FENCE/ECALL), single cycle | Multi (9+) | uses 13-series components + `rv32i_single_cycle.v` | instruction tests + programs |
| 259 | `rv32i-multi-cycle` | Expert | multi-cycle RV32I with unified memory | Multi (8+) | control FSM + datapath files | same tests, CPI measurement |
| 260 | `rv32i-pipelined` | Expert | 5-stage pipeline, forwarding, load-use stall, flush | Multi (10+) | stage files `if_stage.v` … `wb_stage.v` + units | hazard-focused tests + programs |
| 261 | `rv32i-pipelined-branch-prediction` | Expert | BHT/BTB in fetch, misprediction recovery | Multi (12+) | 260 + predictor | branch-heavy programs, accuracy |
| 262 | `stack-machine-cpu` | Advanced | zero-address ISA, data/return stacks | Multi (4) | `stack_unit.v`, `sm_alu.v`, `sm_control.v`, `stack_cpu.v` | expression evaluation programs |
| 263 | `rv32i-with-interrupts` | Expert | traps, CSRs, external interrupt, MRET | Multi (10+) | 258 + `csr_unit.v` + `interrupt_controller.v` | interrupt service programs |
| 264 | `rv32im-with-muldiv` | Expert | M extension with multi-cycle mul/div unit, stall | Multi (10+) | 258/260 + `muldiv_unit.v` | M-extension tests incl. div-by-zero rules |

## 15-advanced-rtl

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 265 | `direct-mapped-cache` | Advanced | tag/index/offset, valid bits, write-through, refill FSM | Multi (4) | `cache_tag_array.v`, `cache_data_array.v`, `cache_controller.v`, `dm_cache.v` + `main_memory_model.v` (tb) | hit/miss/refill sequences |
| 266 | `set-associative-cache` | Expert | 2-way, LRU, write-back, dirty eviction | Multi (5) | `lru_unit.v`, arrays, `sa_cache_controller.v`, `sa_cache.v` | eviction, write-back, random vs memory model |
| 267 | `dma-controller` | Advanced | register-programmed memory-to-memory copy, bus master | Multi (3) | `dma_regs.v`, `dma_engine.v`, `dma_controller.v` + memory model (tb) | copies, done interrupt |
| 268 | `multi-channel-dma` | Expert | channel arbitration, descriptors | Multi (4) | `dma_channel.v`, `rr_arbiter.v`, `dma_mux.v`, `multi_dma.v` | concurrent channels |
| 269 | `sdram-controller` | Expert | init, refresh, activate/read/write/precharge timing | Multi (3) | `sdram_init.v`, `sdram_cmd_fsm.v`, `sdram_controller.v` + `sdram_model.v` (tb) | reads/writes across banks, refresh |
| 270 | `bus-matrix-2x2` | Advanced | per-slave arbitration, concurrent paths | Multi (3) | `rr_arbiter.v`, `matrix_slave_port.v`, `bus_matrix.v` | concurrent/conflicting accesses |
| 271 | `packet-parser` | Advanced | header field extraction on a stream | Single | `packet_parser.v` | several packet types |
| 272 | `packet-fifo-with-drop` | Advanced | store-and-forward, commit/rollback of bad packets | Multi (2) | `ram_sdp.v`, `packet_fifo.v` | good/bad packets, full |
| 273 | `crossbar-switch` | Expert | N×N switching, output arbitration, head-of-line | Multi (3) | `rr_arbiter.v`, `xbar_output.v`, `crossbar.v` | random traffic, ordering per flow |
| 274 | `ternary-cam` | Advanced | value/mask matching, longest-prefix priority | Multi (2) | `tcam.v`, `priority_encoder_n.v` | prefix lookups |
| 275 | `performance-counters` | Intermediate | event counters, snapshot, overflow interrupt | Single | `perf_counters.v` | event streams |
| 276 | `token-bucket-shaper` | Advanced | rate limiting, burst size | Single | `token_bucket.v` | conformance vs model |
| 277 | `multi-port-memory-arbiter` | Advanced | N clients to one SRAM, fairness, latency | Multi (3) | `rr_arbiter.v`, `ram_sp_sync.v`, `mem_arbiter.v` | concurrent clients vs model |
| 278 | `cdc-apb-bridge` | Expert | APB access across clock domains with handshake CDC | Multi (4) | `sync_2ff.v`, `cdc_handshake.v`, `apb_slave_regs.v`, `apb_cdc_bridge.v` | unrelated clocks, data integrity |

## 16-verification

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 279 | `reference-model-testbench` | Intermediate | behavioural golden model vs DUT | Single DUT | `alu8.v` (DUT) + `alu_ref_model.v` (tb) | lock-step comparison |
| 280 | `file-driven-testbench` | Intermediate | `$readmemh`, `$fopen/$fscanf/$fwrite`, vector files | Single DUT | DUT + `data/vectors.txt` | vectors from file, results file |
| 281 | `bus-functional-model` | Intermediate | task-based APB BFM, reusable driver | Single DUT | `apb_slave_regs.v` + `apb_bfm.v` (tb) | BFM-driven register tests |
| 282 | `random-testing-with-seeds` | Intermediate | `$random(seed)`, `$urandom_range`-style helpers, reproducibility | Single DUT | FIFO DUT | seeded random, `+seed=` |
| 283 | `constrained-random-stimulus` | Advanced | weighted/constrained randomization in Verilog | Single DUT | ALU/FIFO DUT | distributions, corner weighting |
| 284 | `scoreboard-checking` | Advanced | expected-queue scoreboard, out-of-order detection | Multi | DUT + `scoreboard.v` (tb) | stream DUT with stalls |
| 285 | `assertion-monitors` | Advanced | protocol checker modules in Verilog | Multi | DUT + `valid_ready_checker.v` (tb) | good run + deliberately broken DUT |
| 286 | `functional-coverage` | Advanced | coverage counters, bins, report | Multi | DUT + `coverage_collector.v` (tb) | coverage closure report |
| 287 | `layered-testbench` | Advanced | generator/driver/monitor/checker separation | Multi | DUT + driver/monitor/checker (tb) | full layered environment |
| 288 | `error-injection-testing` | Advanced | fault injection with `force/release`, negative tests | Multi | ECC/UART DUT | detection of injected faults |
| 289 | `regression-seed-sweep` | Intermediate | plusargs, seed sweeps, pass/fail summaries | Single DUT | DUT + script | multiple seeds via `SIM_ARGS` |
| 290 | `waveform-debugging` | Elementary | `$dumpfile/$dumpvars` scoping, debugging a planted bug | Single DUT | DUT (fixed) + notes | VCD generated on request |
| 291 | `systemverilog-immediate-assertions` | Intermediate | `assert`/`else` with Icarus `-g2012` | Single DUT | DUT | assertions pass; demo of failing assertion |
| 292 | `exhaustive-equivalence-checking` | Intermediate | two implementations compared over full input space | Multi | two adders/multipliers | exhaustive equivalence |

## 17-fpga-oriented-designs

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 293 | `led-blinker` | Beginner | board clock, counter-based blink, top-level wrapper | Single | `led_blinker.v` | toggle period (scaled parameters) |
| 294 | `debounced-counter-display` | Intermediate | button → debouncer → counter → 7-seg | Multi (4) | `debouncer.v`, `edge_detector.v`, `bcd_counter.v`, `counter_display_top.v` | bouncy presses, display value |
| 295 | `breathing-led` | Elementary | PWM with ramping duty | Multi (2) | `pwm_generator.v`, `breathing_led.v` | duty ramp up/down |
| 296 | `uart-echo` | Intermediate | UART RX → TX echo on a board | Multi (4) | `baud_generator.v`, `uart_rx.v`, `uart_tx.v`, `uart_echo_top.v` | bytes echoed |
| 297 | `uart-led-control` | Intermediate | command bytes set LEDs/registers | Multi (4) | UART files + `cmd_decoder.v` + top | command sequences |
| 298 | `vga-test-pattern` | Intermediate | colour bars from pixel coordinates | Multi (2) | `vga_sync.v`, `vga_pattern_top.v` | pixel colours at coordinates |
| 299 | `vga-bouncing-box` | Intermediate | per-frame object update, collision | Multi (3) | `vga_sync.v`, `box_mover.v`, `vga_box_top.v` | positions per frame |
| 300 | `vga-pong` | Advanced | game state, paddles, ball physics, score | Multi (5) | `vga_sync.v`, `paddle.v`, `ball.v`, `score.v`, `pong_top.v` | scripted game frames |
| 301 | `keypad-display` | Intermediate | keypad scan → 7-seg shift display | Multi (4) | `keypad_scanner.v`, `hex_to_7seg.v`, `seven_seg_controller.v`, `keypad_display_top.v` | key sequence on display |
| 302 | `stopwatch-display` | Intermediate | stopwatch integrated with display and buttons | Multi (5) | stopwatch + display files + top | start/stop/lap with buttons |
| 303 | `frequency-meter-display` | Intermediate | frequency counter to BCD display | Multi (4) | counter + `bin2bcd.v` + display + top | known frequencies displayed |
| 304 | `bram-inference-templates` | Intermediate | coding templates that infer block RAM | Multi (3) | `bram_sdp.v`, `bram_tdp.v`, `bram_rom.v` | functional checks; Yosys memory stats |
| 305 | `dsp-inference-mac` | Intermediate | DSP-slice-friendly MAC coding (pre-adder, pipeline) | Single | `dsp_mac.v` | pipelined MAC results |
| 306 | `power-on-reset` | Elementary | POR counter, reset stretching, synchronized release | Single | `power_on_reset.v` | reset length, release alignment |
| 307 | `spi-adc-interface` | Intermediate | MCP3008-style ADC read sequence | Multi (2) | `spi_master.v`, `adc_reader.v` + `adc_model.v` (tb) | channels/values |
| 308 | `i2c-temperature-sensor` | Advanced | LM75-style register read over I²C, periodic polling | Multi (2) | `i2c_master.v`, `temp_sensor_reader.v` + sensor model (tb) | temperatures read |

## 18-industry-entry-projects

| No. | Program | Difficulty | Concepts taught | Structure | Source files | Testbench |
|---|---|---|---|---|---|---|
| 309 | `uart-apb-debug-bridge` | Expert | UART command protocol → APB master → register file | Multi (8+) | UART, command parser, APB master, slaves, top | scripted console sessions |
| 310 | `apb-peripheral-subsystem` | Expert | APB interconnect with UART, GPIO, timer, interrupt controller | Multi (10+) | peripherals + interconnect + top | register-level system test |
| 311 | `rv32i-microcontroller-soc` | Expert | CPU core + ROM + RAM + UART + GPIO + timer on a bus | Multi (15+) | `soc_top.v` + subsystems | firmware prints over UART |
| 312 | `axi-lite-dma-engine` | Expert | AXI-Lite register interface + DMA with FIFOs | Multi (8+) | regs, engine, FIFOs, top + AXI memory model (tb) | descriptor-driven transfers |
| 313 | `image-processing-pipeline` | Expert | RGB→gray, 3×3 Sobel, line buffers, streaming | Multi (6+) | `line_buffer.v`, `window3x3.v`, `rgb2gray.v`, `sobel.v`, `img_pipeline.v` | image file in/out vs model |
| 314 | `fir-dsp-subsystem` | Expert | AXI-Stream FIR with coefficient registers and decimation | Multi (6+) | FIR, regs, AXIS wrappers, top | tone filtering vs model |
| 315 | `aes128-encryption-core` | Expert | AES rounds, key expansion, iterative datapath | Multi (6+) | `aes_sbox.v`, `aes_round.v`, `aes_key_expand.v`, `aes_core.v` | FIPS-197 vectors |
| 316 | `sha256-hash-core` | Expert | message schedule, compression rounds | Multi (4+) | `sha256_w.v`, `sha256_round.v`, `sha256_core.v` | FIPS 180-4 vectors |
| 317 | `ethernet-mac-lite` | Expert | preamble/SFD, CRC append/check, MII nibble interface | Multi (6+) | TX/RX MAC, CRC, FIFOs, top | loopback frames, bad CRC |
| 318 | `spi-flash-controller` | Expert | read command sequencing, memory-mapped flash window | Multi (4+) | SPI engine, command FSM, bus interface + flash model (tb) | reads at many addresses |
| 319 | `pwm-motor-controller-subsystem` | Expert | multi-channel PWM, dead time, APB registers, fault input | Multi (5+) | PWM channels, dead-time, regs, top | complementary outputs, fault shutdown |
| 320 | `packet-switch-4port` | Expert | ingress FIFOs, lookup, crossbar, egress | Multi (8+) | parser, FIFOs, crossbar, top | multi-port traffic |
| 321 | `cache-memory-subsystem` | Expert | CPU-side cache + memory controller + latency model | Multi (6+) | cache, controller, memory model | trace-driven accesses |
| 322 | `traffic-intersection-system` | Advanced | FSMs, timers, sensors, pedestrian, emergency override | Multi (6+) | controllers, timers, sensor sync, top | scenario scripts |
| 323 | `logic-analyzer-capture-engine` | Expert | trigger conditions, circular capture buffer, UART readout | Multi (6+) | trigger, capture RAM, readout, UART, top | triggered captures read back |
| 324 | `vga-frame-buffer-system` | Expert | dual-port frame buffer, pixel writer, VGA scan-out | Multi (5+) | framebuffer RAM, writer, VGA sync, top | drawn pattern read back via scan-out |
