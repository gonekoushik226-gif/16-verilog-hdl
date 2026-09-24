`timescale 1ns / 1ps

// stepper_controller: drives a 4-coil stepper motor through the
// standard 8-position half-step sequence table. Full-step mode walks
// the SAME table two positions at a time, landing only on its 4
// single-coil-energized entries (indices 0,2,4,6) -- so both modes
// share one table instead of needing two separate sequences. A
// SPEED_DIV-cycle prescaler paces how often a step actually advances;
// `enable` gates stepping (and holds the prescaler at 0, so stepping
// always starts fresh from a full period after re-enabling) without
// changing the current coil pattern.
module stepper_controller #(
    parameter SPEED_DIV = 4   // clock cycles between successive steps
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       dir,        // 1 = forward, 0 = reverse
    input  wire       half_step,  // 1 = half-step (8 positions), 0 = full-step (4)
    output reg  [3:0] coil
);

    localparam PRESC_W = $clog2(SPEED_DIV);

    reg [PRESC_W-1:0] presc_cnt;
    reg [2:0]         idx;

    wire step_en = enable && (presc_cnt == SPEED_DIV[PRESC_W-1:0] - 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            presc_cnt <= {PRESC_W{1'b0}};
        end else if (!enable) begin
            presc_cnt <= {PRESC_W{1'b0}};
        end else if (presc_cnt == SPEED_DIV[PRESC_W-1:0] - 1'b1) begin
            presc_cnt <= {PRESC_W{1'b0}};
        end else begin
            presc_cnt <= presc_cnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 3'd0;
        end else if (step_en) begin
            if (half_step) idx <= dir ? (idx + 3'd1) : (idx - 3'd1);
            else           idx <= dir ? (idx + 3'd2) : (idx - 3'd2);
        end
    end

    // 8-position half-step table; full-step mode only ever visits the
    // 4 single-coil entries (0, 2, 4, 6)
    always @(*) begin
        case (idx)
            3'd0: coil = 4'b1000;
            3'd1: coil = 4'b1100;
            3'd2: coil = 4'b0100;
            3'd3: coil = 4'b0110;
            3'd4: coil = 4'b0010;
            3'd5: coil = 4'b0011;
            3'd6: coil = 4'b0001;
            3'd7: coil = 4'b1001;
            default: coil = 4'b1000;
        endcase
    end

endmodule
