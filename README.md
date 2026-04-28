# Google Track Verification Agent #

Team DesignEEErs

Codex-based Verilog testbench generation and evaluation for visible Google Track verification problems.

## Team

Team DesignEEErs

This is a group project for Topic 2: AI for Design Verification (Google Track).

### Members

- Arda Suhedar
- Mertkan Riza Yulu

This repository is the project repository of Team DesignEEErs for Topic 2: AI for Design Verification (Google Track).
Its purpose is to drive a Codex-based workflow that reads a natural language hardware problem, generates a Verilog testbench, and evaluates that testbench against RTL candidates from the professor-provided benchmark repository.

The benchmark repository is treated as an external dataset.
This repo should contain the agent workflow, prompts, local experiment artifacts, and notes.
It should not become a copy of the benchmark itself.

## Repository Contents

- `test_harness/agent.py`: Main agent implementation
- `test_harness/generate_testbenches.py`: Generates `tb.v` files for each problem
- `test_harness/run_evaluation.py`: Compiles and simulates generated testbenches with `iverilog`
- `scripts/run_pipeline.sh`: Single entry-point script for the whole pipeline
- `scripts/compile_smoke_test.sh`: Simple EDA interaction / smoke-check script
- `examples/visible_results.txt`: Example visible-problem run summary
- `REPORT_TR.md`: Project report draft

## Setup

### Environment

The project expects:

- Python 3.10+ or compatible Python 3
- `iverilog`
- `vvp`

Recommended environment:

- Linux VM or Docker environment provided by the course / hackathon

### Python Dependencies

Install dependencies with:

```bash
pip install -r requirements.txt
```

The required Python packages are intentionally minimal:

- `absl-py`
- `wrapt-timeout-decorator`

## Single Command To Run The Pipeline

This repository includes a single entry-point script:

```bash
bash scripts/run_pipeline.sh visible_problems
```

If an answers folder is available:

```bash
bash scripts/run_pipeline.sh visible_problems visible_problems_answers
```

For hidden problems:

```bash
bash scripts/run_pipeline.sh hidden_problems
```

If hidden answers are available locally:

```bash
bash scripts/run_pipeline.sh hidden_problems hidden_problems_answers
```

## Exact Commands

### 1. Generate testbenches

```bash
python test_harness/generate_testbenches.py \
  --problems_folder="${PWD}/visible_problems"
```

### 2. Run evaluation without answers

```bash
python test_harness/run_evaluation.py \
  --problems_folder="${PWD}/visible_problems"
```

### 3. Run evaluation with answers

```bash
python test_harness/run_evaluation.py \
  --problems_folder="${PWD}/visible_problems" \
  --answers_folder="${PWD}/visible_problems_answers"
```

### 4. Quick compile smoke test

```bash
bash scripts/compile_smoke_test.sh visible_problems
```

## Input / Output Description

### Input

Each problem directory contains:

- `specification.md`: Natural language description of the RTL behavior
- `mutant_0.v` ... `mutant_30.v`: 31 RTL implementations
- `tb.v`: Generated Verilog testbench

### Output

The agent returns a complete Verilog testbench as a single string.

The generated testbench:

- uses module name `tb`
- compiles with `iverilog`
- prints `TESTS PASSED` on success
- ends with `$finish`

## Workflow Description

The workflow is:

1. Read `specification.md`
2. Parse the first mutant to extract module name and port information
3. Classify the problem type from the specification text
4. Generate a problem-specific Verilog testbench
5. Write the output to `tb.v`
6. Compile and simulate `tb.v` against each mutant using `iverilog` and `vvp`

The current agent is primarily rule-based and uses problem-family-specific templates.

## Expected Results

Visible problem behavior observed locally:

- `enc_bin2gray`: selective, 1 passing mutant
- `enc_bin2onehot`: selective, 1 passing mutant
- `ecc_sed_encoder`: selective, 1 passing mutant
- `shift_left`: selective, 1 passing mutant
- `shift_right`: selective, 1 passing mutant
- `lfsr`: selective, 1 passing mutant
- `counter`: selective, 1 passing mutant
- `credit_receiver`: selective, 1 passing mutant
- `fifo_flops`: selective, 1 passing mutant
- `cdc_fifo_flops_push_credit`: 1 passing mutant

Example output summary is included in:

- [examples/visible_results.txt](/Users/mertkan/Documents/New%20project/repo/examples/visible_results.txt)

## How To Run Hidden Testcases

When the hidden problems folder is available, use the exact same pipeline:

```bash
bash scripts/run_pipeline.sh hidden_problems
```

If the hidden answers folder is also available:

```bash
bash scripts/run_pipeline.sh hidden_problems hidden_problems_answers
```

No manual code changes are needed between visible and hidden runs.

## EDA Interaction

EDA interaction is performed through:

- `iverilog` compilation
- `vvp` simulation

The scripts that automate these interactions are:

- [scripts/run_pipeline.sh](/Users/mertkan/Documents/New%20project/repo/scripts/run_pipeline.sh)
- [scripts/compile_smoke_test.sh](/Users/mertkan/Documents/New%20project/repo/scripts/compile_smoke_test.sh)

## Notes / Limitations

- The current solution is strongest on combinational and clearly specified modules.
- Complex FIFO / CDC modules are harder to distinguish reliably using the current rule-based strategy.
- The repository is organized so the grader can follow: clone -> install -> run -> reproduce.
