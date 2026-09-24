`timescale 1ns / 1ps

// booth_radix4_mult: WIDTH-bit x WIDTH-bit signed multiplier using
// modified (radix-4) Booth recoding. WIDTH must be even. Examines the
// multiplier b two bits at a time, with a 1-bit overlap between groups
// (group k looks at b[2k+1],b[2k],b[2k-1], with an implicit b[-1]=0),
// so each group needs at most one shift-by-1 and one negation of the
// multiplicand instead of an arbitrary-width partial product — roughly
// halving the number of rows an ordinary array multiplier (076) would
// need.
module booth_radix4_mult #(
    parameter WIDTH = 6
) (
    input  wire signed [WIDTH-1:0]   a,
    input  wire signed [WIDTH-1:0]   b,
    output wire signed [2*WIDTH-1:0] product
);

    localparam NGROUPS = (WIDTH + 2) / 2;   // WIDTH even -> exact ceil((WIDTH+1)/2)

    // b, sign-extended to 2*NGROUPS bits, with a virtual b[-1]=0 appended
    // at the bottom: bext[0]=b[-1](=0), bext[1+:WIDTH]=b, rest=sign ext.
    wire [2*NGROUPS:0] bext = { {(2*NGROUPS-WIDTH){b[WIDTH-1]}}, b, 1'b0 };

    wire [NGROUPS-1:0] neg, x1, x2;

    genvar k;
    generate
        for (k = 0; k < NGROUPS; k = k + 1) begin : enc
            booth_encoder be (
                .b2(bext[2*k+2]), .b1(bext[2*k+1]), .b0(bext[2*k]),
                .neg(neg[k]), .x1(x1[k]), .x2(x2[k])
            );
        end
    endgenerate

    // Sum every group's row (magnitude-selected, optionally negated,
    // shifted to its group weight) with plenty of headroom bits so no
    // intermediate step overflows before the final truncation to the
    // exact 2*WIDTH-bit product width.
    integer i;
    reg signed [2*WIDTH+3:0] acc;
    reg signed [WIDTH:0]     row_mag;
    reg signed [2*WIDTH+3:0] row_ext;

    always @(*) begin
        acc = {(2*WIDTH+4){1'b0}};
        for (i = 0; i < NGROUPS; i = i + 1) begin
            row_mag = x2[i] ? ({a[WIDTH-1], a} <<< 1)
                            : (x1[i] ? {a[WIDTH-1], a} : {(WIDTH+1){1'b0}});
            row_ext = { {(2*WIDTH + 3 - WIDTH){row_mag[WIDTH]}}, row_mag };
            if (neg[i]) row_ext = -row_ext;
            acc = acc + (row_ext <<< (2*i));
        end
    end

    assign product = acc[2*WIDTH-1:0];

endmodule
