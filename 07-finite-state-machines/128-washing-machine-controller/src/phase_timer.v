`timescale 1ns / 1ps

// phase_timer: a restartable interval timer like program 124/126's
// timer/door_timer, extended with `pause`: while asserted and the timer
// is running, the count freezes (neither advances nor completes) until
// `pause` deasserts -- modeling a safety interlock (e.g. a washing
// machine's lid sensor) that must be able to suspend an in-progress
// phase without losing its position.
module phase_timer #(
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
