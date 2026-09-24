`timescale 1ns / 1ps

// sr_latch: cross-coupled NOR latch, the classic gate-level memory
// element with real feedback (each gate's output feeds the other
// gate's input). s=1,r=0 sets q=1; s=0,r=1 resets q=0; s=0,r=0 holds
// the last value; s=1,r=1 is the forbidden state, forcing both q and
// qn to 0 (violating their normal complementary relationship) for as
// long as it is held.
module sr_latch (
    input  wire s,
    input  wire r,
    output wire q,
    output wire qn
);

    nor g1 (q,  r, qn);
    nor g2 (qn, s, q);

endmodule
