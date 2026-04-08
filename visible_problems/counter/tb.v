module tb;

    reg clk;
    reg [1:0] decr;
    reg decr_valid;
    reg [1:0] incr;
    reg incr_valid;
    reg [3:0] initial_value;
    reg reinit;
    reg rst;
    wire [3:0] value;
    wire [3:0] value_next;
    integer errors;

    counter dut (
        .clk(clk),
        .decr(decr),
        .decr_valid(decr_valid),
        .incr(incr),
        .incr_valid(incr_valid),
        .initial_value(initial_value),
        .reinit(reinit),
        .rst(rst),
        .value(value),
        .value_next(value_next)
    );

    task expect1;
        input cond;
        begin
            if (!cond) begin
                errors = errors + 1;
            end
        end
    endtask

    integer cur;
    integer initv;
    integer incv;
    integer decv;
    integer expected_next;

    function automatic [3:0] wrap11;
        input integer raw;
        integer t;
        begin
            t = raw;
            while (t < 0) t = t + 11;
            while (t > 10) t = t - 11;
            wrap11 = t[3:0];
        end
    endfunction

    task run_case;
        input integer cur_in;
        input integer init_in;
        input integer reinit_in;
        input integer incr_valid_in;
        input integer decr_valid_in;
        input integer incr_in;
        input integer decr_in;
        begin
            rst = 1;
            initial_value = cur_in[3:0];
            reinit = 0;
            incr_valid = 0;
            decr_valid = 0;
            incr = 0;
            decr = 0;
            @(posedge clk);
            rst = 0;
            initial_value = init_in[3:0];
            reinit = reinit_in;
            incr_valid = incr_valid_in;
            decr_valid = decr_valid_in;
            incr = incr_in[1:0];
            decr = decr_in[1:0];
            if (reinit_in)
                expected_next = init_in;
            else
                expected_next = wrap11(cur_in + (incr_valid_in ? incr_in : 0) - (decr_valid_in ? decr_in : 0));
            #1;
            expect1(value === cur_in[3:0]);
            expect1(value_next === expected_next[3:0]);
            @(posedge clk);
            #1;
            expect1(value === expected_next[3:0]);
        end
    endtask

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        for (cur = 0; cur <= 10; cur = cur + 1) begin
            for (initv = 0; initv <= 10; initv = initv + 1) begin
                run_case(cur, initv, 1, 0, 0, 0, 0);
                run_case(cur, initv, 1, 1, 1, 3, 2);
                for (incv = 0; incv < 4; incv = incv + 1) begin
                    for (decv = 0; decv < 4; decv = decv + 1) begin
                        run_case(cur, initv, 0, 0, 0, incv, decv);
                        run_case(cur, initv, 0, 1, 0, incv, decv);
                        run_case(cur, initv, 0, 0, 1, incv, decv);
                        run_case(cur, initv, 0, 1, 1, incv, decv);
                    end
                end
            end
        end
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
