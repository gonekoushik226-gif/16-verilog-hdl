`timescale 1ns / 1ps

// full_subtractor: two half subtractors plus an OR gate, mirroring the
// full_adder construction in program 063. The first stage computes
// a-b; the second subtracts bin from that partial difference. At most
// one stage ever borrows for a given input combination, so borrow_out
// is their OR.
module full_subtractor (
    input  wire a,
    input  wire b,
    input  wire bin,
    output wire diff,
    output wire borrow_out
);

    wire diff1, borrow1, borrow2;

    half_subtractor hs1 (.a(a),     .b(b),   .diff(diff1), .borrow(borrow1));
    half_subtractor hs2 (.a(diff1), .b(bin), .diff(diff),  .borrow(borrow2));

    assign borrow_out = borrow1 | borrow2;

endmodule
