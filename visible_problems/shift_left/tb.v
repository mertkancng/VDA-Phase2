module tb;

    reg [11:0] fill;
    reg [95:0] in;
    wire [95:0] out;
    wire out_valid;
    reg [2:0] shift;
    integer errors;

    shift_left dut (
        .fill(fill),
        .in(in),
        .out(out),
        .out_valid(out_valid),
        .shift(shift)
    );

    task expect1;
        input cond;
        begin
            if (!cond) begin
                errors = errors + 1;
            end
        end
    endtask

    reg [95:0] expected_out;
    integer s;
    integer idx;

    task compute_expected;
        begin
            expected_out = '0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                if (idx < shift)
                    expected_out[idx*12 +: 12] = fill;
                else
                    expected_out[idx*12 +: 12] = in[(idx-shift)*12 +: 12];
            end
        end
    endtask

    initial begin
        errors = 0;
        fill = 12'hA55;
        in = 96'h0123456789ABCDEF12345678;
        for (s = 0; s < 8; s = s + 1) begin
            shift = s[2:0];
            #1;
            compute_expected();
            expect1(out === expected_out);
            expect1(out_valid === (shift <= 5));
        end
        fill = 12'hF0F;
        in = 96'hFEDCBA987654321001234567;
        for (s = 0; s < 8; s = s + 1) begin
            shift = s[2:0];
            #1;
            compute_expected();
            expect1(out === expected_out);
        end
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
