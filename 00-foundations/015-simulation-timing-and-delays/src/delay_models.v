`timescale 1ns / 1ps

// delay_models  (simulation-only model, not synthesizable)
// Two ways to delay a signal by 5 ns:
//   inertial_out  : continuous assignment delay. A new value must persist for
//                   the full delay to reach the output, so pulses shorter
//                   than 5 ns are swallowed (like a real gate's inertia).
//   transport_out : non-blocking assignment with an intra-assignment delay.
//                   Every change is scheduled independently, so even a 2 ns
//                   pulse is reproduced 5 ns later (like a wire/delay line).
module delay_models (
    input  wire in_sig,
    output wire inertial_out,
    output reg  transport_out
);

    assign #5 inertial_out = in_sig;

    always @(in_sig)
        transport_out <= #5 in_sig;

endmodule
