`timescale 1ns / 1ps

// comparator4: 4-bit magnitude comparator built from four comparator1 cells
// cascaded MSB-first, in the style of the classic 74LS85. External cascade
// inputs (cin_gt/cin_lt/cin_eq) let several comparator4 instances be chained
// to compare buses wider than 4 bits, exactly as the 74LS85 datasheet
// describes; a standalone 4-bit comparison ties them to the "equal" idle
// state (cin_gt=0, cin_lt=0, cin_eq=1).
module comparator4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin_gt,
    input  wire       cin_lt,
    input  wire       cin_eq,
    output wire        gt,
    output wire        lt,
    output wire        eq
);

    wire g3, l3, e3;   // bit 3 (MSB) stage output, feeds bit 2's cascade input
    wire g2, l2, e2;
    wire g1, l1, e1;

    // Stage order: bit 3 is evaluated first, seeded with the external
    // cascade inputs; each following stage is only reached when every more
    // significant bit compared equal, so the cascade truly carries
    // "equal so far, starting from the most significant bit".
    comparator1 cell3 (.a(a[3]), .b(b[3]), .gt_in(cin_gt), .lt_in(cin_lt), .eq_in(cin_eq), .gt_out(g3), .lt_out(l3), .eq_out(e3));
    comparator1 cell2 (.a(a[2]), .b(b[2]), .gt_in(g3),     .lt_in(l3),     .eq_in(e3),     .gt_out(g2), .lt_out(l2), .eq_out(e2));
    comparator1 cell1 (.a(a[1]), .b(b[1]), .gt_in(g2),     .lt_in(l2),     .eq_in(e2),     .gt_out(g1), .lt_out(l1), .eq_out(e1));
    comparator1 cell0 (.a(a[0]), .b(b[0]), .gt_in(g1),     .lt_in(l1),     .eq_in(e1),     .gt_out(gt), .lt_out(lt), .eq_out(eq));

endmodule
