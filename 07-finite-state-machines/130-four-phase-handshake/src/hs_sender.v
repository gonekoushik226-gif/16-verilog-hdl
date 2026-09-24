`timescale 1ns / 1ps

// hs_sender: sender side of a synchronous four-phase (return-to-zero)
// req/ack handshake. Phase 1: latch data and raise `req`. Phase 3
// (sender's reaction to phase 2): once `ack` is seen, drop `req`.
// Phase 4 (sender's reaction to the receiver's phase 4): once `ack`
// drops again, the link is idle and ready for the next word.
module hs_sender #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             data_valid,
    input  wire [WIDTH-1:0] data_in,
    input  wire             ack,
    output reg              req,
    output reg  [WIDTH-1:0] data_out,
    output wire             busy
);

    localparam [1:0] S_IDLE = 2'd0, S_REQ_HIGH = 2'd1, S_REQ_LOW = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            req      <= 1'b0;
            data_out <= {WIDTH{1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    req <= 1'b0;
                    if (data_valid) begin
                        data_out <= data_in;
                        req      <= 1'b1;
                        state    <= S_REQ_HIGH;
                    end
                end
                S_REQ_HIGH: begin
                    req <= 1'b1;
                    if (ack) begin
                        req   <= 1'b0;
                        state <= S_REQ_LOW;
                    end
                end
                S_REQ_LOW: begin
                    req <= 1'b0;
                    if (!ack) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign busy = (state != S_IDLE);

endmodule
