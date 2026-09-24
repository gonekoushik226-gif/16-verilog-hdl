`timescale 1ns / 1ps

// traffic_controller: program 123's timed Moore traffic light, extended
// with a latched pedestrian request. The normal GREEN->YELLOW->RED cycle
// always runs to completion; if a pedestrian request is pending when the
// RED dwell finishes, a WALK phase (red still held for vehicles) is
// inserted before GREEN resumes. Requests made at any time -- during
// GREEN, YELLOW, RED, or even WALK itself -- are latched by
// `pedestrian_request` and cannot be lost.
module traffic_controller #(
    parameter WIDTH      = 8,
    parameter RED_TIME   = 6,
    parameter GREEN_TIME = 6,
    parameter YELLOW_TIME = 3,
    parameter WALK_TIME   = 5
) (
    input  wire clk,
    input  wire rst_n,
    input  wire req_btn,
    output wire red,
    output wire yellow,
    output wire green,
    output wire walk
);

    localparam [2:0] S_INIT   = 3'd0,
                      S_GREEN  = 3'd1,
                      S_YELLOW = 3'd2,
                      S_RED    = 3'd3,
                      S_WALK   = 3'd4;

    reg [2:0] state, state_next;

    wire timer_done;
    reg  [WIDTH-1:0] timer_duration;
    wire req_pending;
    reg  req_clear;

    timer #(.WIDTH(WIDTH)) u_timer (
        .clk(clk), .rst_n(rst_n),
        .start(state_next != state),
        .duration(timer_duration),
        .done(timer_done)
    );

    pedestrian_request u_req (
        .clk(clk), .rst_n(rst_n),
        .req_btn(req_btn), .clear(req_clear),
        .req_pending(req_pending)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_INIT;
        else        state <= state_next;
    end

    always @(*) begin
        state_next = state;
        case (state)
            S_INIT:   state_next = S_GREEN;                         // unconditional kickoff
            S_GREEN:  state_next = timer_done ? S_YELLOW : S_GREEN;
            S_YELLOW: state_next = timer_done ? S_RED    : S_YELLOW;
            S_RED:    state_next = timer_done
                                        ? (req_pending ? S_WALK : S_GREEN)
                                        : S_RED;
            S_WALK:   state_next = timer_done ? S_GREEN : S_WALK;
            default:  state_next = S_INIT;
        endcase
    end

    // duration for whichever phase is about to be entered (or held)
    always @(*) begin
        timer_duration = RED_TIME[WIDTH-1:0];
        case (state_next)
            S_GREEN:  timer_duration = GREEN_TIME[WIDTH-1:0];
            S_YELLOW: timer_duration = YELLOW_TIME[WIDTH-1:0];
            S_RED:    timer_duration = RED_TIME[WIDTH-1:0];
            S_WALK:   timer_duration = WALK_TIME[WIDTH-1:0];
            default:  timer_duration = RED_TIME[WIDTH-1:0];
        endcase
    end

    // clear the latched request once WALK has fully serviced it
    always @(*) begin
        req_clear = (state == S_WALK) && timer_done;
    end

    assign green  = (state == S_GREEN);
    assign yellow = (state == S_YELLOW);
    assign red    = (state == S_RED) || (state == S_WALK);
    assign walk   = (state == S_WALK);

endmodule
