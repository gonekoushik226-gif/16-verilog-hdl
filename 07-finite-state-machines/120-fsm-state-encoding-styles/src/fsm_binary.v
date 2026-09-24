`timescale 1ns / 1ps

// fsm_binary: the program-118 "1011" Moore sequence detector, re-stated
// here as the binary-encoding reference point for comparing state
// encoding styles (see fsm_gray.v, fsm_onehot.v in this same program).
// 5 states need ceil(log2(5))=3 bits; binary packs them as 000..100.
module fsm_binary (
    input  wire clk,
    input  wire rst_n,
    input  wire in_bit,
    output reg  detected
);

    localparam [2:0] S0 = 3'b000,
                      S1 = 3'b001,
                      S2 = 3'b010,
                      S3 = 3'b011,
                      S4 = 3'b100;

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
