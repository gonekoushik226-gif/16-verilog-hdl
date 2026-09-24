`timescale 1ns / 1ps

// car_direction_fsm: determines a car's direction of travel from the
// firing ORDER of two beam sensors placed a short distance apart
// (sensor_a = outer/entrance side, sensor_b = inner/lot side). A car
// entering breaks A, then both, then B alone (A cleared first), then
// clears both -- confirmed as `entry_pulse`. A car exiting does the
// mirror-image sequence -- confirmed as `exit_pulse`. A car that
// triggers only one sensor and then backs away without ever reaching
// "both active" is an aborted pass: the FSM returns to idle without
// pulsing either output.
module car_direction_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor_a,
    input  wire sensor_b,
    output reg  entry_pulse,
    output reg  exit_pulse
);

    localparam [2:0] S_IDLE    = 3'd0,
                      S_A_START = 3'd1,   // A alone: possible entry starting
                      S_B_START = 3'd2,   // B alone: possible exit starting
                      S_BOTH_A  = 3'd3,   // both active, arrived via A first (entering)
                      S_B_END_A = 3'd4,   // A cleared, B still active (entry finishing)
                      S_BOTH_B  = 3'd5,   // both active, arrived via B first (exiting)
                      S_A_END_B = 3'd6;   // B cleared, A still active (exit finishing)

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            entry_pulse <= 1'b0;
            exit_pulse  <= 1'b0;
        end else begin
            entry_pulse <= 1'b0;
            exit_pulse  <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (sensor_a && !sensor_b)      state <= S_A_START;
                    else if (!sensor_a && sensor_b) state <= S_B_START;
                end
                S_A_START: begin
                    if (sensor_a && sensor_b) state <= S_BOTH_A;
                    else if (!sensor_a)       state <= S_IDLE;   // aborted entry
                end
                S_B_START: begin
                    if (sensor_a && sensor_b) state <= S_BOTH_B;
                    else if (!sensor_b)       state <= S_IDLE;   // aborted exit
                end
                S_BOTH_A: begin
                    if (!sensor_a && sensor_b)      state <= S_B_END_A;  // normal progress
                    else if (sensor_a && !sensor_b) state <= S_IDLE;      // abnormal: fall back safely
                    else if (!sensor_a && !sensor_b) state <= S_IDLE;     // both cleared at once (glitch)
                end
                S_B_END_A: begin
                    if (!sensor_a && !sensor_b) begin
                        state       <= S_IDLE;
                        entry_pulse <= 1'b1;                      // entry confirmed
                    end else if (sensor_a && sensor_b) begin
                        state <= S_BOTH_A;
                    end else if (sensor_a && !sensor_b) begin
                        state <= S_IDLE;                           // abnormal: fall back safely
                    end
                end
                S_BOTH_B: begin
                    if (sensor_a && !sensor_b)       state <= S_A_END_B;  // normal progress
                    else if (!sensor_a && sensor_b)  state <= S_IDLE;      // abnormal fallback
                    else if (!sensor_a && !sensor_b) state <= S_IDLE;     // glitch
                end
                S_A_END_B: begin
                    if (!sensor_a && !sensor_b) begin
                        state      <= S_IDLE;
                        exit_pulse <= 1'b1;                        // exit confirmed
                    end else if (sensor_a && sensor_b) begin
                        state <= S_BOTH_B;
                    end else if (!sensor_a && sensor_b) begin
                        state <= S_IDLE;                            // abnormal fallback
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
