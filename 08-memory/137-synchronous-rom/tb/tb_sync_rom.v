`timescale 1ns / 1ps

// tb_sync_rom: for each address, checks (a) that `data` does NOT yet
// reflect the newly-presented address before the next clock edge --
// still showing the PREVIOUS address's value, proving the read is
// genuinely registered, not combinational -- and (b) that `data`
// matches the file's contents (read independently by the testbench)
// exactly one cycle after `addr` changes.
module tb_sync_rom;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg [3:0] addr;
    wire [7:0] data;

    sync_rom #(.ADDR_W(4), .DATA_W(8), .DEPTH(16)) dut (
        .clk(clk), .addr(addr), .data(data)
    );

    always #5 clk = ~clk;

    reg [7:0] ref_mem [0:15];
    initial $readmemh("data/rom.hex", ref_mem);

    integer i;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_sync_rom.vcd");
            $dumpvars(0, tb_sync_rom);
        end

        addr = 4'd0;
        @(posedge clk); #1;   // prime: data now holds mem[0]

        for (i = 1; i < 16; i = i + 1) begin
            addr = i[3:0];
            #1;   // settle time BEFORE the clock edge -- data must NOT change yet
            checks = checks + 1;
            if (data !== ref_mem[i-1]) begin
                errors = errors + 1;
                $display("ERROR: addr=%0d data changed before clock edge (not registered): data=%02h expected(prev)=%02h",
                          i, data, ref_mem[i-1]);
            end

            @(posedge clk); #1;   // one cycle later, data reflects the new address
            checks = checks + 1;
            if (data !== ref_mem[i]) begin
                errors = errors + 1;
                $display("ERROR: addr=%0d data=%02h expected=%02h", i, data, ref_mem[i]);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
