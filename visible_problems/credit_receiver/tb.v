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

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst = 1;
        push_sender_in_reset = 0;
        push_credit_stall = 0;
        push_valid = 1;
        pop_credit = 0;
        credit_initial = 0;
        credit_withhold = 0;
        push_data = 8'h00;
        #1;
        expect1(push_receiver_in_reset === 1'b1);
        expect1(pop_valid === 1'b0);
        expect1(push_credit === 1'b0);
        @(posedge clk);
        #1;
        expect1(credit_count === 1'b0);
        expect1(credit_available === 1'b0);
        rst = 0;
        #1;
        expect1(push_receiver_in_reset === 1'b0);
        expect1(pop_valid === 1'b1);
        expect1(pop_data === 8'h00);
        expect1(push_credit === 1'b0);
        push_credit_stall = 1;
        push_valid = 0;
        pop_credit = 1;
        push_data = 8'h20;
        @(posedge clk);
        pop_credit = 0;
        #1;
        expect1(credit_count === 1'b1);
        expect1(credit_available === 1'b1);
        expect1(push_credit === 1'b0);
        credit_withhold = 1;
        #1;
        expect1(credit_count === 1'b1);
        expect1(credit_available === 1'b0);
        expect1(push_credit === 1'b0);
        credit_withhold = 0;
        push_credit_stall = 0;
        push_valid = 1;
        push_data = 8'h55;
        #1;
        expect1(pop_valid === 1'b1);
        expect1(pop_data === 8'h55);
        expect1(push_credit === 1'b1);
        @(posedge clk);
        #1;
        expect1(credit_count === 1'b0);
        expect1(credit_available === 1'b0);
        push_sender_in_reset = 1;
        credit_initial = 1;
        credit_withhold = 1;
        push_valid = 1;
        push_data = 8'h5A;
        #1;
        expect1(push_receiver_in_reset === 1'b0);
        expect1(pop_valid === 1'b0);
        expect1(push_credit === 1'b0);
        @(posedge clk);
        #1;
        expect1(credit_count === 1'b1);
        expect1(credit_available === 1'b0);
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
