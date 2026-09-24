`timescale 1ns / 1ps

// barrel_rotator: rotates data left or right by shamt positions using the
// "double-width" trick: concatenating data with itself turns a circular
// rotation into a plain (non-wrapping) WIDTH-bit window read out of a
// 2*WIDTH-bit value, avoiding any explicit wrap-around logic.
module barrel_rotator #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]         data,
    input  wire [$clog2(WIDTH)-1:0] shamt,
    input  wire                     left,   // 1 = rotate left, 0 = rotate right
    output wire [WIDTH-1:0]         result
);

    // {data,data}: upper WIDTH bits and lower WIDTH bits are both a copy
    // of data, so any WIDTH-bit window of this 2*WIDTH-bit value that
    // stays within bounds is automatically the correctly wrapped rotation.
    wire [2*WIDTH-1:0] doubled = {data, data};

    // rotate left by n:  window starts n bits below the top copy
    // rotate right by n: window starts n bits above the bottom copy
    assign result = left ? doubled[(2*WIDTH-1-shamt) -: WIDTH]
                          : doubled[(WIDTH-1+shamt)   -: WIDTH];

endmodule
