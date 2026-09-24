`timescale 1ns / 1ps

// tristate_buffer: enable-controlled driver built from the built-in
// bufif1 primitive. When enable=1 the output follows a; when enable=0 the
// output is high-impedance (1'bz), i.e. electrically disconnected.
module tristate_buffer (
    input  wire a,
    input  wire enable,
    output wire y
);

    // bufif1(out, in, control): drives `in` onto `out` while control=1,
    // else drives high-impedance z.
    bufif1 u_tri (y, a, enable);

endmodule
