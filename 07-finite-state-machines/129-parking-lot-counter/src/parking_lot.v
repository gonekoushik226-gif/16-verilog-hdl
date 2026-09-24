`timescale 1ns / 1ps

// parking_lot: wraps car_direction_fsm with a saturating occupancy
// counter. `entry_pulse` increments (clamped at CAPACITY), `exit_pulse`
// decrements (clamped at 0); `full` reflects the current count reaching
// CAPACITY.
module parking_lot #(
    parameter CAPACITY = 8,
    parameter WIDTH    = 4
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sensor_a,
    input  wire              sensor_b,
    output wire [WIDTH-1:0]  occupancy,
    output wire              full
);

    wire entry_pulse, exit_pulse;

    car_direction_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .sensor_a(sensor_a), .sensor_b(sensor_b),
        .entry_pulse(entry_pulse), .exit_pulse(exit_pulse)
    );

    reg [WIDTH-1:0] occ;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            occ <= {WIDTH{1'b0}};
        end else if (entry_pulse && !exit_pulse) begin
            if (occ < CAPACITY[WIDTH-1:0]) occ <= occ + 1'b1;
        end else if (exit_pulse && !entry_pulse) begin
            if (occ > {WIDTH{1'b0}}) occ <= occ - 1'b1;
        end
    end

    assign occupancy = occ;
    assign full       = (occ >= CAPACITY[WIDTH-1:0]);

endmodule
