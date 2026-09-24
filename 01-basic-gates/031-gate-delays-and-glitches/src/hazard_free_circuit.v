`timescale 1ns / 1ps

// hazard_free_circuit: the same function f(a,b,c) = ab + b'c, with the
// redundant consensus term "ac" added: f = ab + b'c + ac. The consensus
// term is algebraically redundant (it never changes the truth table) but
// stays constant at 1 across any transition of b while a=c=1, which holds
// the OR gate's output at 1 through the transition and removes the
// static-1 hazard that hazard_circuit exhibits.
module hazard_free_circuit (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    wire nb, t1, t2, t3;

    not #(2) g_inv  (nb, b);      // b', 2ns after b changes
    and #(3) g_and1 (t1, a, b);   // ab
    and #(3) g_and2 (t2, nb, c);  // b'c
    and #(3) g_and3 (t3, a, c);   // consensus term ac
    or  #(2) g_or   (y, t1, t2, t3);

endmodule
