`timescale 1ns / 1ps

// seq_detector_moore: Moore FSM detecting "1011" on a serial bit stream,
// overlapping matches allowed (e.g. "1011011" detects at bit 3 and bit 6).
// `detected` is a pure function of state (Moore output), so it is valid
// for the whole cycle after the state that completes the match.
module seq_detector_moore (
    input  wire clk,
    input  wire rst_n,
    input  wire in_bit,
    output reg  detected
);

    localparam [2:0] S0 = 3'd0,  // no prefix of "1011" matched
                      S1 = 3'd1,  // "1" matched
                      S2 = 3'd2,  // "10" matched
                      S3 = 3'd3,  // "101" matched
                      S4 = 3'd4;  // "1011" matched (output state)

    reg [2:0] state, state_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S0;
        else        state <= state_next;
    end

    // Next-state logic: from S4, the previous 3 bits were "011", so the
    // overlap transitions are computed the same way as from any other
    // state -- the longest suffix of the last bits that is also a prefix
    // of "1011" decides the next state.
    always @(*) begin
        state_next = S0;
        case (state)
            S0: state_next = in_bit ? S1 : S0;
            S1: state_next = in_bit ? S1 : S2;
            S2: state_next = in_bit ? S3 : S0;
            S3: state_next = in_bit ? S4 : S2;
            S4: state_next = in_bit ? S1 : S2;
            default: state_next = S0;
        endcase
    end

    // Moore output: depends only on the current state.
    always @(*) begin
        detected = (state == S4);
    end

endmodule
