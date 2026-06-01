#!/usr/bin/env bash
# Run all 5 scanners over the generated IaC artefacts.
# Inputs:  ../generations/<model>/<prompt_id>/sample_<n>/output.<ext>
# Outputs: ../scanner-reports/<scanner>/<model>/<prompt_id>/sample_<n>.json
# Each scanner's per-file report is normalized to a unified schema by
# normalize.py and aggregated into ../scanner-reports/all-findings.jsonl
#
# Requires Docker. Pulls pinned images on first run.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMPIRICAL_DIR="$(cd "$HERE/.." && pwd)"
GENERATIONS_DIR="$EMPIRICAL_DIR/generations"
REPORTS_DIR="$EMPIRICAL_DIR/scanner-reports"

mkdir -p "$REPORTS_DIR"/{checkov,tfsec,kics,terrascan,trivy,raw}

if [ ! -d "$GENERATIONS_DIR" ] || [ -z "$(ls -A "$GENERATIONS_DIR" 2>/dev/null)" ]; then
  echo "ERROR: No generations found at $GENERATIONS_DIR. Run the LLM generation pipeline first." >&2
  exit 1
fi

echo "[$(date -u +%FT%TZ)] Pulling pinned scanner images..."
docker pull bridgecrew/checkov:3.2.358
docker pull aquasec/tfsec:v1.28.13
docker pull checkmarx/kics:v2.1.7
docker pull tenable/terrascan:1.19.9
docker pull aquasec/trivy:0.58.1

# Iterate over every generation: $GENERATIONS_DIR/<model>/<prompt_id>/sample_<n>/
for model_dir in "$GENERATIONS_DIR"/*/; do
  model="$(basename "$model_dir")"
  for prompt_dir in "$model_dir"*/; do
    prompt_id="$(basename "$prompt_dir")"
    for sample_dir in "$prompt_dir"sample_*/; do
      sample="$(basename "$sample_dir")"
      target_rel="${model}/${prompt_id}/${sample}"
      echo "[$(date -u +%FT%TZ)] Scanning $target_rel ..."

      out_base="$REPORTS_DIR/raw/${target_rel}"
      mkdir -p "$out_base"

      # Checkov (supports tf/cfn/k8s/helm/bicep/ansible/dockerfile/json/yaml)
      docker run --rm \
        -v "$sample_dir:/in:ro" \
        -v "$out_base:/out" \
        bridgecrew/checkov:3.2.358 \
        -d /in -o json --output-file-path /out/checkov.json --soft-fail >/dev/null 2>&1 || true

      # tfsec (Terraform only; skipped for non-tf inputs)
      docker run --rm \
        -v "$sample_dir:/in:ro" \
        -v "$out_base:/out" \
        aquasec/tfsec:v1.28.13 \
        /in --no-color --soft-fail --format json --out /out/tfsec.json >/dev/null 2>&1 || true

      # KICS (broad coverage: tf, cfn, k8s, helm, bicep, arm, ansible, dockerfile)
      docker run --rm \
        -v "$sample_dir:/in:ro" \
        -v "$out_base:/out" \
        checkmarx/kics:v2.1.7 \
        scan -p /in -o /out --output-name kics --report-formats json >/dev/null 2>&1 || true

      # Terrascan (tf, k8s, helm, dockerfile, cfn)
      docker run --rm \
        -v "$sample_dir:/in:ro" \
        -v "$out_base:/out" \
        tenable/terrascan:1.19.9 \
        scan -d /in -o json > "$out_base/terrascan.json" 2>/dev/null || true

      # Trivy IaC (tf, cfn, k8s, helm, bicep, arm, ansible, dockerfile)
      docker run --rm \
        -v "$sample_dir:/in:ro" \
        -v "$out_base:/out" \
        aquasec/trivy:0.58.1 \
        config --format json --output /out/trivy.json /in >/dev/null 2>&1 || true

    done
  done
done

echo "[$(date -u +%FT%TZ)] Normalizing scanner reports..."
python3 "$HERE/normalize.py" \
  --raw-dir "$REPORTS_DIR/raw" \
  --output "$REPORTS_DIR/all-findings.jsonl"

echo "[$(date -u +%FT%TZ)] Done. Normalized findings at $REPORTS_DIR/all-findings.jsonl"
