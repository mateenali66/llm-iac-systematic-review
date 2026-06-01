#!/usr/bin/env bash
# Parallel scanner wrapper. Runs all 5 scanners on every sample concurrently.
# Inputs:  ../generations/<model>/<prompt_id>/sample_<n>/output.<ext>
# Outputs: ../scanner-reports/raw/<model>/<prompt_id>/sample_<n>/{checkov.json,tfsec.json,kics.json,terrascan.json,trivy.json}
#
# Parallelism: PARALLEL_JOBS samples in flight at once. Each sample runs its
# 5 scanners sequentially (they share the same /in mount and produce
# distinct output files, so per-sample serialization is safe).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMPIRICAL_DIR="$(cd "$HERE/.." && pwd)"
GENERATIONS_DIR="$EMPIRICAL_DIR/generations"
REPORTS_DIR="$EMPIRICAL_DIR/scanner-reports"
PARALLEL_JOBS="${PARALLEL_JOBS:-6}"

mkdir -p "$REPORTS_DIR/raw"

if [ ! -d "$GENERATIONS_DIR" ] || [ -z "$(ls -A "$GENERATIONS_DIR" 2>/dev/null)" ]; then
  echo "ERROR: No generations found at $GENERATIONS_DIR." >&2
  exit 1
fi

echo "[$(date -u +%FT%TZ)] Pulling pinned scanner images..."
docker pull bridgecrew/checkov:3.2.358 >/dev/null
docker pull aquasec/tfsec:v1.28.13 >/dev/null
docker pull checkmarx/kics:v2.1.7 >/dev/null
docker pull tenable/terrascan:1.19.9 >/dev/null
docker pull aquasec/trivy:0.58.1 >/dev/null

# Build worklist of sample dirs (skip already-done samples for idempotency)
WORKLIST="$REPORTS_DIR/worklist.txt"
: > "$WORKLIST"
for model_dir in "$GENERATIONS_DIR"/*/; do
  model="$(basename "$model_dir")"
  for prompt_dir in "$model_dir"*/; do
    prompt_id="$(basename "$prompt_dir")"
    for sample_dir in "$prompt_dir"sample_*/; do
      sample="$(basename "$sample_dir")"
      target_rel="${model}/${prompt_id}/${sample}"
      out_base="$REPORTS_DIR/raw/${target_rel}"
      # Idempotent skip: marker file means all 5 scanners ran
      if [ -f "$out_base/.done" ]; then
        continue
      fi
      echo "$sample_dir|$target_rel" >> "$WORKLIST"
    done
  done
done

TOTAL=$(wc -l < "$WORKLIST" | tr -d ' ')
echo "[$(date -u +%FT%TZ)] $TOTAL samples queued (parallel=$PARALLEL_JOBS)"
echo "[$(date -u +%FT%TZ)] Estimated wall time: $(python3 -c "print(f'{$TOTAL*16/3600/$PARALLEL_JOBS:.2f} hours')")"

scan_one() {
  local sample_dir="$1"
  local target_rel="$2"
  local out_base="$REPORTS_DIR/raw/$target_rel"
  mkdir -p "$out_base"

  docker run --rm -v "$sample_dir:/in:ro" -v "$out_base:/out" \
    bridgecrew/checkov:3.2.358 \
    -d /in -o json --output-file-path /out/checkov.json --soft-fail >/dev/null 2>&1 || true

  docker run --rm -v "$sample_dir:/in:ro" -v "$out_base:/out" \
    aquasec/tfsec:v1.28.13 \
    /in --no-color --soft-fail --format json --out /out/tfsec.json >/dev/null 2>&1 || true

  docker run --rm -v "$sample_dir:/in:ro" -v "$out_base:/out" \
    checkmarx/kics:v2.1.7 \
    scan -p /in -o /out --output-name kics --report-formats json >/dev/null 2>&1 || true

  docker run --rm -v "$sample_dir:/in:ro" -v "$out_base:/out" \
    tenable/terrascan:1.19.9 \
    scan -d /in -o json > "$out_base/terrascan.json" 2>/dev/null || true

  docker run --rm -v "$sample_dir:/in:ro" -v "$out_base:/out" \
    aquasec/trivy:0.58.1 \
    config --format json --output /out/trivy.json /in >/dev/null 2>&1 || true

  touch "$out_base/.done"
}
export -f scan_one
export REPORTS_DIR

LOG="$REPORTS_DIR/run.log"
echo "[$(date -u +%FT%TZ)] Starting parallel scan, log=$LOG"
xargs -P "$PARALLEL_JOBS" -I {} -d '\n' bash -c '
  IFS="|" read -r sd tr <<< "{}"
  scan_one "$sd" "$tr"
  echo "[$(date -u +%FT%TZ)] done: $tr"
' < "$WORKLIST" 2>&1 | tee -a "$LOG"

echo "[$(date -u +%FT%TZ)] All scans complete. Normalizing..."
python3 "$HERE/normalize.py" \
  --raw-dir "$REPORTS_DIR/raw" \
  --output "$REPORTS_DIR/all-findings.jsonl"

echo "[$(date -u +%FT%TZ)] Done. Normalized findings at $REPORTS_DIR/all-findings.jsonl"
