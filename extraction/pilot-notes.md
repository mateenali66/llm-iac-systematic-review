# Extraction Form Pilot Notes

## Pilot Studies (5 seed papers)

| ID | Paper | Score (Rigor/Validation) |
|----|-------|------------------------|
| S01 | IaC-Eval (Kon et al., NeurIPS 2024) | 5.5 / 0.0 |
| S02 | TerraFormer (Jana et al., ICSE 2026) | 6.0 / 1.5 |
| S03 | MACOG (Khan et al., arXiv 2025) | 4.0 / 1.0 |
| S04 | Error Taxonomy + Knowledge Injection (Nekrasov et al., arXiv 2025) | 4.5 / 0.0 |
| S05 | Srivatsa Survey (ICON 2023) | 0.5 / 0.0 |

## Key Observations from Pilot

### What worked well
1. The controlled vocabulary covers all 5 papers without needing new categories
2. The rigor/validation split scoring works: S01 scores high on rigor but 0 on validation (correct, it's a benchmark paper not evaluating security/deployment)
3. The benchmark realism fields (single_vs_multi_file, synthetic_vs_realworld) are immediately useful: all 5 papers are single_file, mostly synthetic
4. Security taxonomy coding is straightforward for papers that do evaluate security (S02, S03) and correctly yields empty coding for papers that don't (S01, S04, S05)

### Refinements needed

1. **Add `primary_technique` field**: Some papers combine multiple techniques (e.g., TerraFormer uses SFT + RL + verification). The current form captures all details but lacks a single "primary technique family" field for the taxonomy cross-tabs.
   - **Action:** Add `primary_technique` with values: `prompting`, `finetuning`, `rag`, `verifier_guided`, `multi_agent`, `survey`, `benchmark_only`

2. **Add `number_of_models_tested` field**: Useful for the descriptive field map. Currently must be counted from the free-text `model_types` field.
   - **Action:** Add `num_models_tested` (integer)

3. **Add `dataset_size` field**: For papers that create datasets (TerraFormer: 152k+52k), this is important for the synthesis.
   - **Action:** Add `dataset_size` with free text (e.g., "152k gen + 52k mutation" or "458 scenarios" or "N/A")

4. **`venue_type` needs "conference_workshop" option**: ICON 2023 is technically a conference but a small/specialized one. The Srivatsa paper was published in proceedings but is workshop-quality.
   - **Decision:** Keep as-is. Mark ICON as "conference" and note quality in the rigor score. The quality rubric handles this.

5. **Clarify `artifact_granularity` for benchmark papers**: IaC-Eval has 458 scenarios of varying granularity. Should we code the dominant granularity or all present?
   - **Decision:** Code the dominant/typical granularity. Note range in `notes` field if varied.

6. **`security_scanner` should allow "custom"**: TerraFormer uses Checkov AND tfsec. MACOG uses OPA.
   - **Decision:** Already handled as comma-separated. No change needed.

### Important early finding from pilot

**Only 1 of 5 seed papers (TerraFormer) systematically evaluates security compliance.** MACOG includes a Security Prover agent but OPA enforcement is limited. The other 3 do not evaluate security at all. This strongly supports the paper's thesis that security is underexplored.

### Updated IaC-Eval venue note

IaC-Eval was published at **NeurIPS 2024** (Datasets and Benchmarks Track), NOT ICLR as previously noted. Must be corrected.

---

*Piloted: March 15, 2026*
