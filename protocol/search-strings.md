# Search Strings -- LLM-Assisted IaC Systematic Review

## Concept Blocks

### Block A: LLM / Generative AI
```
"large language model" OR "LLM" OR "GPT" OR "GPT-4" OR "GPT-3.5"
OR "code generation model" OR "generative AI" OR "foundation model"
OR "code LLM" OR "Claude" OR "CodeLlama" OR "StarCoder" OR "Codex"
OR "Copilot" OR "DeepSeek" OR "WizardCoder" OR "CodeGen"
OR "language model" OR "transformer model"
```

### Block B: Infrastructure as Code
```
"infrastructure as code" OR "IaC" OR "Terraform" OR "OpenTofu"
OR "CloudFormation" OR "AWS CDK" OR "Bicep" OR "Pulumi"
OR "Kubernetes manifest" OR "Helm chart" OR "cloud provisioning"
OR "infrastructure configuration" OR "deployment manifest"
OR "cloud configuration" OR "ARM template" OR "HCL"
OR "infrastructure automation" OR "infrastructure specification"
OR "GCP Deployment Manager"
```

### Combined Query
```
(Block A) AND (Block B)
```

---

## Database-Specific Adaptations

### IEEE Xplore
```
("large language model" OR "LLM" OR "GPT" OR "generative AI" OR "foundation model" OR "code generation model" OR "CodeLlama" OR "Codex" OR "Copilot")
AND
("infrastructure as code" OR "IaC" OR "Terraform" OR "CloudFormation" OR "Kubernetes manifest" OR "Helm chart" OR "Bicep" OR "Pulumi" OR "cloud provisioning" OR "infrastructure configuration" OR "ARM template" OR "HCL")
```
- Filter: 2023-present
- Search in: Full Text & Metadata

### ACM Digital Library
```
[[Full Text: "large language model"] OR [Full Text: "LLM"] OR [Full Text: "GPT"] OR [Full Text: "generative AI"] OR [Full Text: "foundation model"] OR [Full Text: "code generation model"] OR [Full Text: "CodeLlama"] OR [Full Text: "Codex"]]
AND
[[Full Text: "infrastructure as code"] OR [Full Text: "IaC"] OR [Full Text: "Terraform"] OR [Full Text: "CloudFormation"] OR [Full Text: "Kubernetes manifest"] OR [Full Text: "Bicep"] OR [Full Text: "Pulumi"] OR [Full Text: "cloud provisioning"] OR [Full Text: "HCL"]]
```
- Filter: Published Since 2023

### Scopus
```
TITLE-ABS-KEY(("large language model" OR "LLM" OR "GPT" OR "generative AI" OR "foundation model" OR "code generation" OR "CodeLlama" OR "Codex" OR "Copilot")
AND
("infrastructure as code" OR "IaC" OR "Terraform" OR "CloudFormation" OR "Kubernetes manifest" OR "Bicep" OR "Pulumi" OR "cloud provisioning" OR "infrastructure configuration" OR "HCL"))
AND PUBYEAR > 2022
```

### Web of Science
```
TS=("large language model" OR "LLM" OR "GPT" OR "generative AI" OR "foundation model" OR "code generation model" OR "CodeLlama" OR "Codex")
AND
TS=("infrastructure as code" OR "IaC" OR "Terraform" OR "CloudFormation" OR "Kubernetes manifest" OR "Bicep" OR "Pulumi" OR "cloud provisioning" OR "infrastructure configuration" OR "HCL")
```
- Timespan: 2023-2026

### arXiv
Search URL: https://arxiv.org/search/
```
(large language model OR LLM OR GPT OR generative AI OR foundation model OR code generation)
AND
(infrastructure as code OR IaC OR Terraform OR CloudFormation OR Kubernetes manifest OR Bicep OR Pulumi OR cloud provisioning OR HCL)
```
- Categories: cs.SE, cs.CL, cs.AI
- Date range: 2023-present

### Google Scholar (supplementary, for snowballing seeds)
```
"large language model" "infrastructure as code"
"LLM" "Terraform" code generation
"generative AI" "CloudFormation" OR "Kubernetes manifest"
```
- Multiple queries, date filter 2023-present
- Used for forward snowballing seed discovery, not primary search

---

## Pilot Testing Log

Pilot performed via Brave Search API (site-restricted queries) on March 15, 2026. Full database searches to be executed directly on each platform during Phase 2.

| Database | Date Tested | Query Method | Relevant Results Found | Notes |
|----------|------------|-------------|----------------------|-------|
| IEEE Xplore | 2026-03-15 | Brave site:ieeexplore.ieee.org | ~3-5 relevant | Found: "Repairing IaC using LLMs" (IEEE conf), IaC quality metrics. Some noise from general LLM/infrastructure papers. Need tighter IaC terms |
| ACM DL | 2026-03-15 | Brave site:dl.acm.org | ~3-4 relevant | Found: "LLM-driven Framework for Dynamic IaC Generation" (Middleware 2024), "Automated Microservice Pattern Detection using IaC and LLMs" (ICSA-C 2025). Heavy noise from general code LLM papers |
| arXiv | 2026-03-15 | Brave site:arxiv.org | ~8-12 relevant | Richest source. Found all core papers plus: Multi-IaC-Eval (2509.05303), Deployability-Centric IaCGen (2506.05623), Feedback Loop IaC (2411.19043), Security Smells taxonomy (2509.18761). arXiv dominates this field |
| Scopus | | Direct search needed | | Cannot pilot via Brave; requires institutional access |
| Web of Science | | Direct search needed | | Cannot pilot via Brave; requires institutional access |
| Google Scholar | 2026-03-15 | Brave search | Broad coverage | Confirms all known papers discoverable; useful for snowballing |

### New Papers Discovered During Pilot

| Paper | Venue | Relevance |
|-------|-------|-----------|
| "Repairing Infrastructure-as-Code using Large Language Models" | IEEE conf 2024 | High - LLM for IaC repair (new problem type) |
| "An LLM-driven Framework for Dynamic IaC Generation" | ACM Middleware 2024 | High - RAG-based IaC generation |
| "Multi-IaC-Eval: Benchmarking Cloud IaC Across Multiple Formats" | arXiv 2025 | High - extends IaC-Eval to CloudFormation + CDK (already known) |
| "Deployability-Centric IaC Generation (IaCGen)" | arXiv 2025 | High - iterative deployment feedback loop (already known) |
| "Using a Feedback Loop for LLM-based IaC Generation" | arXiv 2024 | High - deployment feedback on CloudFormation |
| "Security Smells in IaC Scripts: A Taxonomy" | arXiv 2025 | Medium-High - LLM-assisted IaC security smell detection across 7 tools |
| "Automated Microservice Pattern Detection using IaC and LLMs" | ICSA-C 2025 | Medium - adjacent: LLM + IaC for architecture detection |

### Pilot Assessment

**Search string effectiveness:** The concept blocks capture all known core papers. arXiv is clearly the dominant source (8-12 directly relevant results). IEEE and ACM yield fewer but include peer-reviewed work not on arXiv.

**Noise level:** Moderate on IEEE/ACM due to papers about "LLM infrastructure" (deployment/serving) matching "infrastructure" keyword. The IaC-specific terms (Terraform, CloudFormation, HCL, Bicep) are effective discriminators.

**Estimated total pool:** ~25-35 unique candidates from database search + ~10-15 from snowballing = ~35-50 total before screening. This aligns with the initial estimate of 15-20 core + 20-25 adjacent = ~40+ papers.

---

## Refinement Notes

| Date | Change | Reason |
|------|--------|--------|
| 2026-03-15 | No changes to search strings after pilot | Core papers all discoverable. Noise manageable via screening. IaC-specific terms effective as discriminators |

---

*Created: March 15, 2026*
*Pilot tested: March 15, 2026*
