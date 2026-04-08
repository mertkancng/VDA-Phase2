module tb;

    reg [4:0] fill;
    reg [49:0] in;
    wire [49:0] out;
    wire out_valid;
    reg [2:0] shift;
    integer errors;

    shift_right dut (
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

    reg [49:0] expected_out;
    integer s;
    integer idx;

    task compute_expected;
        begin
            expected_out = '0;
            for (idx = 0; idx < 10; idx = idx + 1) begin
                if (idx + shift >= 10)
                    expected_out[idx*5 +: 5] = fill;
                else
                    expected_out[idx*5 +: 5] = in[(idx+shift)*5 +: 5];
            end
        end
    endtask

    initial begin
        errors = 0;
        fill = 5'h12;
        in = 50'h123456789ABCD;
        for (s = 0; s < 10; s = s + 1) begin
            shift = s[2:0];
            #1;
            compute_expected();
            expect1(out === expected_out);
            expect1(out_valid === (shift <= 4));
        end
        fill = 5'h1B;
        in = 50'h0F0F0AA551234;
        for (s = 0; s < 10; s = s + 1) begin
            shift = s[2:0];
            #1;
            compute_expected();
            expect1(out === expected_out);
        end
        in = 50'h3ab85bb07059a;
        fill = 5'h15;
        shift = 3'd2;
        #1;
        compute_expected();
        expect1(out === expected_out);
        expect1(out_valid === 1'b1);
        in = 50'h0000800000000;
        fill = 5'h00;
        shift = 3'd2;
        #1;
        compute_expected();
        expect1(out === expected_out);
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
