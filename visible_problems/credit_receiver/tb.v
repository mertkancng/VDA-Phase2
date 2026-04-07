module tb;

    reg clk;
    wire credit_available;
    wire credit_count;
    reg credit_initial;
    reg credit_withhold;
    reg pop_credit;
    wire [7:0] pop_data;
    wire pop_valid;
    wire push_credit;
    reg push_credit_stall;
    reg [7:0] push_data;
    wire push_receiver_in_reset;
    reg push_sender_in_reset;
    reg push_valid;
    reg rst;
    integer errors;

    credit_receiver dut (
        .clk(clk),
        .credit_available(credit_available),
        .credit_count(credit_count),
        .credit_initial(credit_initial),
        .credit_withhold(credit_withhold),
        .pop_credit(pop_credit),
        .pop_data(pop_data),
        .pop_valid(pop_valid),
        .push_credit(push_credit),
        .push_credit_stall(push_credit_stall),
        .push_data(push_data),
        .push_receiver_in_reset(push_receiver_in_reset),
        .push_sender_in_reset(push_sender_in_reset),
        .push_valid(push_valid),
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

    reg model_push_credit;
    reg model_available;

    task check_comb;
        begin
            #1;
            model_available = credit_available;
            if (rst || push_sender_in_reset)
                model_push_credit = 1'b0;
            else
                model_push_credit = (~push_credit_stall) & model_available;
            expect1(push_receiver_in_reset === rst);
            expect1(pop_data === push_data);
            expect1(pop_valid === (push_valid & ~(rst | push_sender_in_reset)));
            if (rst || push_sender_in_reset)
                expect1(push_credit === 1'b0);
            else if (push_credit_stall)
                expect1(push_credit === 1'b0);
            else
                expect1(push_credit === model_push_credit);
        end
    endtask

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst = 1;
        push_sender_in_reset = 0;
        push_credit_stall = 0;
        push_valid = 0;
        pop_credit = 0;
        credit_initial = 1;
        credit_withhold = 0;
        push_data = 8'h3C;
        @(posedge clk);
        check_comb();
        rst = 0;
        push_valid = 1;
        push_data = 8'hA5;
        check_comb();
        @(posedge clk);
        check_comb();
        push_credit_stall = 1;
        pop_credit = 1;
        check_comb();
        @(posedge clk);
        pop_credit = 0;
        check_comb();
        push_credit_stall = 0;
        credit_withhold = 1;
        check_comb();
        expect1(push_credit === 1'b0);
        credit_withhold = 0;
        push_sender_in_reset = 1;
        credit_initial = 0;
        @(posedge clk);
        check_comb();
        push_sender_in_reset = 0;
        push_valid = 0;
        check_comb();
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
