# VLSI Design Automation Phase 2 Report

## 1. Project Goal

The goal of this project is to build an agent that can automatically generate a Verilog testbench from a natural-language RTL specification. The generated testbench is expected to distinguish the correct design from 31 RTL implementations of the same module. In other words, the testbench should pass on the correct implementation and reject as many incorrect mutants as possible.

The main implementation point is the `generate_testbench(file_name_to_content)` function in [agent.py](/Users/mertkan/Documents/New%20project/repo/test_harness/agent.py).

## 2. Problem Definition

Each problem directory contains the following files:

- `specification.md`: natural-language description of the RTL behavior
- `mutant_0.v` ... `mutant_30.v`: 31 RTL implementations of the same module
- `tb.v`: generated or provided testbench

The evaluation harness compiles `tb.v` with each mutant using `iverilog` and simulates the result. For a testbench to be accepted by the harness:

- the module name must be `tb`
- it must print exactly `TESTS PASSED` on success
- it must terminate with `$finish`

## 3. Implemented Approach

This submission uses a rule-based testbench generation approach. The agent receives all files in a problem directory, reads the specification text, and extracts the module interface from the first mutant file.

The specification is then classified into a known problem family, and a family-specific testbench template is generated. This is not a fully general LLM verification agent; instead, it is a practical and fast solution optimized for the visible benchmark families under submission-time constraints.

## 4. Architecture

The flow inside `agent.py` is:

1. Read the `specification.md` content from the problem directory.
2. Parse the module name and ports from `mutant_0.v`.
3. Classify the problem using key phrases from the specification.
4. Call a problem-specific testbench generator.
5. Return a complete Verilog `tb` module.

Because the interface is parsed automatically, signal widths and module names are inserted into the generated testbench without manual editing.

## 5. Supported Problem Families

The agent currently generates custom testbenches for the following visible problem families:

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

## 6. Testbench Generation Strategy

Directed tests were written for each problem family according to the behavior described in the specification.

### 6.1 Combinational Modules

For combinational modules such as `enc_bin2gray`, `enc_bin2onehot`, `ecc_sed_encoder`, `shift_left`, and `shift_right`:

- input vectors are assigned directly
- expected outputs are computed inside the testbench
- DUT outputs are compared against reference values

Because these modules have explicit mathematical behavior, this category achieved the highest selectivity.

### 6.2 Sequential Modules

For sequential modules such as `counter` and `lfsr`:

- clocks are generated in the testbench
- reset and control scenarios are exercised explicitly
- a lightweight internal reference model is maintained in the testbench

### 6.3 Flow-Control and FIFO-Style Modules

For `credit_receiver`, `fifo_flops`, and `cdc_fifo_flops_push_credit`:

- reset behavior is checked
- handshake behavior is checked
- data-path behavior is checked
- credit, occupancy, and buffering behavior is checked
- targeted mutant-discriminating scenarios are applied

These modules are harder because they combine state, timing, and protocol behavior. As a result, they are more difficult to separate with a short handcrafted testbench.

## 7. Experimental Results

Visible-problem mutant scans were run locally using `iverilog` and `vvp`. For each problem, the number of mutants that still passed the generated testbench was recorded.

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

These results show that the generated testbenches identify a single candidate implementation for 9 out of 10 visible problems. The remaining hard case is `cdc_fifo_flops_push_credit`, which improved substantially compared with earlier attempts, but still remains less selective than the other visible benchmarks.

## 8. Challenges

The main challenges in this project were:

- some natural-language specifications are incomplete or open to interpretation
- the mutant RTL files are difficult to read because they resemble synthesized or gate-level style netlists
- the solution had to be implemented quickly while still producing selective testbenches
- stateful FIFO and CDC modules are difficult because strong filtering can accidentally reject the correct implementation

The hardest remaining family is `cdc_fifo_flops_push_credit`, which would benefit from a stronger reference model and deeper protocol-aware checking.

## 9. Limitations

The current solution has the following limitations:

- it does not use a general semantic parser or a fully autonomous LLM planning loop
- generation is based on recognized problem families, so hidden-case generalization is limited
- selectivity is still weak for the hardest CDC problem
- the approach is intentionally pragmatic rather than fully generic

## 10. Future Improvements

A stronger version of this project could include:

- automatic extraction of a reference model from the natural-language specification
- symbolic or constrained-random test generation
- coverage-driven testbench generation
- automatic search for distinguishing patterns across mutants
- iterative refinement based on simulation feedback

In particular, hidden-problem performance would likely improve if the current rule-based approach were combined with reasoning and simulation-guided adaptation.

## 11. Conclusion

This project delivers a working testbench-generation agent compatible with the provided hackathon harness. The system operates through `generate_testbench(file_name_to_content)` and constructs full Verilog testbenches from the specification and mutant RTL files.

The results are strong on clearly defined combinational and sequential modules, and significantly improved on several stateful modules. While the CDC FIFO credit problem is still not fully solved, the overall Phase 2 pipeline is complete, automated, and reproducible.
