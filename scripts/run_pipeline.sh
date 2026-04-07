#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: bash scripts/run_pipeline.sh <problems_folder> [answers_folder]"
  exit 1
fi

PROBLEMS_FOLDER="$1"
ANSWERS_FOLDER="${2:-}"

if [[ ! -d "$PROBLEMS_FOLDER" ]]; then
  echo "Problems folder not found: $PROBLEMS_FOLDER"
  exit 1
fi

echo "[1/2] Generating testbenches from ${PROBLEMS_FOLDER}"
python test_harness/generate_testbenches.py \
  --problems_folder="${PWD}/${PROBLEMS_FOLDER}"

echo "[2/2] Running evaluation"
if [[ -n "$ANSWERS_FOLDER" ]]; then
  python test_harness/run_evaluation.py \
    --problems_folder="${PWD}/${PROBLEMS_FOLDER}" \
    --answers_folder="${PWD}/${ANSWERS_FOLDER}"
else
  python test_harness/run_evaluation.py \
    --problems_folder="${PWD}/${PROBLEMS_FOLDER}"
fi
