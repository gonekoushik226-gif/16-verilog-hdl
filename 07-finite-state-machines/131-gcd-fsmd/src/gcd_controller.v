`timescale 1ns / 1ps

// gcd_controller: the control half of the GCD FSMD. Each cycle in
// S_COMPUTE it inspects the datapath's status flags and decides to
// subtract the smaller register from the larger -- one subtraction per
// cycle, exactly the textbook subtraction-based Euclidean algorithm.
// `a_zero`/`b_zero` end the loop immediately for a zero operand (the
// pure equality-only version would spin forever on gcd(a,0): a never
// changes because a-0=a).
module gcd_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire eq,
    input  wire a_gt_b,
    input  wire a_zero,
    input  wire b_zero,
    output reg  load,
    output reg  sub_a,
    output reg  sub_b,
    output wire done,
    output wire busy
);

    localparam [1:0] S_IDLE = 2'd0, S_COMPUTE = 2'd1, S_DONE = 2'd2;

    reg [1:0] state;

    wire converged = eq || a_zero || b_zero;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE:    if (start) state <= S_COMPUTE;
                S_COMPUTE: if (converged) state <= S_DONE;
                S_DONE:    if (start) state <= S_COMPUTE;
                default:   state <= S_IDLE;
            endcase
        end
    end

    always @(*) begin
        load  = 1'b0;
        sub_a = 1'b0;
        sub_b = 1'b0;
        case (state)
            S_IDLE: load = start;
            S_COMPUTE: begin
                if (!converged) begin
                    if (a_gt_b) sub_a = 1'b1;
                    else        sub_b = 1'b1;
                end
            end
            S_DONE: load = start;
            default: ;
        endcase
    end

    assign done = (state == S_DONE);
    assign busy = (state == S_COMPUTE);

endmodule
