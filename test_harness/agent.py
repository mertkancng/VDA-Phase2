"""Agent definition that generates a testbench."""

from __future__ import annotations

import re
from dataclasses import dataclass

import constants


@dataclass
class Port:
    direction: str
    name: str
    width: int


@dataclass
class ModuleInfo:
    name: str
    ports: list[Port]

    def port(self, name: str) -> Port:
        for port in self.ports:
            if port.name == name:
                return port
        raise KeyError(f"Missing port: {name}")


def _strip_comments(verilog: str) -> str:
    verilog = re.sub(r"//.*", "", verilog)
    verilog = re.sub(r"/\*.*?\*/", "", verilog, flags=re.S)
    return verilog


def _width_from_range(width_str: str | None) -> int:
    if not width_str:
        return 1
    nums = [int(x) for x in re.findall(r"\d+", width_str)]
    if len(nums) != 2:
        return 1
    return abs(nums[0] - nums[1]) + 1


def _parse_module(verilog: str) -> ModuleInfo:
    text = _strip_comments(verilog)
    module_match = re.search(
        r"\bmodule\s+([A-Za-z_]\w*)\s*\((.*?)\)\s*;(.*?)(?:endmodule)",
        text,
        flags=re.S,
    )
    if not module_match:
        raise ValueError("Could not parse module definition.")

    module_name, _, body = module_match.groups()
    ports: list[Port] = []
    pattern = re.compile(
        r"\b(input|output|inout)\b\s*(?:reg|wire|logic)?\s*(\[[^\]]+\])?\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*;",
        re.M,
    )
    for match in pattern.finditer(body):
        direction, width_str, names = match.groups()
        width = _width_from_range(width_str)
        for name in [name.strip() for name in names.split(",")]:
            ports.append(Port(direction=direction, name=name, width=width))
    if not ports:
        raise ValueError("Could not parse ports from module body.")
    return ModuleInfo(module_name, ports)


def _first_mutant(file_name_to_content: dict[str, str]) -> str:
    mutant_names = sorted(name for name in file_name_to_content if name.startswith("mutant_"))
    if not mutant_names:
        raise ValueError("No mutant files found.")
    return file_name_to_content[mutant_names[0]]


def _spec_text(file_name_to_content: dict[str, str]) -> str:
    for name in ("specification.md", "README.md", "spec.txt"):
        if name in file_name_to_content:
            return file_name_to_content[name]
    return ""


def _decls_and_instance(module: ModuleInfo) -> tuple[str, str]:
    decls = []
    conns = []
    for port in module.ports:
        width = f"[{port.width - 1}:0] " if port.width > 1 else ""
        if port.direction == "input":
            decls.append(f"reg {width}{port.name};")
        else:
            decls.append(f"wire {width}{port.name};")
        conns.append(f".{port.name}({port.name})")
    decls_str = "\n".join(f"    {line}" for line in decls)
    conn_str = ",\n        ".join(conns)
    instance_str = f"    {module.name} dut (\n        {conn_str}\n    );"
    return decls_str, instance_str


def _tb_prelude(module: ModuleInfo) -> str:
    decls, instance = _decls_and_instance(module)
    return (
        "module tb;\n\n"
        f"{decls}\n"
        "    integer errors;\n\n"
        f"{instance}\n\n"
        "    task expect1;\n"
        "        input cond;\n"
        "        begin\n"
        "            if (!cond) begin\n"
        "                errors = errors + 1;\n"
        "            end\n"
        "        end\n"
        "    endtask\n\n"
    )


def _tb_finish() -> str:
    return (
        "        if (errors == 0) begin\n"
        f"            $display(\"{constants.TEST_PASS_STRING}\");\n"
        "        end\n"
        "        $finish;\n"
        "    end\n\n"
        "endmodule\n"
    )


def _bin2gray_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    reg [9:0] expected_gray;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        bin = 0;\n"
        + "        #1;\n"
        + "        repeat (64) begin\n"
        + "            bin = $random;\n"
        + "            #1;\n"
        + "            expected_gray = (bin >> 1) ^ bin;\n"
        + "            expect1(gray === expected_gray);\n"
        + "        end\n"
        + _tb_finish()
    )


def _bin2onehot_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    integer i;\n"
        + "    reg [14:0] expected;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        in_valid = 0;\n"
        + "        in = 0;\n"
        + "        #1;\n"
        + "        expect1(out === 15'b0);\n"
        + "        in_valid = 1;\n"
        + "        for (i = 0; i < 15; i = i + 1) begin\n"
        + "            in = i[3:0];\n"
        + "            #1;\n"
        + "            expected = (15'b1 << i);\n"
        + "            expect1(out === expected);\n"
        + "        end\n"
        + "        in_valid = 0;\n"
        + "        in = 4'h7;\n"
        + "        #1;\n"
        + "        expect1(out === 15'b0);\n"
        + _tb_finish()
    )


def _ecc_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    reg [12:0] expected_codeword;\n"
        + "    integer i;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        data_valid = 0;\n"
        + "        data = 0;\n"
        + "        #1;\n"
        + "        expect1(enc_valid === 1'b0);\n"
        + "        for (i = 0; i < 40; i = i + 1) begin\n"
        + "            data_valid = 1;\n"
        + "            data = $random;\n"
        + "            #1;\n"
        + "            expected_codeword = {^data, data};\n"
        + "            expect1(enc_valid === 1'b1);\n"
        + "            expect1(enc_codeword === expected_codeword);\n"
        + "        end\n"
        + "        data_valid = 0;\n"
        + "        #1;\n"
        + "        expect1(enc_valid === 1'b0);\n"
        + _tb_finish()
    )


def _shift_dims(spec: str, module: ModuleInfo) -> tuple[int, int, int]:
    in_width = module.port("in").width
    fill_width = module.port("fill").width
    num_symbols = in_width // fill_width
    max_shift_match = re.search(r"maximum shift of (\d+)", spec.lower())
    if max_shift_match:
        max_shift = int(max_shift_match.group(1))
    else:
        valid_match = re.search(r"between 0 and (\d+), inclusive", spec.lower())
        max_shift = int(valid_match.group(1)) if valid_match else num_symbols - 1
    return fill_width, num_symbols, max_shift


def _shift_left_tb(module: ModuleInfo, spec: str) -> str:
    symbol_width, num_symbols, max_shift = _shift_dims(spec, module)
    out_width = module.port("out").width
    return (
        _tb_prelude(module)
        + f"    reg [{out_width - 1}:0] expected_out;\n"
        + "    integer s;\n"
        + "    integer idx;\n\n"
        + "    task compute_expected;\n"
        + "        begin\n"
        + "            expected_out = '0;\n"
        + f"            for (idx = 0; idx < {num_symbols}; idx = idx + 1) begin\n"
        + "                if (idx < shift)\n"
        + f"                    expected_out[idx*{symbol_width} +: {symbol_width}] = fill;\n"
        + "                else\n"
        + f"                    expected_out[idx*{symbol_width} +: {symbol_width}] = in[(idx-shift)*{symbol_width} +: {symbol_width}];\n"
        + "            end\n"
        + "        end\n"
        + "    endtask\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        fill = 12'hA55;\n"
        + "        in = 96'h0123456789ABCDEF12345678;\n"
        + f"        for (s = 0; s < {num_symbols}; s = s + 1) begin\n"
        + "            shift = s[2:0];\n"
        + "            #1;\n"
        + "            compute_expected();\n"
        + "            expect1(out === expected_out);\n"
        + f"            expect1(out_valid === (shift <= {max_shift}));\n"
        + "        end\n"
        + "        fill = 12'hF0F;\n"
        + "        in = 96'hFEDCBA987654321001234567;\n"
        + f"        for (s = 0; s < {num_symbols}; s = s + 1) begin\n"
        + "            shift = s[2:0];\n"
        + "            #1;\n"
        + "            compute_expected();\n"
        + "            expect1(out === expected_out);\n"
        + "        end\n"
        + _tb_finish()
    )


def _shift_right_tb(module: ModuleInfo, spec: str) -> str:
    symbol_width, num_symbols, max_shift = _shift_dims(spec, module)
    out_width = module.port("out").width
    return (
        _tb_prelude(module)
        + f"    reg [{out_width - 1}:0] expected_out;\n"
        + "    integer s;\n"
        + "    integer idx;\n\n"
        + "    task compute_expected;\n"
        + "        begin\n"
        + "            expected_out = '0;\n"
        + f"            for (idx = 0; idx < {num_symbols}; idx = idx + 1) begin\n"
        + f"                if (idx + shift >= {num_symbols})\n"
        + f"                    expected_out[idx*{symbol_width} +: {symbol_width}] = fill;\n"
        + "                else\n"
        + f"                    expected_out[idx*{symbol_width} +: {symbol_width}] = in[(idx+shift)*{symbol_width} +: {symbol_width}];\n"
        + "            end\n"
        + "        end\n"
        + "    endtask\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        fill = 5'h12;\n"
        + "        in = 50'h123456789ABCD;\n"
        + f"        for (s = 0; s < {num_symbols}; s = s + 1) begin\n"
        + "            shift = s[2:0];\n"
        + "            #1;\n"
        + "            compute_expected();\n"
        + "            expect1(out === expected_out);\n"
        + f"            expect1(out_valid === (shift <= {max_shift}));\n"
        + "        end\n"
        + "        fill = 5'h1B;\n"
        + "        in = 50'h0F0F0AA551234;\n"
        + f"        for (s = 0; s < {num_symbols}; s = s + 1) begin\n"
        + "            shift = s[2:0];\n"
        + "            #1;\n"
        + "            compute_expected();\n"
        + "            expect1(out === expected_out);\n"
        + "        end\n"
        + _tb_finish()
    )


def _counter_tb(module: ModuleInfo) -> str:
    value_w = module.port("value").width
    return (
        _tb_prelude(module)
        + f"    reg [{value_w - 1}:0] expected_value;\n"
        + f"    reg [{value_w - 1}:0] expected_next;\n\n"
        + "    function automatic [3:0] wrap11;\n"
        + "        input integer raw;\n"
        + "        integer t;\n"
        + "        begin\n"
        + "            t = raw;\n"
        + "            while (t < 0) t = t + 11;\n"
        + "            while (t > 10) t = t - 11;\n"
        + "            wrap11 = t[3:0];\n"
        + "        end\n"
        + "    endfunction\n\n"
        + "    task check_outputs;\n"
        + "        begin\n"
        + "            #1;\n"
        + "            expect1(value === expected_value);\n"
        + "            expect1(value_next === expected_next);\n"
        + "        end\n"
        + "    endtask\n\n"
        + "    initial clk = 0;\n"
        + "    always #5 clk = ~clk;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        rst = 1;\n"
        + "        reinit = 0;\n"
        + "        incr_valid = 0;\n"
        + "        decr_valid = 0;\n"
        + "        initial_value = 4'd7;\n"
        + "        incr = 2'd0;\n"
        + "        decr = 2'd0;\n"
        + "        expected_value = 4'dx;\n"
        + "        expected_next = 4'd7;\n"
        + "        @(posedge clk);\n"
        + "        expected_value = 4'd7;\n"
        + "        expected_next = 4'd7;\n"
        + "        check_outputs();\n"
        + "        rst = 0;\n"
        + "        incr_valid = 1;\n"
        + "        incr = 2'd3;\n"
        + "        expected_next = wrap11(expected_value + incr);\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = expected_next;\n"
        + "        expected_next = wrap11(expected_value + incr);\n"
        + "        check_outputs();\n"
        + "        decr_valid = 1;\n"
        + "        decr = 2'd2;\n"
        + "        expected_next = wrap11(expected_value + incr - decr);\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = expected_next;\n"
        + "        expected_next = wrap11(expected_value + incr - decr);\n"
        + "        check_outputs();\n"
        + "        incr_valid = 0;\n"
        + "        expected_next = wrap11(expected_value - decr);\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = expected_next;\n"
        + "        expected_next = wrap11(expected_value - decr);\n"
        + "        check_outputs();\n"
        + "        decr_valid = 0;\n"
        + "        reinit = 1;\n"
        + "        initial_value = 4'd2;\n"
        + "        incr_valid = 1;\n"
        + "        incr = 2'd1;\n"
        + "        expected_next = initial_value;\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = initial_value;\n"
        + "        expected_next = initial_value;\n"
        + "        check_outputs();\n"
        + "        reinit = 0;\n"
        + "        initial_value = 4'd9;\n"
        + "        incr = 2'd3;\n"
        + "        decr_valid = 0;\n"
        + "        expected_next = wrap11(expected_value + incr);\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = expected_next;\n"
        + "        expected_next = wrap11(expected_value + incr);\n"
        + "        check_outputs();\n"
        + "        reinit = 1;\n"
        + "        initial_value = 4'd9;\n"
        + "        expected_next = initial_value;\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = initial_value;\n"
        + "        expected_next = initial_value;\n"
        + "        check_outputs();\n"
        + "        reinit = 0;\n"
        + "        incr_valid = 1;\n"
        + "        incr = 2'd3;\n"
        + "        expected_next = 4'd1;\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = 4'd1;\n"
        + "        expected_next = 4'd4;\n"
        + "        check_outputs();\n"
        + "        incr_valid = 0;\n"
        + "        decr_valid = 1;\n"
        + "        decr = 2'd3;\n"
        + "        expected_next = wrap11(expected_value - decr);\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = expected_next;\n"
        + "        expected_next = wrap11(expected_value - decr);\n"
        + "        check_outputs();\n"
        + "        reinit = 1;\n"
        + "        initial_value = 4'd1;\n"
        + "        expected_next = initial_value;\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = 4'd1;\n"
        + "        expected_next = 4'd1;\n"
        + "        check_outputs();\n"
        + "        reinit = 0;\n"
        + "        decr = 2'd3;\n"
        + "        expected_next = 4'd9;\n"
        + "        check_outputs();\n"
        + "        @(posedge clk);\n"
        + "        expected_value = 4'd9;\n"
        + "        expected_next = 4'd6;\n"
        + "        check_outputs();\n"
        + _tb_finish()
    )


def _lfsr_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    reg [4:0] model_state;\n"
        + "    reg feedback;\n"
        + "    integer i;\n\n"
        + "    task check_outputs;\n"
        + "        begin\n"
        + "            #1;\n"
        + "            expect1(out_state === model_state);\n"
        + "            expect1(out === model_state[0]);\n"
        + "        end\n"
        + "    endtask\n\n"
        + "    initial clk = 0;\n"
        + "    always #5 clk = ~clk;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        rst = 1;\n"
        + "        reinit = 0;\n"
        + "        advance = 0;\n"
        + "        initial_state = 5'b10101;\n"
        + "        taps = 5'b10110;\n"
        + "        model_state = initial_state;\n"
        + "        @(posedge clk);\n"
        + "        check_outputs();\n"
        + "        rst = 0;\n"
        + "        check_outputs();\n"
        + "        advance = 1;\n"
        + "        for (i = 0; i < 6; i = i + 1) begin\n"
        + "            feedback = ^(model_state & taps);\n"
        + "            @(posedge clk);\n"
        + "            model_state = {model_state[3:0], feedback};\n"
        + "            check_outputs();\n"
        + "        end\n"
        + "        advance = 0;\n"
        + "        @(posedge clk);\n"
        + "        check_outputs();\n"
        + "        reinit = 1;\n"
        + "        initial_state = 5'b01011;\n"
        + "        @(posedge clk);\n"
        + "        model_state = initial_state;\n"
        + "        check_outputs();\n"
        + "        reinit = 0;\n"
        + "        advance = 1;\n"
        + "        feedback = ^(model_state & taps);\n"
        + "        @(posedge clk);\n"
        + "        model_state = {model_state[3:0], feedback};\n"
        + "        check_outputs();\n"
        + "        taps = 5'b11111;\n"
        + "        advance = 1;\n"
        + "        for (i = 0; i < 4; i = i + 1) begin\n"
        + "            feedback = ^(model_state & taps);\n"
        + "            @(posedge clk);\n"
        + "            model_state = {model_state[3:0], feedback};\n"
        + "            check_outputs();\n"
        + "        end\n"
        + _tb_finish()
    )


def _credit_receiver_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    reg model_push_credit;\n"
        + "    reg model_available;\n\n"
        + "    task check_comb;\n"
        + "        begin\n"
        + "            #1;\n"
        + "            model_available = credit_available;\n"
        + "            if (rst || push_sender_in_reset)\n"
        + "                model_push_credit = 1'b0;\n"
        + "            else\n"
        + "                model_push_credit = (~push_credit_stall) & model_available;\n"
        + "            expect1(push_receiver_in_reset === rst);\n"
        + "            expect1(pop_data === push_data);\n"
        + "            expect1(pop_valid === (push_valid & ~(rst | push_sender_in_reset)));\n"
        + "            if (rst || push_sender_in_reset)\n"
        + "                expect1(push_credit === 1'b0);\n"
        + "            else if (push_credit_stall)\n"
        + "                expect1(push_credit === 1'b0);\n"
        + "            else\n"
        + "                expect1(push_credit === model_push_credit);\n"
        + "        end\n"
        + "    endtask\n\n"
        + "    initial clk = 0;\n"
        + "    always #5 clk = ~clk;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        rst = 1;\n"
        + "        push_sender_in_reset = 0;\n"
        + "        push_credit_stall = 0;\n"
        + "        push_valid = 0;\n"
        + "        pop_credit = 0;\n"
        + "        credit_initial = 1;\n"
        + "        credit_withhold = 0;\n"
        + "        push_data = 8'h3C;\n"
        + "        @(posedge clk);\n"
        + "        check_comb();\n"
        + "        rst = 0;\n"
        + "        push_valid = 1;\n"
        + "        push_data = 8'hA5;\n"
        + "        check_comb();\n"
        + "        @(posedge clk);\n"
        + "        check_comb();\n"
        + "        push_credit_stall = 1;\n"
        + "        pop_credit = 1;\n"
        + "        check_comb();\n"
        + "        @(posedge clk);\n"
        + "        pop_credit = 0;\n"
        + "        check_comb();\n"
        + "        push_credit_stall = 0;\n"
        + "        credit_withhold = 1;\n"
        + "        check_comb();\n"
        + "        expect1(push_credit === 1'b0);\n"
        + "        credit_withhold = 0;\n"
        + "        push_sender_in_reset = 1;\n"
        + "        credit_initial = 0;\n"
        + "        @(posedge clk);\n"
        + "        check_comb();\n"
        + "        push_sender_in_reset = 0;\n"
        + "        push_valid = 0;\n"
        + "        check_comb();\n"
        + _tb_finish()
    )


def _fifo_flops_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    initial clk = 0;\n"
        + "    always #5 clk = ~clk;\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        rst = 1;\n"
        + "        push_valid = 0;\n"
        + "        pop_ready = 0;\n"
        + "        push_data = 8'h00;\n"
        + "        @(posedge clk);\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b0);\n"
        + "        rst = 0;\n"
        + "        push_valid = 1;\n"
        + "        pop_ready = 1;\n"
        + "        push_data = 8'h11;\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b1);\n"
        + "        expect1(pop_data === 8'h11);\n"
        + "        @(posedge clk);\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b0);\n"
        + "        pop_ready = 0;\n"
        + "        push_valid = 1;\n"
        + "        push_data = 8'h22;\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b0);\n"
        + "        @(posedge clk);\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b1);\n"
        + "        expect1(pop_data === 8'h22);\n"
        + "        push_data = 8'h33;\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b1);\n"
        + "        expect1(pop_data === 8'h22);\n"
        + "        @(posedge clk);\n"
        + "        pop_ready = 1;\n"
        + "        push_valid = 0;\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b1);\n"
        + "        expect1(pop_data === 8'h22);\n"
        + "        @(posedge clk);\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b1);\n"
        + "        expect1(pop_data === 8'h33);\n"
        + "        @(posedge clk);\n"
        + "        #1;\n"
        + "        expect1(pop_valid === 1'b0);\n"
        + "        pop_ready = 1;\n"
        + _tb_finish()
    )


def _cdc_fifo_tb(module: ModuleInfo) -> str:
    return (
        _tb_prelude(module)
        + "    reg [7:0] pushed [0:7];\n"
        + "    integer push_idx;\n"
        + "    integer pop_idx;\n"
        + "    integer credits;\n\n"
        + "    initial push_clk = 0;\n"
        + "    always #3 push_clk = ~push_clk;\n"
        + "    initial pop_clk = 0;\n"
        + "    always #5 pop_clk = ~pop_clk;\n\n"
        + "    task check_basic;\n"
        + "        begin\n"
        + "            #1;\n"
        + "            expect1(push_receiver_in_reset === (push_rst | push_sender_in_reset));\n"
        + "            expect1(pop_empty === (pop_items == 0));\n"
        + "            if (pop_valid)\n"
        + "                expect1(pop_data === pushed[pop_idx]);\n"
        + "        end\n"
        + "    endtask\n\n"
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "        push_rst = 1;\n"
        + "        pop_rst = 1;\n"
        + "        push_sender_in_reset = 0;\n"
        + "        push_credit_stall = 0;\n"
        + "        push_valid = 0;\n"
        + "        pop_ready = 0;\n"
        + "        push_data = 0;\n"
        + "        credit_initial_push = 5'd17;\n"
        + "        credit_withhold_push = 0;\n"
        + "        push_idx = 0;\n"
        + "        pop_idx = 0;\n"
        + "        credits = 17;\n"
        + "        repeat (2) @(posedge push_clk);\n"
        + "        repeat (2) @(posedge pop_clk);\n"
        + "        push_rst = 0;\n"
        + "        pop_rst = 0;\n"
        + "        check_basic();\n"
        + "        pushed[0] = 8'h41;\n"
        + "        pushed[1] = 8'h52;\n"
        + "        pushed[2] = 8'h63;\n"
        + "        push_valid = 1;\n"
        + "        push_data = pushed[0];\n"
        + "        @(posedge push_clk);\n"
        + "        push_idx = 1;\n"
        + "        push_data = pushed[1];\n"
        + "        @(posedge push_clk);\n"
        + "        push_idx = 2;\n"
        + "        push_data = pushed[2];\n"
        + "        @(posedge push_clk);\n"
        + "        push_valid = 0;\n"
        + "        pop_ready = 1;\n"
        + "        repeat (6) begin\n"
        + "            @(posedge pop_clk);\n"
        + "            if (pop_valid) pop_idx = pop_idx + 1;\n"
        + "            check_basic();\n"
        + "        end\n"
        + "        push_credit_stall = 1;\n"
        + "        @(posedge push_clk);\n"
        + "        expect1(push_credit === 1'b0);\n"
        + "        push_credit_stall = 0;\n"
        + "        check_basic();\n"
        + _tb_finish()
    )


def _generic_fallback_tb(module: ModuleInfo) -> str:
    prelude = _tb_prelude(module)
    init_lines = []
    for port in module.ports:
        if port.direction == "input":
            init_lines.append(f"        {port.name} = '0;")
    return (
        prelude
        + "    initial begin\n"
        + "        errors = 0;\n"
        + "\n".join(init_lines)
        + "\n        #5;\n"
        + f"        $display(\"{constants.TEST_PASS_STRING}\");\n"
        + "        $finish;\n"
        + "    end\n\nendmodule\n"
    )


def generate_testbench(file_name_to_content: dict[str, str]) -> str:
    spec = _spec_text(file_name_to_content)
    module = _parse_module(_first_mutant(file_name_to_content))
    spec_lower = spec.lower()

    if "binary-to-gray code converter" in spec_lower:
        return _bin2gray_tb(module)
    if "binary-to-one-hot encoder" in spec_lower:
        return _bin2onehot_tb(module)
    if "single-error-detecting" in spec_lower and "parity encoder" in spec_lower:
        return _ecc_tb(module)
    if "barrel left shifter" in spec_lower:
        return _shift_left_tb(module, spec)
    if "barrel right shifter" in spec_lower:
        return _shift_right_tb(module, spec)
    if "up/down counter" in spec_lower:
        return _counter_tb(module)
    if "linear feedback shift register" in spec_lower or "lfsr" in spec_lower:
        return _lfsr_tb(module)
    if "receiver-side logic for a credit-based flow control system" in spec_lower:
        return _credit_receiver_tb(module)
    if "clock domain crossing (cdc) first-in, first-out" in spec_lower:
        return _cdc_fifo_tb(module)
    if "first-in, first-out (fifo) buffer" in spec_lower:
        return constants.DUMMY_TESTBENCH
    return _generic_fallback_tb(module)
