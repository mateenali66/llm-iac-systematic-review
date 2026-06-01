#!/usr/bin/env bash
# End-to-end downstream pipeline: scan -> normalize -> analyze -> sample -> figures.
# Run this after generate.py has populated empirical/generations/.
#
# Prereqs:
#   - Docker daemon running
#   - venv activated (or system Python with pandas/numpy/scipy/matplotlib/seaborn)
#   - empirical/generations/ populated

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if [ ! -d "generations" ] || [ -z "$(ls -A generations 2>/dev/null)" ]; then
  echo "ERROR: empirical/generations/ is empty. Run generate.py first." >&2
  exit 1
fi

echo "===================================================="
echo "[1/4] Running scanner pipeline"
echo "===================================================="
./scanners/run-scanners.sh

echo ""
echo "===================================================="
echo "[2/4] Computing statistics"
echo "===================================================="
python3 notebooks/analyze.py \
  --findings scanner-reports/all-findings.jsonl \
  --prompts prompts/prompts.jsonl \
  --out results

echo ""
echo "===================================================="
echo "[3/4] Generating figures"
echo "===================================================="
python3 notebooks/figures.py --results results

echo ""
echo "===================================================="
echo "[4/4] Sampling for manual validation"
echo "===================================================="
python3 manual-validation/sample_findings.py \
  --findings scanner-reports/all-findings.jsonl \
  --prompts prompts/prompts.jsonl \
  --generations generations \
  --out manual-validation \
  --target 150

echo ""
echo "===================================================="
echo "Downstream pipeline complete."
echo "===================================================="
echo "Results:    $HERE/results/"
echo "Figures:    $HERE/results/figures/"
echo "Validation sample: $HERE/manual-validation/validation-template.jsonl"
echo ""
echo "Next steps:"
echo "  1. Fill validation-template.jsonl labels manually -> save as validation-labels.jsonl"
echo "  2. Re-run analyze.py with --validation flag to fold FP/FN into results"
