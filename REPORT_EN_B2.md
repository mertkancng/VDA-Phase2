# VLSI Design Automation Phase 2 Report

## 1. Introduction

In this project, the goal was to build an agent that can write a Verilog testbench from a natural language RTL specification. The generated testbench should help us find the correct RTL implementation among 31 different versions of the same module.

The main target was simple: the testbench should pass for the correct design and fail for the wrong mutants as much as possible.

The core part of the solution was implemented in [agent.py](/Users/mertkan/Documents/New%20project/repo/test_harness/agent.py), inside the `generate_testbench(file_name_to_content)` function.

## 2. Problem Setup

Each problem folder includes:

- `specification.md`, which explains the module behavior in natural language
- `mutant_0.v` to `mutant_30.v`, which are 31 RTL implementations
- `tb.v`, which is the generated testbench

The evaluation flow compiles `tb.v` together with each mutant using `iverilog` and runs the simulation with `vvp`.

For the harness to accept the testbench:

- the top module name must be `tb`
- it must print `TESTS PASSED` when the test is successful
- it must end with `$finish`

## 3. Approach

I used a rule-based solution instead of a fully general AI system. This choice was practical because the deadline was short and the visible problems had clear families.

The agent works in the following way:

1. It reads the specification text.
2. It parses the module name and ports from one mutant file.
3. It tries to detect the problem family from the specification.
4. It generates a custom testbench for that family.

This approach is not fully generic, but it is fast, readable, and effective for the visible benchmark set.

## 4. System Design

The structure of the agent is based on small helper functions:

- one part reads the specification
- one part parses Verilog ports
- one part chooses the problem category
- one part creates the final Verilog testbench

Because the ports are parsed automatically, the generated testbench uses the correct signal names and widths without manual editing.

## 5. Supported Problem Types

The current agent generates dedicated testbenches for these visible problems:

- `enc_bin2gray`
- `enc_bin2onehot`
- `ecc_sed_encoder`
- `shift_left`
- `shift_right`
- `counter`
- `lfsr`
- `credit_receiver`
- `fifo_flops`
- `cdc_fifo_flops_push_credit`

## 6. Testbench Strategy

Different module types needed different verification styles.

### 6.1 Combinational Modules

For combinational modules such as `enc_bin2gray`, `enc_bin2onehot`, `ecc_sed_encoder`, `shift_left`, and `shift_right`, I used direct input/output checking.

In these testbenches:

- input vectors are applied directly
- expected outputs are calculated inside the testbench
- DUT outputs are compared against those expected values

This worked well because the behavior of these modules is clear and mathematical.

### 6.2 Sequential Modules

For sequential modules such as `counter` and `lfsr`, I added:

- clock generation
- reset handling
- directed control scenarios
- a small reference model inside the testbench

This made it possible to compare the internal behavior over time, not only in a single cycle.

### 6.3 Flow Control and FIFO Modules

For `credit_receiver`, `fifo_flops`, and `cdc_fifo_flops_push_credit`, the tests became more complex. These modules needed checks for:

- reset behavior
- handshake behavior
- data movement
- occupancy and credit logic
- selected corner cases that help separate mutants

These modules were harder because they include protocol behavior and timing relations between signals.

## 7. Results

I ran local visible-problem scans with `iverilog` and `vvp` and counted how many mutants still passed the generated testbench.

Final visible results:

- `enc_bin2gray`: 1 passing mutant
- `enc_bin2onehot`: 1 passing mutant
- `ecc_sed_encoder`: 1 passing mutant
- `shift_left`: 1 passing mutant
- `shift_right`: 1 passing mutant
- `lfsr`: 1 passing mutant
- `counter`: 1 passing mutant
- `credit_receiver`: 1 passing mutant
- `fifo_flops`: 1 passing mutant
- `cdc_fifo_flops_push_credit`: 18 passing mutants

This means the system isolated one candidate implementation in 9 out of 10 visible problems.

The weakest case was `cdc_fifo_flops_push_credit`. Even so, this module improved a lot compared to the earlier version of the solution.

## 8. Challenges

There were several important challenges during the project:

- some specifications were short and open to interpretation
- the mutant RTL files were difficult to read because they looked close to synthesized netlists
- the work had to be completed in a limited time
- stronger FIFO and CDC tests can sometimes reject the correct design together with the wrong ones

The CDC FIFO problem was the most difficult one because it combines state, protocol logic, and clock-domain interaction.

## 9. Limitations

This solution still has some limitations:

- it is based on known problem families
- it is not a fully general reasoning agent
- hidden problems may require better generalization
- the CDC FIFO case is still not selective enough

So, while the system is effective for most visible problems, it is not yet a complete universal verification agent.

## 10. Possible Improvements

This project can be improved in several ways:

- automatic reference-model generation from the natural language specification
- constrained-random test generation
- coverage-driven verification
- automatic search for mutant-distinguishing patterns
- iterative improvement using simulation feedback

In future work, combining rule-based generation with stronger AI reasoning could improve hidden-test performance.

## 11. Conclusion

This project produced a working testbench-generation agent for the provided Phase 2 framework. The system reads the problem files, identifies the module family, and returns a complete Verilog testbench that is compatible with the given harness.

The final result is strong on combinational and many sequential problems. It also improved difficult protocol-based problems such as `credit_receiver` and `fifo_flops`. The only remaining weak case is `cdc_fifo_flops_push_credit`, which still needs a stronger CDC-aware reference strategy.

Overall, the submission provides a complete, automated, and reproducible Phase 2 solution.
