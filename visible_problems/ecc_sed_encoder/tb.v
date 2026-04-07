module tb;

    reg clk;
    reg [11:0] data;
    reg data_valid;
    wire [12:0] enc_codeword;
    wire enc_valid;
    reg rst;
    integer errors;

    ecc_sed_encoder dut (
        .clk(clk),
        .data(data),
        .data_valid(data_valid),
        .enc_codeword(enc_codeword),
        .enc_valid(enc_valid),
        .rst(rst)
    );

    task expect1;
        input cond;
        begin
            if (!cond) begin
                errors = errors + 1;
            end
        end
    endtask

    reg [12:0] expected_codeword;
    integer i;

    initial begin
        errors = 0;
        data_valid = 0;
        data = 0;
        #1;
        expect1(enc_valid === 1'b0);
        for (i = 0; i < 40; i = i + 1) begin
            data_valid = 1;
            data = $random;
            #1;
            expected_codeword = {^data, data};
            expect1(enc_valid === 1'b1);
            expect1(enc_codeword === expected_codeword);
        end
        data_valid = 0;
        #1;
        expect1(enc_valid === 1'b0);
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
