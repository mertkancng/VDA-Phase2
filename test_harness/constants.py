TESTBENCH_FILE_NAME = "tb.v"
TESTBENCH_MODULE_NAME = "tb"
TEST_PASS_STRING = "TESTS PASSED"
ANSWER_FILE_NAME = "null_mutant_id.txt"
DUMMY_TESTBENCH = """\
module tb;

    initial begin
        $display("TESTS PASSED");
        $finish;
    end

endmodule
"""
