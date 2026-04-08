module tb;

    reg clk;
    wire empty;
    wire empty_next;
    wire full;
    wire full_next;
    wire [3:0] items;
    wire [3:0] items_next;
    wire [7:0] pop_data;
    reg pop_ready;
    wire pop_valid;
    reg [7:0] push_data;
    wire push_ready;
    reg push_valid;
    reg rst;
    wire [3:0] slots;
    wire [3:0] slots_next;
    integer errors;

    fifo_flops dut (
        .clk(clk),
        .empty(empty),
        .empty_next(empty_next),
        .full(full),
        .full_next(full_next),
        .items(items),
        .items_next(items_next),
        .pop_data(pop_data),
        .pop_ready(pop_ready),
        .pop_valid(pop_valid),
        .push_data(push_data),
        .push_ready(push_ready),
        .push_valid(push_valid),
        .rst(rst),
        .slots(slots),
        .slots_next(slots_next)
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

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst = 1;
        push_valid = 0;
        pop_ready = 0;
        push_data = 8'h00;
        @(posedge clk);
        #1;
        expect1(push_ready === 1'b1);
        expect1(pop_valid === 1'b0);
        expect1(empty === 1'b1);
        expect1(full === 1'b0);
        expect1(items === 4'd0);
        expect1(slots === 4'd13);
        rst = 0;
        push_valid = 1;
        pop_ready = 1;
        push_data = 8'h11;
        #1;
        expect1(pop_valid === 1'b1);
        expect1(pop_data === 8'h11);
        @(posedge clk);
        #1;
        expect1(empty === 1'b1);
        push_valid = 1;
        pop_ready = 0;
        push_data = 8'h08;
        #1;
        expect1(pop_valid === 1'b1);
        expect1(pop_data === 8'h08);
        @(posedge clk);
        push_valid = 0;
        pop_ready = 1;
        #1;
        expect1(pop_valid === 1'b1);
        expect1(pop_data === 8'h08);
        expect1(empty === 1'b0);
        @(posedge clk);
        rst = 1;
        push_valid = 0;
        pop_ready = 0;
        @(posedge clk);
        rst = 0;
        push_valid = 1;
        pop_ready = 0;
        for (i = 0; i < 13; i = i + 1) begin
            push_data = i[7:0];
            @(posedge clk);
        end
        push_valid = 0;
        #1;
        expect1(full === 1'b1);
        expect1(push_ready === 1'b0);
        expect1(pop_valid === 1'b1);
        expect1(empty === 1'b0);
        expect1(items === 4'd13);
        expect1(slots === 4'd0);
        expect1(pop_data === 8'h01);
        push_valid = 1;
        push_data = 8'hAA;
        #1;
        expect1(push_ready === 1'b0);
        expect1(items === 4'd13);
        pop_ready = 1;
        push_valid = 0;
        #1;
        expect1(pop_data === 8'h01);
        @(posedge clk);
        #1;
        expect1(items === 4'd12);
        expect1(empty === 1'b0);
        expect1(pop_data === 8'h01);
        @(posedge clk);
        #1;
        expect1(items === 4'd11);
        expect1(empty === 1'b0);
        expect1(pop_data === 8'h03);
        push_valid = 1;
        push_data = 8'hF0;
        #1;
        expect1(pop_data === 8'h03);
        @(posedge clk);
        #1;
        expect1(items === 4'd11);
        expect1(pop_data === 8'h03);
        if (errors == 0) begin
            $display("TESTS PASSED");
        end
        $finish;
    end

endmodule
