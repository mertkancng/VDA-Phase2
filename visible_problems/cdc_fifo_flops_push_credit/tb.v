module tb;

    wire [4:0] credit_available_push;
    wire [4:0] credit_count_push;
    reg [4:0] credit_initial_push;
    reg [4:0] credit_withhold_push;
    reg pop_clk;
    wire [7:0] pop_data;
    wire pop_empty;
    wire [4:0] pop_items;
    reg pop_ready;
    reg pop_rst;
    wire pop_valid;
    reg push_clk;
    wire push_credit;
    reg push_credit_stall;
    reg [7:0] push_data;
    wire push_full;
    wire push_receiver_in_reset;
    reg push_rst;
    reg push_sender_in_reset;
    wire [4:0] push_slots;
    reg push_valid;
    integer errors;

    cdc_fifo_flops_push_credit dut (
        .credit_available_push(credit_available_push),
        .credit_count_push(credit_count_push),
        .credit_initial_push(credit_initial_push),
        .credit_withhold_push(credit_withhold_push),
        .pop_clk(pop_clk),
        .pop_data(pop_data),
        .pop_empty(pop_empty),
        .pop_items(pop_items),
        .pop_ready(pop_ready),
        .pop_rst(pop_rst),
        .pop_valid(pop_valid),
        .push_clk(push_clk),
        .push_credit(push_credit),
        .push_credit_stall(push_credit_stall),
        .push_data(push_data),
        .push_full(push_full),
        .push_receiver_in_reset(push_receiver_in_reset),
        .push_rst(push_rst),
        .push_sender_in_reset(push_sender_in_reset),
        .push_slots(push_slots),
        .push_valid(push_valid)
    );

    task expect1;
        input cond;
        begin
            if (!cond) begin
                errors = errors + 1;
            end
        end
    endtask

    reg [7:0] pushed [0:7];
    integer push_idx;
    integer pop_idx;
    integer credits;

    initial push_clk = 0;
    always #3 push_clk = ~push_clk;
    initial pop_clk = 0;
    always #5 pop_clk = ~pop_clk;

    task check_basic;
        begin
            #1;
            expect1(push_receiver_in_reset === (push_rst | push_sender_in_reset));
            expect1(pop_empty === (pop_items == 0));
            if (pop_valid)
                expect1(pop_data === pushed[pop_idx]);
        end
    endtask

    initial begin
        errors = 0;
        push_rst = 1;
        pop_rst = 1;
        push_sender_in_reset = 0;
        push_credit_stall = 0;
        push_valid = 0;
        pop_ready = 0;
        push_data = 0;
        credit_initial_push = 5'd17;
        credit_withhold_push = 0;
        push_idx = 0;
        pop_idx = 0;
        credits = 17;
        repeat (2) @(posedge push_clk);
        repeat (2) @(posedge pop_clk);
        push_rst = 0;
        pop_rst = 0;
        check_basic();
        expect1(push_slots === 5'd17);
        expect1(credit_count_push === 5'd17);
        expect1(credit_available_push === 5'd17);
        expect1(push_full === 1'b0);
        pushed[0] = 8'h41;
        pushed[1] = 8'h52;
        pushed[2] = 8'h63;
        push_valid = 1;
        push_data = pushed[0];
        @(posedge push_clk);
        #1;
        expect1(push_slots === 5'd16);
        expect1(pop_data === 8'h41);
        push_idx = 1;
        push_data = pushed[1];
        @(posedge push_clk);
        #1;
        expect1(push_slots === 5'd15);
        expect1(pop_data === 8'h41);
        push_idx = 2;
        push_data = pushed[2];
        @(posedge push_clk);
        push_valid = 0;
        pop_ready = 1;
        repeat (6) begin
            @(posedge pop_clk);
            if (pop_valid) pop_idx = pop_idx + 1;
            check_basic();
        end
        push_credit_stall = 1;
        @(posedge push_clk);
        expect1(push_credit === 1'b0);
        push_credit_stall = 0;
        check_basic();
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
