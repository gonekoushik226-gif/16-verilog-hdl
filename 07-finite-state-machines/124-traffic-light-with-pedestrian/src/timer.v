`timescale 1ns / 1ps

// timer: a reusable, restartable interval timer. A one-cycle `start`
// pulse loads `duration` and begins counting; `done` pulses for exactly
// one cycle `duration` clock edges after the start pulse is consumed
// (registered, not combinational -- like program 116/117's `tick`, this
// costs the consumer one extra cycle to react, documented in the
// top-level traffic_controller README).
module timer #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
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
                if (duration <= 1) begin
                    done    <= 1'b1;   // 0- or 1-cycle duration: pulse immediately
                    running <= 1'b0;
                end else begin
                    cnt     <= {WIDTH{1'b0}};
                    running <= 1'b1;
                end
            end else if (running) begin
                if (cnt == duration - 1'b1) begin
                    done    <= 1'b1;
                    running <= 1'b0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule
