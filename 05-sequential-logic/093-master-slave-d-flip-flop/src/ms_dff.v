`timescale 1ns / 1ps

// ms_dff: positive-edge-triggered D flip-flop built from two D latches
// (program 086/094's building block), the classic master-slave
// construction -- demonstrating that "edge-triggered" behavior can
// itself be built from purely level-sensitive pieces.
//
// The master latch is transparent while clk=0 and freezes (holds) the
// instant clk rises. The slave latch is transparent while clk=1 (i.e.
// while the master is frozen) and freezes while clk=0 (i.e. while the
// master is transparent). Because the two are never transparent at the
// same time, data can only flow all the way from d to q once per clk
// cycle, at the instant clk transitions from 0 to 1 -- which is exactly
// what makes the combination behave as if it triggered on the rising
// edge, with no explicit `posedge` anywhere in either latch.
module ms_dff (
    input  wire clk,
    input  wire d,
    output wire q
);

    wire master_q;

    d_latch master (.d(d),        .en(~clk), .q(master_q));
    d_latch slave  (.d(master_q), .en(clk),  .q(q));

endmodule
