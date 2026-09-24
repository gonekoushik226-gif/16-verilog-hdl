`timescale 1ns / 1ps

// cla4_block: one 4-bit lookahead block. Computes its own internal
// carries from its own bit-level p/g and an externally supplied block
// carry-in (cin, which the top-level lookahead_unit computes for all
// four blocks in parallel rather than by rippling between blocks), and
// also exposes its own group propagate (P) and group generate (G) so a
// second lookahead level can treat this whole 4-bit block as a single
// generate/propagate unit — the same equations as program 069's cla4,
// factored so cin arrives from outside instead of being a module input
// used only locally.
module cla4_block (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       p_group,   // P = p3 & p2 & p1 & p0
    output wire       g_group    // G = g3 | (p3&g2) | (p3&p2&g1) | (p3&p2&p1&g0)
);

    wire [3:0] p, g;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : pg
            pg_cell pgc (.a(a[i]), .b(b[i]), .p(p[i]), .g(g[i]));
        end
    endgenerate

    wire c0 = cin;
    wire c1 = g[0] | (p[0] & c0);
    wire c2 = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c0);
    wire c3 = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c0);

    assign sum     = p ^ {c3, c2, c1, c0};
    assign p_group = p[3] & p[2] & p[1] & p[0];
    assign g_group = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);

endmodule
