`timescale 1ns / 1ps

// tb_hs_link: (1) a white-box protocol monitor watching the internal
// req/ack pair (via hierarchical reference into the DUT) every cycle,
// checking every transition follows the legal four-phase cycle
// 00 -> 10 -> 11 -> 01 -> 00 and never anything else; (2) a black-box
// data-integrity check sending a sequence of words (pacing on `busy`)
// and comparing the received sequence, captured on `data_ready`,
// against what was sent, in order.
module tb_hs_link;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg data_valid;
    reg [WIDTH-1:0] data_in;
    wire busy;
    wire [WIDTH-1:0] data_out;
    wire data_ready;

    hs_link #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .data_valid(data_valid), .data_in(data_in),
        .busy(busy), .data_out(data_out), .data_ready(data_ready)
    );

    always #5 clk = ~clk;

    // --- protocol monitor: req/ack must only ever follow
    // 00 -> 10 -> 11 -> 01 -> 00 (the four-phase cycle) ---
    reg [1:0] prev_ra;
    reg       monitor_en = 1'b0;

    always @(posedge clk) begin
        #1;
        if (monitor_en) begin
            checks = checks + 1;
            case (prev_ra)
                2'b00: if (!(dut.req == 1'b0 && dut.ack == 1'b0) && !(dut.req == 1'b1 && dut.ack == 1'b0)) begin
                    errors = errors + 1;
                    $display("ERROR: protocol violation from 00 to req=%b ack=%b", dut.req, dut.ack);
                end
                2'b10: if (!(dut.req == 1'b1 && dut.ack == 1'b0) && !(dut.req == 1'b1 && dut.ack == 1'b1)) begin
                    errors = errors + 1;
                    $display("ERROR: protocol violation from 10 to req=%b ack=%b", dut.req, dut.ack);
                end
                2'b11: if (!(dut.req == 1'b1 && dut.ack == 1'b1) && !(dut.req == 1'b0 && dut.ack == 1'b1)) begin
                    errors = errors + 1;
                    $display("ERROR: protocol violation from 11 to req=%b ack=%b", dut.req, dut.ack);
                end
                2'b01: if (!(dut.req == 1'b0 && dut.ack == 1'b1) && !(dut.req == 1'b0 && dut.ack == 1'b0)) begin
                    errors = errors + 1;
                    $display("ERROR: protocol violation from 01 to req=%b ack=%b", dut.req, dut.ack);
                end
            endcase
            prev_ra = {dut.req, dut.ack};
        end
    end

    // --- receive-side capture queue ---
    reg [WIDTH-1:0] rx_queue [0:63];
    integer rx_count = 0;
    always @(posedge clk) begin
        #1;
        if (data_ready) begin
            rx_queue[rx_count] = data_out;
            rx_count = rx_count + 1;
        end
    end

    task do_reset;
        begin
            rst_n = 0; data_valid = 0; data_in = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
            @(negedge clk);
            prev_ra = 2'b00;
            monitor_en = 1'b1;
        end
    endtask

    task send_word(input [WIDTH-1:0] w);
        integer watchdog;
        begin
            watchdog = 0;
            while (busy) begin
                @(posedge clk); #1;
                watchdog = watchdog + 1;
                if (watchdog > 200) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout waiting for sender idle");
                end
            end
            @(negedge clk);
            data_valid = 1'b1; data_in = w;
            @(posedge clk); #1;
            data_valid = 1'b0;
        end
    endtask

    integer i;
    reg [WIDTH-1:0] sent [0:63];
    integer sent_count;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_hs_link.vcd");
            $dumpvars(0, tb_hs_link);
        end

        do_reset;
        sent_count = 0;

        // ordered sequence of transfers, including back-to-back sends
        // (each send_word waits for !busy, so this paces correctly to
        // the receiver's own four-phase completion time)
        for (i = 0; i < 20; i = i + 1) begin
            sent[sent_count] = (i * 17 + 3) & 8'hFF;
            send_word(sent[sent_count]);
            sent_count = sent_count + 1;
        end

        // let the final transfer's fourth phase fully complete
        repeat (10) begin @(posedge clk); #1; end

        checks = checks + 1;
        if (rx_count !== sent_count) begin
            errors = errors + 1;
            $display("ERROR: received %0d words, expected %0d", rx_count, sent_count);
        end

        for (i = 0; i < sent_count && i < rx_count; i = i + 1) begin
            checks = checks + 1;
            if (rx_queue[i] !== sent[i]) begin
                errors = errors + 1;
                $display("ERROR: word #%0d received=%0d expected=%0d", i, rx_queue[i], sent[i]);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
