`timescale 1ns / 1ps

module tb_address_decoder;

    localparam AW = 16;

    reg  [AW-1:0] addr;
    wire          cs_rom, cs_ram, cs_periph, cs_uart, error;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg [4:0] expected;   // {cs_rom, cs_ram, cs_periph, cs_uart, error}

    address_decoder #(.ADDR_WIDTH(AW)) dut (
        .addr(addr), .cs_rom(cs_rom), .cs_ram(cs_ram),
        .cs_periph(cs_periph), .cs_uart(cs_uart), .error(error)
    );

    function [4:0] model;
        input [AW-1:0] a;
        begin
            if (a >= 16'h0000 && a <= 16'h1FFF)      model = 5'b10000;
            else if (a >= 16'h2000 && a <= 16'h5FFF) model = 5'b01000;
            else if (a >= 16'h6000 && a <= 16'h6FFF) model = 5'b00100;
            else if (a >= 16'h7000 && a <= 16'h70FF) model = 5'b00010;
            else                                     model = 5'b00001;
        end
    endfunction

    task check(input [AW-1:0] a);
        begin
            addr = a;
            #1;
            expected = model(a);
            checks = checks + 1;
            if ({cs_rom, cs_ram, cs_periph, cs_uart, error} !== expected) begin
                errors = errors + 1;
                $display("ERROR: addr=%h expected {rom,ram,periph,uart,err}=%b actual=%b",
                          a, expected, {cs_rom, cs_ram, cs_periph, cs_uart, error});
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_address_decoder.vcd");
            $dumpvars(0, tb_address_decoder);
        end

        // Directed: every region's base and top boundary, plus the
        // addresses immediately outside each boundary (the classic
        // off-by-one decoder bug locations).
        $display("directed boundary checks:");
        check(16'h0000); check(16'h1FFF); check(16'h2000);           // ROM base/top, RAM base
        check(16'h5FFF); check(16'h6000);                            // RAM top, PERIPH base
        check(16'h6FFF); check(16'h7000);                            // PERIPH top, UART base
        check(16'h70FF); check(16'h7100);                            // UART top, first unmapped addr
        check(16'hFFFF);                                             // top of address space
        $display("  boundaries checked: %0d, errors so far: %0d", checks, errors);

        // Exhaustive: every one of the 65536 possible 16-bit addresses
        $display("exhaustive sweep of all %0d addresses...", 65536);
        for (i = 0; i < 65536; i = i + 1) begin
            check(i[AW-1:0]);
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
