`timescale 1ns / 1ps

// microwave_controller: a main FSM (S_IDLE/S_COOKING/S_PAUSED/S_DONE)
// coordinating two sub-modules: `door_monitor` (registers the door
// sensor) and `countdown_timer` (the cook-time countdown, restartable
// and pausable). Opening the door mid-cook pauses the countdown
// IMMEDIATELY (timer.pause is driven directly by the registered
// door_open, not by the main state, so there is no extra detection
// latency before heating stops) while the main FSM's own S_PAUSED
// state is purely for observability. Cooking cannot start while the
// door is open (a safety interlock), and `cancel` returns to S_IDLE
// from either S_COOKING or S_PAUSED.
module microwave_controller #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire             cancel,
    input  wire             door_open_raw,
    input  wire [WIDTH-1:0] cook_time,
    output wire             cooking,
    output wire             paused,
    output wire             done_beep,
    output wire             idle
);

    localparam [1:0] S_IDLE = 2'd0, S_COOKING = 2'd1, S_PAUSED = 2'd2, S_DONE = 2'd3;

    reg [1:0] state;

    wire door_open;
    wire timer_done;

    // S_IDLE or S_DONE entering S_COOKING loads a fresh cook_time;
    // resuming from S_PAUSED must NOT restart the timer, so this does
    // not fire then
    wire timer_start = (state == S_IDLE || state == S_DONE) && start && !door_open;

    door_monitor u_door (
        .clk(clk), .rst_n(rst_n),
        .door_open_raw(door_open_raw), .door_open(door_open)
    );

    countdown_timer #(.WIDTH(WIDTH)) u_timer (
        .clk(clk), .rst_n(rst_n),
        .start(timer_start), .pause(door_open),
        .duration(cook_time), .done(timer_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: if (start && !door_open) state <= S_COOKING;
                S_COOKING: begin
                    if (cancel)          state <= S_IDLE;
                    else if (door_open)  state <= S_PAUSED;
                    else if (timer_done) state <= S_DONE;
                end
                S_PAUSED: begin
                    if (cancel)           state <= S_IDLE;
                    else if (!door_open)  state <= S_COOKING;
                end
                S_DONE: begin
                    if (cancel)                   state <= S_IDLE;
                    else if (start && !door_open) state <= S_COOKING;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign cooking   = (state == S_COOKING);
    assign paused     = (state == S_PAUSED);
    assign done_beep  = (state == S_DONE);
    assign idle        = (state == S_IDLE);

endmodule
