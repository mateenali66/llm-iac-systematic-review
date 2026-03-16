# Search Strings -- Paper 6: LLM-Assisted IaC Systematic Review

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

| Database | Date Tested | Query Used | Results Count | Notes |
|----------|------------|------------|---------------|-------|
| IEEE Xplore | | | | |
| ACM DL | | | | |
| Scopus | | | | |
| Web of Science | | | | |
| arXiv | | | | |
| Google Scholar | | | | |

## Refinement Notes

Record any changes made to search strings after pilot testing:

| Date | Change | Reason |
|------|--------|--------|
| | | |

---

*Created: March 15, 2026*
