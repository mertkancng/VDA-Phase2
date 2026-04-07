module tb;

    reg [9:0] bin;
    wire [9:0] gray;
    integer errors;

    enc_bin2gray dut (
        .bin(bin),
        .gray(gray)
    );

    task expect1;
        input cond;
        begin
            if (!cond) begin
                errors = errors + 1;
            end
        end
    endtask

    reg [9:0] expected_gray;

    initial begin
        errors = 0;
        bin = 0;
        #1;
        repeat (64) begin
            bin = $random;
            #1;
            expected_gray = (bin >> 1) ^ bin;
            expect1(gray === expected_gray);
        end
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
