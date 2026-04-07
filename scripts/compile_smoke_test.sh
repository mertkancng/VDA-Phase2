#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/compile_smoke_test.sh <problems_folder>"
  exit 1
fi

PROBLEMS_FOLDER="$1"

if [[ ! -d "$PROBLEMS_FOLDER" ]]; then
  echo "Problems folder not found: $PROBLEMS_FOLDER"
  exit 1
fi

for problem_dir in "${PROBLEMS_FOLDER}"/*; do
  [[ -d "${problem_dir}" ]] || continue
  tb_file="${problem_dir}/tb.v"
  mutant_file="${problem_dir}/mutant_0.v"
  [[ -f "${tb_file}" ]] || continue
  [[ -f "${mutant_file}" ]] || continue
  echo "Compiling $(basename "${problem_dir}")"
  iverilog -g2012 -o /tmp/"$(basename "${problem_dir}")".out -s tb "${tb_file}" "${mutant_file}"
done

echo "Smoke compilation completed."
