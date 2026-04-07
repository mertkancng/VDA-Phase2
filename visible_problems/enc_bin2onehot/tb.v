module tb;

    reg clk;
    reg [3:0] in;
    reg in_valid;
    wire [14:0] out;
    reg rst;
    integer errors;

    enc_bin2onehot dut (
        .clk(clk),
        .in(in),
        .in_valid(in_valid),
        .out(out),
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

    integer i;
    reg [14:0] expected;

    initial begin
        errors = 0;
        in_valid = 0;
        in = 0;
        #1;
        expect1(out === 15'b0);
        in_valid = 1;
        for (i = 0; i < 15; i = i + 1) begin
            in = i[3:0];
            #1;
            expected = (15'b1 << i);
            expect1(out === expected);
        end
        in_valid = 0;
        in = 4'h7;
        #1;
        expect1(out === 15'b0);
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
