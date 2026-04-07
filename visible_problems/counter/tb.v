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

    reg [3:0] expected_value;
    reg [3:0] expected_next;

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

    task check_outputs;
        begin
            #1;
            expect1(value === expected_value);
            expect1(value_next === expected_next);
        end
    endtask

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst = 1;
        reinit = 0;
        incr_valid = 0;
        decr_valid = 0;
        initial_value = 4'd7;
        incr = 2'd0;
        decr = 2'd0;
        expected_value = 4'dx;
        expected_next = 4'd7;
        @(posedge clk);
        expected_value = 4'd7;
        expected_next = 4'd7;
        check_outputs();
        rst = 0;
        incr_valid = 1;
        incr = 2'd3;
        expected_next = wrap11(expected_value + incr);
        check_outputs();
        @(posedge clk);
        expected_value = expected_next;
        expected_next = wrap11(expected_value + incr);
        check_outputs();
        decr_valid = 1;
        decr = 2'd2;
        expected_next = wrap11(expected_value + incr - decr);
        check_outputs();
        @(posedge clk);
        expected_value = expected_next;
        expected_next = wrap11(expected_value + incr - decr);
        check_outputs();
        incr_valid = 0;
        expected_next = wrap11(expected_value - decr);
        check_outputs();
        @(posedge clk);
        expected_value = expected_next;
        expected_next = wrap11(expected_value - decr);
        check_outputs();
        decr_valid = 0;
        reinit = 1;
        initial_value = 4'd2;
        incr_valid = 1;
        incr = 2'd1;
        expected_next = initial_value;
        check_outputs();
        @(posedge clk);
        expected_value = initial_value;
        expected_next = initial_value;
        check_outputs();
        reinit = 0;
        initial_value = 4'd9;
        incr = 2'd3;
        decr_valid = 0;
        expected_next = wrap11(expected_value + incr);
        check_outputs();
        @(posedge clk);
        expected_value = expected_next;
        expected_next = wrap11(expected_value + incr);
        check_outputs();
        reinit = 1;
        initial_value = 4'd9;
        expected_next = initial_value;
        check_outputs();
        @(posedge clk);
        expected_value = initial_value;
        expected_next = initial_value;
        check_outputs();
        reinit = 0;
        incr_valid = 1;
        incr = 2'd3;
        expected_next = 4'd1;
        check_outputs();
        @(posedge clk);
        expected_value = 4'd1;
        expected_next = 4'd4;
        check_outputs();
        incr_valid = 0;
        decr_valid = 1;
        decr = 2'd3;
        expected_next = wrap11(expected_value - decr);
        check_outputs();
        @(posedge clk);
        expected_value = expected_next;
        expected_next = wrap11(expected_value - decr);
        check_outputs();
        reinit = 1;
        initial_value = 4'd1;
        expected_next = initial_value;
        check_outputs();
        @(posedge clk);
        expected_value = 4'd1;
        expected_next = 4'd1;
        check_outputs();
        reinit = 0;
        decr = 2'd3;
        expected_next = 4'd9;
        check_outputs();
        @(posedge clk);
        expected_value = 4'd9;
        expected_next = 4'd6;
        check_outputs();
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
