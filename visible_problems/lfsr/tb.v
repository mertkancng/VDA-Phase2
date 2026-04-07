module tb;

    reg advance;
    reg clk;
    reg [4:0] initial_state;
    wire out;
    wire [4:0] out_state;
    reg reinit;
    reg rst;
    reg [4:0] taps;
    integer errors;

    lfsr dut (
        .advance(advance),
        .clk(clk),
        .initial_state(initial_state),
        .out(out),
        .out_state(out_state),
        .reinit(reinit),
        .rst(rst),
        .taps(taps)
    );

    task expect1;
        input cond;
        begin
            if (!cond) begin
                errors = errors + 1;
            end
        end
    endtask

    reg [4:0] model_state;
    reg feedback;
    integer i;

    task check_outputs;
        begin
            #1;
            expect1(out_state === model_state);
            expect1(out === model_state[0]);
        end
    endtask

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst = 1;
        reinit = 0;
        advance = 0;
        initial_state = 5'b10101;
        taps = 5'b10110;
        model_state = initial_state;
        @(posedge clk);
        check_outputs();
        rst = 0;
        check_outputs();
        advance = 1;
        for (i = 0; i < 6; i = i + 1) begin
            feedback = ^(model_state & taps);
            @(posedge clk);
            model_state = {model_state[3:0], feedback};
            check_outputs();
        end
        advance = 0;
        @(posedge clk);
        check_outputs();
        reinit = 1;
        initial_state = 5'b01011;
        @(posedge clk);
        model_state = initial_state;
        check_outputs();
        reinit = 0;
        advance = 1;
        feedback = ^(model_state & taps);
        @(posedge clk);
        model_state = {model_state[3:0], feedback};
        check_outputs();
        taps = 5'b11111;
        advance = 1;
        for (i = 0; i < 4; i = i + 1) begin
            feedback = ^(model_state & taps);
            @(posedge clk);
            model_state = {model_state[3:0], feedback};
            check_outputs();
        end
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
