`timescale 1ns / 1ps

// combination_lock: a 4-digit code-entry FSM. Each `enter` pulse
// presents one 4-bit digit; matching the fixed CODE_0..CODE_3 sequence
// in order unlocks the mechanism. A wrong digit at any position resets
// entry to the first digit and counts a failed attempt; after MAX_FAILS
// consecutive failures the lock enters a LOCKOUT state that ignores all
// input for LOCKOUT_TIME cycles before resetting the failure count and
// allowing entry again.
module combination_lock #(
    parameter [3:0] CODE_0 = 4'd3,
    parameter [3:0] CODE_1 = 4'd1,
    parameter [3:0] CODE_2 = 4'd4,
    parameter [3:0] CODE_3 = 4'd1,
    parameter MAX_FAILS   = 3,
    parameter LOCKOUT_TIME = 8
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enter,       // pulse: digit_in is valid this cycle
    input  wire [3:0] digit_in,
    input  wire       relock,      // pulse: re-lock from S_UNLOCKED
    output wire        unlocked,
    output wire        locked_out,
    output wire [1:0]  fail_count_out
);

    localparam CNT_W = $clog2(LOCKOUT_TIME + 1);

    localparam [2:0] S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3,
                      S_UNLOCKED = 3'd4, S_LOCKOUT = 3'd5;

    reg [2:0]       state, state_next;
    reg [1:0]       fail_count, fail_count_next;
    reg [CNT_W-1:0] lockout_cnt, lockout_cnt_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S0;
            fail_count  <= 2'd0;
            lockout_cnt <= {CNT_W{1'b0}};
        end else begin
            state       <= state_next;
            fail_count  <= fail_count_next;
            lockout_cnt <= lockout_cnt_next;
        end
    end

    // shared "wrong digit" outcome: retry from S0, or lock out once
    // MAX_FAILS consecutive failures have accumulated
    task automatic on_mismatch(output [2:0] ns, output [1:0] fc_next);
        begin
            fc_next = fail_count + 1'b1;
            if (fc_next >= MAX_FAILS[1:0]) ns = S_LOCKOUT;
            else                            ns = S0;
        end
    endtask

    always @(*) begin
        state_next       = state;
        fail_count_next  = fail_count;
        lockout_cnt_next = lockout_cnt;

        case (state)
            S0: if (enter) begin
                    if (digit_in == CODE_0) state_next = S1;
                    else                     on_mismatch(state_next, fail_count_next);
                end
            S1: if (enter) begin
                    if (digit_in == CODE_1) state_next = S2;
                    else                     on_mismatch(state_next, fail_count_next);
                end
            S2: if (enter) begin
                    if (digit_in == CODE_2) state_next = S3;
                    else                     on_mismatch(state_next, fail_count_next);
                end
            S3: if (enter) begin
                    if (digit_in == CODE_3) begin
                        state_next      = S_UNLOCKED;
                        fail_count_next = 2'd0;
                    end else on_mismatch(state_next, fail_count_next);
                end
            S_UNLOCKED: begin
                if (relock) state_next = S0;
            end
            S_LOCKOUT: begin
                if (lockout_cnt == LOCKOUT_TIME[CNT_W-1:0] - 1'b1) begin
                    state_next       = S0;
                    fail_count_next  = 2'd0;
                    lockout_cnt_next = {CNT_W{1'b0}};
                end else begin
                    lockout_cnt_next = lockout_cnt + 1'b1;
                end
            end
            default: state_next = S0;
        endcase
    end

    assign unlocked       = (state == S_UNLOCKED);
    assign locked_out      = (state == S_LOCKOUT);
    assign fail_count_out = fail_count;

endmodule
