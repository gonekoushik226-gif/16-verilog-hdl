`timescale 1ns / 1ps

// fsm_gray: the identical "1011" Moore detector FSM as fsm_binary.v, with
// only the state encoding changed to reflected Gray code (adjacent states
// in the transition graph differ by exactly one bit at the encoding
// level too -- though note the state *graph* here is not a simple ring,
// so not every transition is a single-bit change; only the S0-S1-S2-S3-S4
// numbering sequence itself is one-bit-adjacent by construction).
module fsm_gray (
    input  wire clk,
    input  wire rst_n,
    input  wire in_bit,
    output reg  detected
);

    // gray(n) = n ^ (n>>1) for n=0..4
    localparam [2:0] S0 = 3'b000,  // gray(0)
                      S1 = 3'b001,  // gray(1)
                      S2 = 3'b011,  // gray(2)
                      S3 = 3'b010,  // gray(3)
                      S4 = 3'b110;  // gray(4)

    reg [2:0] state, state_next;

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

    always @(*) begin
        detected = (state == S4);
    end

endmodule
