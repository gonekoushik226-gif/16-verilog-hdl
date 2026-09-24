`timescale 1ns / 1ps

// shared_bus: two tristate_buffer drivers connected to one shared net,
// modelling a classic shared bus with two agents. Only one driver should
// be enabled at a time; enabling both with differing data creates a real
// electrical contention, which Verilog models as an unknown (x) value.
module shared_bus (
    input  wire data_a,
    input  wire enable_a,
    input  wire data_b,
    input  wire enable_b,
    output wire bus
);

    tristate_buffer u_drv_a (.a(data_a), .enable(enable_a), .y(bus));
    tristate_buffer u_drv_b (.a(data_b), .enable(enable_b), .y(bus));

endmodule
