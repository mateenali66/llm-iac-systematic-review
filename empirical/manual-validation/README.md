# Manual Validation Sub-Study

This directory contains the stratified-sample manual-validation framework that estimates per-(scanner, severity) false-positive and false-negative rates for the scanner stack.

## Step 1 — Generate the sample

After scanner pipeline runs and `../scanner-reports/all-findings.jsonl` exists:

```bash
python sample_findings.py \
    --findings ../scanner-reports/all-findings.jsonl \
    --prompts ../prompts/prompts.jsonl \
    --generations ../generations \
    --out . \
    --target 150 \
    --floor-per-cell 3
```

Produces three files:

- `validation-input.jsonl` — one row per sampled finding with the IaC source path and original prompt for context
- `validation-template.jsonl` — same rows but with empty `label` and `rationale` fields for the validator to fill
- `sample-summary.json` — coverage report across (scanner, severity, model family) cells

## Step 2 — Validate each finding

For each row in `validation-template.jsonl`:

1. Read `generation_path/output.<ext>` (the IaC source the scanner flagged).
2. Read `original_prompt` to understand the user's intent.
3. Determine whether the flagged misconfiguration represents:
   - **TP** (True Positive): the IaC code violates a documented security best practice (e.g., CIS Benchmark item) AND that best practice is appropriate for the prompt's stated context.
   - **FP** (False Positive): the scanner flagged something that is not actually a misconfiguration in the prompt's context (e.g., flagging public S3 access on a deliberate static website bucket).
   - **TN** (True Negative): rare in this workflow because we only sampled flagged findings; useful for findings that scanners flagged as LOW/INFO that are not actually security concerns.
   - **FN** (False Negative): the IaC has a real security flaw that the sampled finding does NOT catch but should — only label as FN if reviewing the file end-to-end reveals a missed issue.
4. Write a one- or two-sentence `rationale` justifying the label, and optionally cite the canonical CIS Benchmark ID (`cis_benchmark_id`).

Save the completed file as `validation-labels.jsonl` (do not overwrite the template).

## Schema

Each row in `validation-labels.jsonl`:

| Field | Type | Description |
|-------|------|-------------|
| `validation_id` | string | Unique sample ID (V001 ... V150) |
| `scanner` | enum | One of checkov, tfsec, kics, terrascan, trivy |
| `model` | string | LLM that produced the flagged IaC |
| `prompt_id` | string | Prompt the IaC was generated from |
| `sample_id` | string | sample_1 ... sample_3 |
| `rule_id` | string | Scanner rule ID that fired |
| `severity` | enum | INFO/LOW/MEDIUM/HIGH/CRITICAL |
| `label` | enum | TP / FP / TN / FN |
| `rationale` | string | 1-2 sentence justification |
| `cis_benchmark_id` | string | Optional canonical reference (e.g. "CIS AWS 2.1.1") |

## Step 3 — Fold validation results into analysis

```bash
python ../notebooks/analyze.py \
    --findings ../scanner-reports/all-findings.jsonl \
    --prompts ../prompts/prompts.jsonl \
    --validation ./validation-labels.jsonl \
    --out ../results
```

This adds `manual_validation_summary.csv` to the results, with FP/FN rates per (scanner, severity) that feed into Section 9 of the manuscript.

## Reproducibility

The sampler uses `--seed 42` by default. A fixed seed plus the floor-per-cell rule (`>=3` from every non-empty cell) means re-running the sampler against the same findings file yields the same sample. Document any seed change in your run-log.
