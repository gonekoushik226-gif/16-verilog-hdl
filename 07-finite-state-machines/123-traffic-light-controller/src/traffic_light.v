`timescale 1ns / 1ps

// traffic_light: a timed Moore FSM cycling RED -> GREEN -> YELLOW -> RED
// forever, dwelling in each state for a parameterized number of clock
// cycles (an internal counter, not an external timer module). Exactly
// one of red/yellow/green is asserted at any time -- a direct function
// of `state` (Moore).
module traffic_light #(
    parameter RED_TIME    = 4,
    parameter GREEN_TIME  = 6,
    parameter YELLOW_TIME = 3
) (
    input  wire clk,
    input  wire rst_n,
    output reg  red,
    output reg  yellow,
    output reg  green
);

    function integer max3(input integer a, input integer b, input integer c);
        begin
            max3 = a;
            if (b > max3) max3 = b;
            if (c > max3) max3 = c;
        end
    endfunction

    localparam integer MAX_TIME = max3(RED_TIME, GREEN_TIME, YELLOW_TIME);
    localparam integer CNT_W    = $clog2(MAX_TIME + 1);

    localparam [1:0] S_RED = 2'd0, S_GREEN = 2'd1, S_YELLOW = 2'd2;

    reg [1:0]        state, state_next;
    reg [CNT_W-1:0]  cnt,   cnt_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RED;
            cnt   <= {CNT_W{1'b0}};
        end else begin
            state <= state_next;
            cnt   <= cnt_next;
        end
    end

    always @(*) begin
        state_next = state;
        cnt_next   = cnt + 1'b1;
        case (state)
            S_RED:    if (cnt == RED_TIME[CNT_W-1:0]-1'b1)
                          begin state_next = S_GREEN;  cnt_next = {CNT_W{1'b0}}; end
            S_GREEN:  if (cnt == GREEN_TIME[CNT_W-1:0]-1'b1)
                          begin state_next = S_YELLOW; cnt_next = {CNT_W{1'b0}}; end
            S_YELLOW: if (cnt == YELLOW_TIME[CNT_W-1:0]-1'b1)
                          begin state_next = S_RED;    cnt_next = {CNT_W{1'b0}}; end
            default: begin state_next = S_RED; cnt_next = {CNT_W{1'b0}}; end
        endcase
    end

    always @(*) begin
        red = 1'b0; yellow = 1'b0; green = 1'b0;
        case (state)
            S_RED:    red    = 1'b1;
            S_GREEN:  green  = 1'b1;
            S_YELLOW: yellow = 1'b1;
            default:  red    = 1'b1;
        endcase
    end

endmodule
