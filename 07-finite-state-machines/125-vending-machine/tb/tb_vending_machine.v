`timescale 1ns / 1ps

// tb_vending_machine: inserts directed and randomized coin sequences
// (one coin per cycle, one-hot), tracking an independent reference
// credit total, and checks `vend`/`change` exactly on the cycle credit
// reaches PRICE, plus that the machine correctly resets and accepts a
// fresh transaction immediately afterward.
module tb_vending_machine;

    localparam PRICE = 45;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg coin_5, coin_10, coin_25;
    wire vend;
    wire [7:0] change;
    wire [7:0] credit;

    vending_machine #(.PRICE(PRICE)) dut (
        .clk(clk), .rst_n(rst_n),
        .coin_5(coin_5), .coin_10(coin_10), .coin_25(coin_25),
        .vend(vend), .change(change), .credit(credit)
    );

    always #5 clk = ~clk;

    task do_reset;
        begin
            rst_n = 0; coin_5 = 0; coin_10 = 0; coin_25 = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    // insert one coin (value 5, 10 or 25) and check vend/change/credit
    // against the running reference for this transaction. `vended`
    // reports whether this coin triggered a vend (ref_credit is reset
    // to 0 by this task when it does) -- callers driving a while-loop
    // must key off `vended`, not `ref_credit`, since ref_credit is
    // zeroed the moment a vend happens.
    task insert_coin(input integer value, inout integer ref_credit, output integer vended);
        integer expected_change;
        begin
            @(negedge clk);
            coin_5 = (value == 5);
            coin_10 = (value == 10);
            coin_25 = (value == 25);
            @(posedge clk); #1;
            coin_5 = 0; coin_10 = 0; coin_25 = 0;

            ref_credit = ref_credit + value;
            vended = (ref_credit >= PRICE) ? 1 : 0;
            expected_change = vended ? (ref_credit - PRICE) : 0;

            checks = checks + 1;
            if (vend !== vended[0]) begin
                errors = errors + 1;
                $display("ERROR: after coin=%0d ref_credit=%0d vend=%b expected=%0d",
                          value, ref_credit, vend, vended);
            end
            if (vended) begin
                checks = checks + 1;
                if (change !== expected_change[7:0]) begin
                    errors = errors + 1;
                    $display("ERROR: after coin=%0d ref_credit=%0d change=%0d expected=%0d",
                              value, ref_credit, change, expected_change);
                end
                ref_credit = 0;   // machine resets on the vend cycle
            end else begin
                checks = checks + 1;
                if (credit !== ref_credit[7:0]) begin
                    errors = errors + 1;
                    $display("ERROR: after coin=%0d credit=%0d expected=%0d",
                              value, credit, ref_credit);
                end
            end
        end
    endtask

    // wait one idle cycle after a vend to confirm the machine settled
    // back to a clean, zero-credit idle state before the next purchase
    task confirm_idle;
        begin
            @(negedge clk); @(posedge clk); #1;
            checks = checks + 1;
            if (vend !== 1'b0 || credit !== 8'd0) begin
                errors = errors + 1;
                $display("ERROR: expected idle (vend=0, credit=0) after vend, got vend=%b credit=%0d",
                          vend, credit);
            end
        end
    endtask

    integer ref_credit;
    integer vended;
    integer seed = 32'hDEC0DE;
    integer r, coin_val, sel;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_vending_machine.vcd");
            $dumpvars(0, tb_vending_machine);
        end

        // Case 1: exact payment (25+10+10=45)
        do_reset; ref_credit = 0;
        insert_coin(25, ref_credit, vended);
        insert_coin(10, ref_credit, vended);
        insert_coin(10, ref_credit, vended);
        confirm_idle;

        // Case 2: overpayment (25+25=50, change=5)
        do_reset; ref_credit = 0;
        insert_coin(25, ref_credit, vended);
        insert_coin(25, ref_credit, vended);
        confirm_idle;

        // Case 3: many small coins (9x5=45)
        do_reset; ref_credit = 0;
        for (r = 0; r < 9; r = r + 1) insert_coin(5, ref_credit, vended);
        confirm_idle;

        // Case 4: overpay with mixed large coins (25+10+25=60, change=15).
        // Partial sums 25, 35, 60 never reach PRICE early, so all three
        // coins land while the machine is still accepting (unlike
        // 25+25+25, which would already vend after the 2nd coin here).
        do_reset; ref_credit = 0;
        insert_coin(25, ref_credit, vended);
        insert_coin(10, ref_credit, vended);
        insert_coin(25, ref_credit, vended);
        confirm_idle;

        // Case 5: two consecutive purchases, no reset between them
        do_reset; ref_credit = 0;
        insert_coin(25, ref_credit, vended);
        insert_coin(25, ref_credit, vended);   // vend #1, change=5
        confirm_idle;
        insert_coin(25, ref_credit, vended);
        insert_coin(10, ref_credit, vended);
        insert_coin(10, ref_credit, vended);   // vend #2, exact
        confirm_idle;

        // Case 6: randomized coin sequences, several full transactions
        for (r = 0; r < 40; r = r + 1) begin
            do_reset; ref_credit = 0; vended = 0;
            while (!vended) begin
                sel = $random(seed) % 3;
                coin_val = (sel == 0) ? 5 : (sel == 1) ? 10 : 25;
                insert_coin(coin_val, ref_credit, vended);
            end
            confirm_idle;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
