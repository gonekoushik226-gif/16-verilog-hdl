`timescale 1ns / 1ps

// fsm_onehot: the identical "1011" Moore detector FSM as fsm_binary.v,
// re-encoded one-hot: 5 states need 5 flip-flops (vs. 3 for binary/gray),
// but next-state and output decode logic collapses to simple single-bit
// terms, which is why one-hot is common on FPGAs where flip-flops are
// cheap and decode logic (LUTs) is comparatively more precious.
module fsm_onehot (
    input  wire clk,
    input  wire rst_n,
    input  wire in_bit,
    output wire detected
);

    localparam [4:0] S0 = 5'b00001,
                      S1 = 5'b00010,
                      S2 = 5'b00100,
                      S3 = 5'b01000,
                      S4 = 5'b10000;

    reg [4:0] state, state_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S0;
        else        state <= state_next;
    end

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

    // one-hot output decode is a single bit test, no equality comparator
    assign detected = state[4];

endmodule
