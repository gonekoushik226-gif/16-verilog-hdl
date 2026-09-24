`timescale 1ns / 1ps

// hs_link: connects hs_sender and hs_receiver back to back through
// their req/ack/data wires, exposing a simple data_valid/data_in ...
// data_out/data_ready interface at each end -- the internal req/ack
// handshake is entirely hidden from the link's users.
module hs_link #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             data_valid,
    input  wire [WIDTH-1:0] data_in,
    output wire             busy,
    output wire [WIDTH-1:0] data_out,
    output wire             data_ready
);

    wire             req, ack;
    wire [WIDTH-1:0] link_data;

    hs_sender #(.WIDTH(WIDTH)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .data_valid(data_valid), .data_in(data_in), .ack(ack),
        .req(req), .data_out(link_data), .busy(busy)
    );

    hs_receiver #(.WIDTH(WIDTH)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .req(req), .data_in(link_data), .ack(ack),
        .data_out(data_out), .data_ready(data_ready)
    );

endmodule
