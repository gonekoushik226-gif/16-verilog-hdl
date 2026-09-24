`timescale 1ns / 1ps

// safe_fsm: a 4-state one-hot sequencer (S_A->S_B->S_C->S_D->S_A on
// `advance`) whose next-state `case` only recognizes the 4 legal
// one-hot patterns; any of the other 12 possible 4-bit values (a
// corrupted state register -- e.g. from a radiation-induced upset in
// real hardware) falls into `default`, which recovers to S_A on the
// very next clock edge. `error` reports the corruption combinationally,
// the same cycle it appears, before the recovering edge even occurs.
module safe_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       advance,
    output wire [3:0] state_out,
    output wire       error
);

    localparam [3:0] S_A = 4'b0001, S_B = 4'b0010, S_C = 4'b0100, S_D = 4'b1000;

    reg [3:0] state, state_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_A;
        else        state <= state_next;
    end

    always @(*) begin
        state_next = S_A;   // default/safe recovery target
        case (state)
            S_A: state_next = advance ? S_B : S_A;
            S_B: state_next = advance ? S_C : S_B;
            S_C: state_next = advance ? S_D : S_C;
            S_D: state_next = advance ? S_A : S_D;
            default: state_next = S_A;   // illegal (non-one-hot) state: recover
        endcase
    end

    assign state_out = state;
    assign error      = !(state == S_A || state == S_B || state == S_C || state == S_D);

endmodule
