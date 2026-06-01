# Empirical Prompt Set

**Total:** 116 prompts
**Format:** JSONL (one prompt per line)
**License:** CC BY 4.0

## Per-language balance

| Language | Count | Provider |
|----------|-------|----------|
| Terraform | 25 | AWS |
| Kubernetes YAML | 21 | Kubernetes |
| Azure Bicep | 15 | Azure |
| GCP Deployment Manager | 15 | GCP |
| CloudFormation | 10 | AWS |
| Helm | 10 | Kubernetes |
| Ansible | 10 | Linux (state reconciliation, per ITAB) |
| CDK Python | 7 | AWS |
| CDK TypeScript | 3 | AWS |

## Per-provider balance

| Provider | Count |
|----------|-------|
| AWS | 45 |
| Kubernetes | 31 |
| Azure | 15 |
| GCP | 15 |
| Linux | 10 |

## Per-category balance

| Category | Count |
|----------|-------|
| Compute | 19 |
| Storage | 15 |
| Observability | 14 |
| Workload (K8s/Helm) | 14 |
| Network/Networking | 17 |
| Security | 11 |
| Identity | 9 |
| Database | 9 |
| Container | 5 |
| RBAC | 3 |

## Provenance

All 116 prompts are hand-crafted by the author (Mateen Ali Anjum, 12+ years of DevOps practice). They are designed to:

1. Mirror common practitioner intents (security-relevant decisions like encryption, public exposure, least privilege, network segmentation).
2. Span every IaC language in the empirical study scope (Terraform, CloudFormation, CDK Python, CDK TypeScript, Azure Bicep, GCP Deployment Manager, Kubernetes manifests, Helm charts, Ansible).
3. Stratify by service category so per-(cloud, language, category) analysis is feasible.
4. Be sufficiently specific that an LLM has interesting design choices to make (e.g., choosing whether to enable encryption by default, restricting public access, applying least-privilege IAM).

The hand-crafted approach is preferred over sampling from IaC-Eval / Multi-IaC-Eval because: (1) it ensures multi-cloud coverage that the foundational benchmarks lack; (2) it gives full reproducibility under CC BY 4.0 without secondary-license concerns; (3) it allows targeting of the specific security-relevant decision points that the manual-validation sample will probe.

## Schema

Each line is a JSON object with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `prompt_id` | string | Unique identifier (e.g., `TF-AWS-001`, `K8S-NET-004`, `BICEP-AZURE-009`) |
| `language` | enum | One of: terraform, cloudformation, cdk_python, cdk_typescript, azure_bicep, gcp_dm, k8s_yaml, helm, ansible |
| `provider` | enum | One of: aws, azure, gcp, kubernetes, linux |
| `category` | enum | Service category for stratified analysis |
| `difficulty` | enum | `single_resource` or `multi_resource` |
| `source` | string | Always `hand-crafted` for this prompt set |
| `prompt` | string | Natural-language prompt text given to the LLM |

## Citation

If you reuse this prompt set, please cite the parent paper and the Zenodo replication-package DOI.
