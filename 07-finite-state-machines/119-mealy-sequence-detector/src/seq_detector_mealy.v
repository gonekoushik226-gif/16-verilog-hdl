`timescale 1ns / 1ps

// seq_detector_mealy: Mealy FSM detecting "1011" on a serial bit stream,
// overlapping matches allowed. Unlike program 118's Moore version, only
// 4 states are needed -- the match is signalled combinationally on the
// S3-to-S1 transition (state="101", in_bit=1) instead of requiring a
// dedicated "matched" state, so `detected` goes high one cycle earlier
// relative to the same input stream.
module seq_detector_mealy (
    input  wire clk,
    input  wire rst_n,
    input  wire in_bit,
    output reg  detected
);

    localparam [1:0] S0 = 2'd0,  // no prefix of "1011" matched
                      S1 = 2'd1,  // "1" matched
                      S2 = 2'd2,  // "10" matched
                      S3 = 2'd3;  // "101" matched

    reg [1:0] state, state_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S0;
        else        state <= state_next;
    end

    // Next-state logic (same longest-matching-suffix rule as program 118,
    // but S3+1 folds back to S1 instead of advancing to a dedicated S4).
    always @(*) begin
        state_next = S0;
        case (state)
            S0: state_next = in_bit ? S1 : S0;
            S1: state_next = in_bit ? S1 : S2;
            S2: state_next = in_bit ? S3 : S0;
            S3: state_next = in_bit ? S1 : S2;
            default: state_next = S0;
        endcase
    end

    // Mealy output: function of state AND the current input, so it can
    // assert on the very transition that completes the match, without
    // waiting for a dedicated "matched" state to be clocked in.
    always @(*) begin
        detected = (state == S3) && in_bit;
    end

endmodule
