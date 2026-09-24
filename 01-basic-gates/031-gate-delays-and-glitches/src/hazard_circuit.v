`timescale 1ns / 1ps

// hazard_circuit: f(a,b,c) = ab + b'c, built from primitives with explicit
// per-gate delays so that a real static-1 hazard (a transient glitch to 0
// while the function should stay logically 1) can be observed in
// simulation when b changes while a=1 and c=1.
//
// This program intentionally uses `#` delays, which are otherwise
// forbidden in synthesizable RTL (see CLAUDE.md §4) — that is exactly
// what it is meant to teach; program.conf sets SYNTH=no because delay
// values are a simulation/timing concept, not a synthesizable one.
module hazard_circuit (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    wire nb, t1, t2;

    not #(2) g_inv  (nb, b);      // b', 2ns after b changes
    and #(3) g_and1 (t1, a, b);   // ab, 3ns after a or b changes
    and #(3) g_and2 (t2, nb, c);  // b'c, 3ns after nb or c changes
    or  #(2) g_or   (y, t1, t2);  // ab + b'c, 2ns after t1 or t2 changes

endmodule
