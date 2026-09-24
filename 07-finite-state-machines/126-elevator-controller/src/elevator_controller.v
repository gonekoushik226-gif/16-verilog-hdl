`timescale 1ns / 1ps

// elevator_controller: a simplified SCAN-algorithm elevator over
// FLOORS floors (0..FLOORS-1). Pending floor requests (hall + cabin
// calls unified into one bit per floor, per this program's simplified
// model) are held in `request_register`. The controller continues
// moving in its current direction while requests remain that way,
// reversing only when none remain ahead; it stops and opens the door
// (via `door_timer`) whenever it arrives at, or already sits at, a
// requested floor.
module elevator_controller #(
    parameter FLOORS    = 4,
    parameter MOVE_TIME = 3,   // cycles to travel between adjacent floors
    parameter OPEN_TIME = 4    // cycles the door stays open
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [FLOORS-1:0]     request_in,
    output wire [$clog2(FLOORS)-1:0] current_floor,
    output wire                  moving_up,
    output wire                  moving_down,
    output wire                  door_open,
    output wire [FLOORS-1:0]     pending_out
);

    localparam FLOOR_W = (FLOORS <= 2) ? 1 : $clog2(FLOORS);
    localparam CNT_W   = $clog2(MOVE_TIME + 1);

    localparam [1:0] S_IDLE      = 2'd0,
                      S_MOVE_UP   = 2'd1,
                      S_MOVE_DOWN = 2'd2,
                      S_DOOR_OPEN = 2'd3;

    reg [1:0]         state, state_next;
    reg [FLOOR_W-1:0] floor_r, floor_next;
    reg [CNT_W-1:0]   move_cnt, move_cnt_next;
    reg               direction_r, direction_next;   // 1 = up, 0 = down

    wire [FLOORS-1:0] pending;
    reg  [FLOORS-1:0] clear_mask;
    reg               door_start;
    wire              door_done;

    request_register #(.FLOORS(FLOORS)) u_req (
        .clk(clk), .rst_n(rst_n),
        .request_in(request_in), .clear_mask(clear_mask),
        .pending(pending)
    );

    door_timer #(.OPEN_TIME(OPEN_TIME), .WIDTH(8)) u_door (
        .clk(clk), .rst_n(rst_n), .start(door_start), .done(door_done)
    );

    function automatic has_above(input [FLOORS-1:0] p, input [FLOOR_W-1:0] f);
        integer i;
        begin
            has_above = 1'b0;
            for (i = 0; i < FLOORS; i = i + 1)
                if (i > f && p[i]) has_above = 1'b1;
        end
    endfunction

    function automatic has_below(input [FLOORS-1:0] p, input [FLOOR_W-1:0] f);
        integer i;
        begin
            has_below = 1'b0;
            for (i = 0; i < FLOORS; i = i + 1)
                if (i < f && p[i]) has_below = 1'b1;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            floor_r     <= {FLOOR_W{1'b0}};
            move_cnt    <= {CNT_W{1'b0}};
            direction_r <= 1'b1;
        end else begin
            state       <= state_next;
            floor_r     <= floor_next;
            move_cnt    <= move_cnt_next;
            direction_r <= direction_next;
        end
    end

    always @(*) begin
        state_next     = state;
        floor_next     = floor_r;
        move_cnt_next  = move_cnt;
        direction_next = direction_r;
        clear_mask     = {FLOORS{1'b0}};
        door_start     = 1'b0;

        case (state)
            S_IDLE: begin
                if (pending[floor_r]) begin
                    state_next = S_DOOR_OPEN;
                    clear_mask = ({{(FLOORS-1){1'b0}}, 1'b1} << floor_r);
                    door_start = 1'b1;
                end else if (direction_r && has_above(pending, floor_r)) begin
                    state_next    = S_MOVE_UP;
                    move_cnt_next = {CNT_W{1'b0}};
                end else if (!direction_r && has_below(pending, floor_r)) begin
                    state_next    = S_MOVE_DOWN;
                    move_cnt_next = {CNT_W{1'b0}};
                end else if (has_above(pending, floor_r)) begin
                    state_next     = S_MOVE_UP;
                    move_cnt_next  = {CNT_W{1'b0}};
                    direction_next = 1'b1;
                end else if (has_below(pending, floor_r)) begin
                    state_next     = S_MOVE_DOWN;
                    move_cnt_next  = {CNT_W{1'b0}};
                    direction_next = 1'b0;
                end
            end

            S_MOVE_UP: begin
                if (move_cnt == MOVE_TIME[CNT_W-1:0] - 1'b1) begin
                    floor_next    = floor_r + 1'b1;
                    move_cnt_next = {CNT_W{1'b0}};
                    if (pending[floor_r + 1'b1]) begin
                        state_next = S_DOOR_OPEN;
                        clear_mask = ({{(FLOORS-1){1'b0}}, 1'b1} << (floor_r + 1'b1));
                        door_start = 1'b1;
                    end else if (has_above(pending, floor_r + 1'b1)) begin
                        state_next = S_MOVE_UP;
                    end else begin
                        state_next = S_IDLE;
                    end
                end else begin
                    move_cnt_next = move_cnt + 1'b1;
                end
            end

            S_MOVE_DOWN: begin
                if (move_cnt == MOVE_TIME[CNT_W-1:0] - 1'b1) begin
                    floor_next    = floor_r - 1'b1;
                    move_cnt_next = {CNT_W{1'b0}};
                    if (pending[floor_r - 1'b1]) begin
                        state_next = S_DOOR_OPEN;
                        clear_mask = ({{(FLOORS-1){1'b0}}, 1'b1} << (floor_r - 1'b1));
                        door_start = 1'b1;
                    end else if (has_below(pending, floor_r - 1'b1)) begin
                        state_next = S_MOVE_DOWN;
                    end else begin
                        state_next = S_IDLE;
                    end
                end else begin
                    move_cnt_next = move_cnt + 1'b1;
                end
            end

            S_DOOR_OPEN: begin
                if (door_done) state_next = S_IDLE;
            end

            default: state_next = S_IDLE;
        endcase
    end

    assign current_floor = floor_r;
    assign moving_up     = (state == S_MOVE_UP);
    assign moving_down   = (state == S_MOVE_DOWN);
    assign door_open     = (state == S_DOOR_OPEN);
    assign pending_out   = pending;

endmodule
