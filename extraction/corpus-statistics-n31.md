# Corpus Statistics (n=31)

Source: `extraction/full-extraction.csv`.

All rates reported with Wilson 95% confidence intervals.

## Venue distribution

| Venue type | k/n | % | Wilson 95% CI |
|------------|-----|---|---------------|
| Peer-reviewed (conference + journal + workshop) | 18/31 | 58% | [41%, 74%] |
| arXiv-only | 13/31 | 42% | [26%, 59%] |
| Journal | 3/31 | 10% | -- |
| Conference | 14/31 | 45% | -- |
| Workshop (Springer LNCS) | 1/31 | 3% | -- |

The peer-reviewed pool includes top-tier venues: ICSE 2026 and ICSE-SEIP, ESEC/FSE 2026, ASE 2025, ACL 2025 Industry Track, IEEE COMPSAC 2025, NeurIPS Datasets and Benchmarks 2024, DAC, IEEE SecDev, ACM Middleware, ICPE 2024 Companion, Empirical Software Engineering 2025, MDPI Electronics 2026, Future Internet 2025, and Springer LNCS/CCIS workshop chapters via ESORICS 2025 and ADBIS 2025.

## IaC language coverage

| Language | k/n | % | Wilson 95% CI |
|----------|-----|---|---------------|
| Terraform | 11/31 | 35% | [21%, 53%] |
| K8s_YAML | 7/31 | 23% | [11%, 40%] |
| Ansible | 7/31 | 23% | [11%, 40%] |
| CloudFormation | 4/31 | 13% | [5%, 29%] |
| Chef | 3/31 | 10% | -- |
| Puppet | 3/31 | 10% | -- |
| CDK | 2/31 | 6% | -- |
| Pulumi | 2/31 | 6% | -- |
| Helm | 2/31 | 6% | -- |
| Bicep | 0/31 | 0% | [0%, 11%] |
| ARM template | 0/31 | 0% | [0%, 11%] |
| GCP Deployment Manager | 0/31 | 0% | [0%, 11%] |

## Cloud provider coverage

| Provider | k/n | % | Wilson 95% CI |
|----------|-----|---|---------------|
| AWS | 9/31 | 29% | [16%, 47%] |
| Azure | 1/31 | 3% | [1%, 16%] |
| GCP | 0/31 | 0% | [0%, 11%] |
| Cloud-agnostic | 4/31 | 13% | -- |
| Multi-cloud (survey) | 1/31 | 3% | -- |
| Not specified | 16/31 | 52% | -- |

## Problem type (non-exclusive)

| Problem type | k/n | % | Wilson 95% CI |
|--------------|-----|---|---------------|
| Generation | 18/31 | 58% | [41%, 74%] |
| Validation | 7/31 | 23% | [11%, 40%] |
| Repair | 7/31 | 23% | [11%, 40%] |
| Mutation | 2/31 | 6% | -- |

## Evaluation depth (five-level framework)

| Level | k/n | % | Wilson 95% CI |
|-------|-----|---|---------------|
| Deployability — full execution | 4/31 | 13% | [5%, 29%] |
| Deployability — plan-level only | 3/31 | 10% | -- |
| Deployability tested (any) | 7/31 | 23% | [11%, 40%] |
| Not deployability-tested | 24/31 | 77% | -- |
| Security/compliance tested | 11/31 | 35% | [21%, 53%] |
| Security/compliance not tested | 19/31 | 61% | [44%, 76%] |

## Primary technique families

| Technique | k/n | % | Wilson 95% CI |
|-----------|-----|---|---------------|
| Prompting | 14/31 | 45% | [29%, 62%] |
| Benchmark only | 4/31 | 13% | [5%, 29%] |
| RAG / knowledge injection | 4/31 | 13% | [5%, 29%] |
| Fine-tuning | 3/31 | 10% | -- |
| Verifier-guided | 2/31 | 6% | -- |
| Survey | 2/31 | 6% | -- |
| Multi-agent | 1/31 | 3% | -- |
| Mixed (prompting + RAG) | 1/31 | 3% | -- |

## Headline rates with Wilson CIs

- **35% (11/31) of studies evaluate security or compliance** [Wilson 95% CI 21%, 53%]
- **61% (19/31) of studies do not evaluate security at all** [Wilson 95% CI 44%, 76%]
- **23% (7/31) test deployability at any level** [Wilson 95% CI 11%, 40%]
- **35% (11/31) of studies target Terraform** [Wilson 95% CI 21%, 53%]
- **23% (7/31) of studies address Kubernetes manifests** [Wilson 95% CI 11%, 40%]
- **Zero studies (0/31) target Azure Bicep, ARM templates, or GCP Deployment Manager** [Wilson 95% CI 0%, 11%]

These rates carry wide CIs because n=31 is modest by traditional SLR standards, but the direction of every finding is robust: security underexamined, deployability rarely tested, Terraform and AWS dominant, multi-cloud nearly absent.
