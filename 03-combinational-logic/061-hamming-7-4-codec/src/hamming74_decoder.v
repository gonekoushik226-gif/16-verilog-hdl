`timescale 1ns / 1ps

// hamming74_decoder: recomputes the three parity-check equations against
// a received 7-bit codeword to form a 3-bit syndrome. A zero syndrome
// means no error; a nonzero syndrome directly gives the 1-indexed bit
// position of a single flipped bit (this is the defining property of the
// Hamming(7,4) parity-check matrix), which is then corrected before the
// four data bits are extracted. Any single-bit error anywhere in the
// 7-bit codeword — a parity bit or a data bit — is corrected this way.
module hamming74_decoder (
    input  wire [6:0] code_in,   // code_in[0]=position1 .. code_in[6]=position7
    output wire [3:0] data_out,  // {d4,d3,d2,d1}, corrected
    output wire       error,     // 1 when a (corrected) single-bit error was detected
    output wire [2:0] syndrome   // 0 = no error, else the 1-indexed faulty position
);

    wire s1 = code_in[0] ^ code_in[2] ^ code_in[4] ^ code_in[6];   // positions 1,3,5,7
    wire s2 = code_in[1] ^ code_in[2] ^ code_in[5] ^ code_in[6];   // positions 2,3,6,7
    wire s3 = code_in[3] ^ code_in[4] ^ code_in[5] ^ code_in[6];   // positions 4,5,6,7

    wire [2:0] synd = {s3, s2, s1};

    // flip the faulty bit (position `synd`, 1-indexed) only when the
    // syndrome is nonzero; the shift amount is only meaningful in that case
    wire [6:0] corrected = (synd == 3'd0) ? code_in : (code_in ^ (7'b1 << (synd - 3'd1)));

    assign data_out = {corrected[6], corrected[5], corrected[4], corrected[2]};
    assign error     = (synd != 3'd0);
    assign syndrome  = synd;

endmodule
