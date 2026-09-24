`timescale 1ns / 1ps

// vending_machine: a 2-state Moore FSM (S_IDLE / S_VEND) with an
// 8-bit credit accumulator. Coin inputs are one-hot, momentary
// (one clock pulse per coin, at most one coin per cycle -- a real
// coin-slot mechanism serializes coins the same way). As soon as
// accumulated credit reaches PRICE, the machine vends on the very next
// clock edge and reports the correct change, then resets credit to 0
// and returns to accepting coins.
module vending_machine #(
    parameter PRICE = 45   // price of the item, in cents
) (
    input  wire clk,
    input  wire rst_n,
    input  wire coin_5,
    input  wire coin_10,
    input  wire coin_25,
    output reg  vend,        // one-cycle pulse: item dispensed
    output reg  [7:0] change, // change due, valid the same cycle as `vend`
    output wire [7:0] credit  // current accumulated credit
);

    localparam S_IDLE = 1'b0, S_VEND = 1'b1;

    reg       state, state_next;
    reg [7:0] credit_r, credit_next;

    assign credit = credit_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            credit_r <= 8'd0;
        end else begin
            state    <= state_next;
            credit_r <= credit_next;
        end
    end

    always @(*) begin
        state_next  = state;
        credit_next = credit_r;
        case (state)
            S_IDLE: begin
                if (coin_5)       credit_next = credit_r + 8'd5;
                else if (coin_10) credit_next = credit_r + 8'd10;
                else if (coin_25) credit_next = credit_r + 8'd25;

                if (credit_next >= PRICE[7:0])
                    state_next = S_VEND;
            end
            S_VEND: begin
                credit_next = 8'd0;
                state_next  = S_IDLE;
            end
            default: begin
                state_next  = S_IDLE;
                credit_next = 8'd0;
            end
        endcase
    end

    always @(*) begin
        vend   = (state == S_VEND);
        change = (state == S_VEND) ? (credit_r - PRICE[7:0]) : 8'd0;
    end

endmodule
