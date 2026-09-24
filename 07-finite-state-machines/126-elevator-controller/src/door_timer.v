`timescale 1ns / 1ps

// door_timer: fixed-duration (compile-time OPEN_TIME) restartable timer,
// used to hold the elevator door open for a set number of cycles. Same
// start/done handshake style as program 124's `timer`, but with the
// duration baked in as a parameter instead of a runtime port, since this
// program's complexity budget is spent on the controller's FSM/SCAN
// dispatch logic rather than another configurable timer.
module door_timer #(
    parameter OPEN_TIME = 4,
    parameter WIDTH     = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg  done
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
            end else if (running) begin
                if (cnt == OPEN_TIME[WIDTH-1:0] - 1'b1) begin
                    done    <= 1'b1;
                    running <= 1'b0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule
