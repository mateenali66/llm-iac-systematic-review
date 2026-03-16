# Extraction Codebook -- Paper 6

This document defines the controlled vocabulary and coding rules for every field in the extraction form.

---

## Bibliographic Fields

| Field | Values | Notes |
|-------|--------|-------|
| `study_id` | S01, S02, ... | Sequential ID assigned during screening |
| `authors` | Free text | Last names, comma-separated |
| `year` | 2023, 2024, 2025, 2026 | Publication or preprint year |
| `title` | Free text | Full title |
| `venue` | Free text | Journal name, conference name, or "arXiv" |
| `venue_type` | journal, conference, workshop, arxiv | Controlled values |
| `doi` | DOI string or "none" | |

---

## Problem Type

| Value | Definition |
|-------|-----------|
| generation | LLM generates new IaC from scratch (NL prompt, spec, etc.) |
| repair | LLM fixes/patches existing broken IaC |
| validation | LLM validates or checks existing IaC |
| refactoring | LLM restructures existing IaC without changing behavior |
| migration | LLM converts IaC from one language/platform to another |
| mixed | Study covers multiple problem types |

---

## IaC Languages

Controlled values (comma-separated if multiple):

| Value | Covers |
|-------|--------|
| Terraform | Terraform, OpenTofu, HCL |
| CloudFormation | AWS CloudFormation (JSON/YAML) |
| CDK | AWS CDK (TypeScript, Python, etc.) |
| Bicep | Azure Bicep |
| ARM | Azure ARM templates |
| Pulumi | Pulumi (any language) |
| K8s_YAML | Kubernetes manifests (YAML) |
| Helm | Helm charts |
| GCP_DM | GCP Deployment Manager |
| Ansible | Ansible playbooks (only if framed as IaC) |
| Other | Specify in notes |

---

## Cloud Providers

Controlled values: `AWS`, `Azure`, `GCP`, `multi-cloud`, `cloud-agnostic`, `not_specified`

---

## Artifact Granularity

| Value | Definition |
|-------|-----------|
| single_resource | One cloud resource (e.g., one S3 bucket) |
| module | A reusable module or group of related resources |
| full_stack | Complete infrastructure stack (networking + compute + storage + ...) |
| multi_file | Multiple files with cross-references |
| not_specified | Paper does not clarify |

---

## Model Types

Free text, but normalize to families where possible:

| Family | Specific Models |
|--------|----------------|
| GPT-4 | GPT-4, GPT-4o, GPT-4-turbo, GPT-4-0613 |
| GPT-3.5 | GPT-3.5-turbo, text-davinci-003 |
| Claude | Claude 3, Claude 3.5, Claude 2 |
| CodeLlama | CodeLlama-7B, CodeLlama-13B, CodeLlama-34B |
| StarCoder | StarCoder, StarCoder2 |
| DeepSeek | DeepSeek-Coder, DeepSeek-V2 |
| WizardCoder | WizardCoder-15B, etc. |
| Custom | Fine-tuned custom model (describe in notes) |
| Other | Specify |

---

## Model Version Fields

| Field | Values |
|-------|--------|
| `model_versions` | Specific version string if reported (e.g., "GPT-4-0613", "2024-01"), or "not_reported" |
| `closed_vs_open` | closed_api, open_weight, both |
| `tool_use_external_verifier` | yes (describe), no, not_reported |

---

## Fields Added After Pilot (March 2026)

| Field | Values | Rationale |
|-------|--------|-----------|
| `primary_technique` | prompting, finetuning, rag, verifier_guided, multi_agent, survey, benchmark_only | Single primary technique family for taxonomy cross-tabs |
| `num_models_tested` | Integer | Count of distinct models evaluated; useful for descriptive field map |
| `dataset_size` | Free text (e.g., "458 scenarios", "152k gen + 52k mutation", "N/A") | Size of dataset created or used; important for synthesis |

---

## Technique Fields

### Prompting Method
Controlled values: `zero-shot`, `few-shot`, `chain-of-thought`, `template-guided`, `structured`, `retrieval-augmented`, `mixed`, `not_specified`

### Fine-tuning
| Field | Values |
|-------|--------|
| `finetuning_used` | yes, no |
| `finetuning_dataset_size` | Number or "not_reported" |
| `finetuning_technique` | SFT, RLHF, DPO, policy-guided, other, N/A |

### RAG / Knowledge Injection
| Field | Values |
|-------|--------|
| `rag_knowledge_injection` | yes, no |
| `knowledge_source` | provider_docs, API_schemas, existing_modules, benchmark_data, custom_KB, N/A |

### Multi-Agent / Verifier
| Field | Values |
|-------|--------|
| `multi_agent_verifier` | yes, no |
| `agent_architecture` | Free text description, or N/A |

---

## Evaluation Fields

### Evaluation Metrics
Free text, comma-separated. Common values:
`pass@1`, `pass@5`, `pass@10`, `BLEU`, `CodeBLEU`, `exact_match`, `plan_success`, `apply_success`, `deploy_success`, `CIS_compliance`, `Checkov_score`, `human_eval`, `custom`

### Deployability Tested
| Value | Definition |
|-------|-----------|
| static_only | Syntax/parse check only |
| plan_level | terraform plan or equivalent |
| full_deployment | Actually deployed to cloud |
| not_tested | No deployment validation |

### Security Tested
| Field | Values |
|-------|--------|
| `security_tested` | yes, no |
| `security_scanner` | Checkov, tfsec, OPA, Sentinel, custom, none |

---

## Failure Categories

Comma-separated from controlled list:
`syntactic`, `semantic`, `dependency`, `provider_api_mismatch`, `deployability`, `security_governance`, `llm_reasoning`, `not_reported`

---

## Reproducibility Level

| Value | Definition |
|-------|-----------|
| full | Code + data + prompts publicly available |
| partial | Some artifacts shared (e.g., code but not data, or data but not prompts) |
| none | No replication artifacts available |

---

## Benchmark Realism Fields

| Field | Values |
|-------|--------|
| `single_vs_multi_file` | single_file, multi_file, both, not_specified |
| `synthetic_vs_realworld` | synthetic, realworld, mixed, not_specified |
| `provider_docs_used` | yes, no, not_specified |
| `module_reuse_state` | present, absent, not_specified |
| `org_policy_context` | present, absent, not_specified |

---

## Quality Scoring

### Methodological Rigor (0 / 0.5 / 1 each, max 6.0)

| Field | Dimension |
|-------|-----------|
| `rigor_clarity` | Clarity of research objective |
| `rigor_dataset` | Adequacy of dataset/task description |
| `rigor_reproducibility` | Reproducibility of prompt/setup |
| `rigor_evaluation` | Rigor of evaluation design |
| `rigor_code_data` | Availability of code/data |
| `rigor_validity` | Validity discussion |
| `rigor_total` | Sum of above (auto-calculated) |

### Practical Validation Depth (0 / 0.5 / 1 each, max 2.0)

| Field | Dimension |
|-------|-----------|
| `validation_security` | Security assessment |
| `validation_deployment` | Deployment validation |
| `validation_total` | Sum of above (auto-calculated) |

---

## Notes Field

Free text for anything not captured above: borderline decisions, interesting quotes, cross-references to other studies, etc.

---

*Created: March 15, 2026*
