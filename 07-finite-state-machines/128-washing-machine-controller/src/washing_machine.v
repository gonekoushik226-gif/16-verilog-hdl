`timescale 1ns / 1ps

// washing_machine: a fixed-sequence Moore FSM (FILL -> WASH -> RINSE ->
// SPIN -> DONE) driven by a single `phase_timer`, whose duration is
// re-selected for whichever phase is current. `lid_open` pauses the
// active phase's timer without losing progress (see phase_timer.v);
// `cancel` immediately cancels the cycle back to IDLE from any running
// phase. Pressing `start` again from DONE begins a fresh cycle.
module washing_machine #(
    parameter WIDTH      = 8,
    parameter FILL_TIME  = 4,
    parameter WASH_TIME  = 8,
    parameter RINSE_TIME = 5,
    parameter SPIN_TIME  = 6
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire cancel,
    input  wire lid_open,
    output wire filling,
    output wire washing,
    output wire rinsing,
    output wire spinning,
    output wire done_light,
    output wire idle
);

    localparam [2:0] S_IDLE  = 3'd0, S_FILL = 3'd1, S_WASH = 3'd2,
                      S_RINSE = 3'd3, S_SPIN = 3'd4, S_DONE = 3'd5;

    reg [2:0] state, state_next;

    wire timer_done;
    reg  [WIDTH-1:0] timer_duration;

    wire is_timed_next = (state_next == S_FILL)  || (state_next == S_WASH)
                       || (state_next == S_RINSE) || (state_next == S_SPIN);

    phase_timer #(.WIDTH(WIDTH)) u_timer (
        .clk(clk), .rst_n(rst_n),
        .start((state_next != state) && is_timed_next),
        .pause(lid_open),
        .duration(timer_duration),
        .done(timer_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= state_next;
    end

    always @(*) begin
        timer_duration = FILL_TIME[WIDTH-1:0];
        case (state_next)
            S_FILL:  timer_duration = FILL_TIME[WIDTH-1:0];
            S_WASH:  timer_duration = WASH_TIME[WIDTH-1:0];
            S_RINSE: timer_duration = RINSE_TIME[WIDTH-1:0];
            S_SPIN:  timer_duration = SPIN_TIME[WIDTH-1:0];
            default: timer_duration = FILL_TIME[WIDTH-1:0];
        endcase
    end

    always @(*) begin
        state_next = state;
        case (state)
            S_IDLE:  if (start) state_next = S_FILL;
            S_FILL:  if (cancel) state_next = S_IDLE;
                     else if (timer_done) state_next = S_WASH;
            S_WASH:  if (cancel) state_next = S_IDLE;
                     else if (timer_done) state_next = S_RINSE;
            S_RINSE: if (cancel) state_next = S_IDLE;
                     else if (timer_done) state_next = S_SPIN;
            S_SPIN:  if (cancel) state_next = S_IDLE;
                     else if (timer_done) state_next = S_DONE;
            S_DONE:  if (start) state_next = S_FILL;
            default: state_next = S_IDLE;
        endcase
    end

    assign filling    = (state == S_FILL);
    assign washing    = (state == S_WASH);
    assign rinsing    = (state == S_RINSE);
    assign spinning   = (state == S_SPIN);
    assign done_light = (state == S_DONE);
    assign idle       = (state == S_IDLE);

endmodule
