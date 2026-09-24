`timescale 1ns / 1ps

// hs_receiver: receiver side of the four-phase handshake. Phase 2
// (reaction to phase 1): once `req` is seen, latch data and raise
// `ack`. Phase 4 (reaction to the sender's phase 3): once `req` drops
// again, drop `ack`, returning to idle.
module hs_receiver #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             req,
    input  wire [WIDTH-1:0] data_in,
    output reg              ack,
    output reg  [WIDTH-1:0] data_out,
    output reg              data_ready
);

    localparam S_IDLE = 1'b0, S_ACK_HIGH = 1'b1;

    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            ack        <= 1'b0;
            data_out   <= {WIDTH{1'b0}};
            data_ready <= 1'b0;
        end else begin
            data_ready <= 1'b0;
            case (state)
                S_IDLE: begin
                    ack <= 1'b0;
                    if (req) begin
                        data_out   <= data_in;
                        ack        <= 1'b1;
                        data_ready <= 1'b1;
                        state      <= S_ACK_HIGH;
                    end
                end
                S_ACK_HIGH: begin
                    ack <= 1'b1;
                    if (!req) begin
                        ack   <= 1'b0;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
