`timescale 1ns / 1ps

// countdown_timer: restartable interval timer with a `pause` input that
// freezes the count (not merely ignores its completion) while asserted
// -- same start/pause/duration/done handshake as program 128's
// phase_timer, reused here for the microwave's cook-time countdown.
module countdown_timer #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire             pause,
    input  wire [WIDTH-1:0] duration,
    output reg              done
);

    reg [WIDTH-1:0] cnt;
    reg             running;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= {WIDTH{1'b0}};
            running <= 1'b0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin
                cnt     <= {WIDTH{1'b0}};
                running <= 1'b1;
            end else if (running && !pause) begin
                if (cnt == duration - 1'b1) begin
                    done    <= 1'b1;
                    running <= 1'b0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
            // running && pause: hold cnt and running unchanged (frozen)
        end
    end

endmodule
