`timescale 1ns / 1ps

// div_by_3_fsm: reads a binary number serially, most-significant bit
// first, and tracks (value-read-so-far) mod 3 as FSM state. Because
// shifting the accumulated value left by one bit and adding the new bit
// is exactly "value*2+bit", and (2*r + b) mod 3 depends only on the old
// remainder r and the new bit b, a 3-state machine is sufficient no
// matter how many bits the number has.
module div_by_3_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire bit_in,
    output wire [1:0] remainder,   // running (value-so-far) mod 3
    output wire div_by_3           // remainder == 0
);

    localparam [1:0] R0 = 2'd0, R1 = 2'd1, R2 = 2'd2;

    reg [1:0] state, state_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= R0;
        else        state <= state_next;
    end

    // next_remainder = (2*state + bit_in) mod 3
    always @(*) begin
        state_next = R0;
        case (state)
            R0: state_next = bit_in ? R1 : R0;   // 0*2+0=0, 0*2+1=1
            R1: state_next = bit_in ? R0 : R2;   // 1*2+1=3->0, 1*2+0=2
            R2: state_next = bit_in ? R2 : R1;   // 2*2+1=5->2, 2*2+0=4->1
            default: state_next = R0;
        endcase
    end

    assign remainder  = state;
    assign div_by_3    = (state == R0);

endmodule
