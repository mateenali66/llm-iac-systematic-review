# PRISMA 2020 Review Protocol

## Paper 6: Towards Reliable LLM-Assisted Infrastructure as Code: A Systematic Review of Generation, Evaluation, and Security

---

## 1. Administrative Information

| Field | Value |
|-------|-------|
| **Title** | Towards reliable LLM-assisted infrastructure as code: a systematic review of generation, evaluation, and security |
| **Author** | Mateen Ali Anjum |
| **Affiliation** | Phono Technologies Inc., Kitchener, ON, Canada |
| **Email** | mateen@phonotech.ca |
| **ORCID** | 0009-0001-7231-8515 |
| **Protocol Version** | 1.0 |
| **Protocol Date** | March 15, 2026 |
| **Target Journal** | Journal of Systems and Software (Elsevier) |
| **Archival** | GitHub repository, archived via Zenodo DOI |

---

## 2. Review Objective

To systematically identify, classify, and synthesize research on LLM-assisted infrastructure as code (IaC), with security and compliance as a cross-cutting analytical dimension, producing a taxonomy of technical approaches, a unified evaluation framework, a cross-study error model, and a research agenda for reliable and secure adoption.

---

## 3. Research Questions

| RQ | Question |
|----|----------|
| RQ1 | What technical approaches have been used for LLM-assisted IaC generation, and how can they be systematically classified? |
| RQ2 | What artifact types, cloud platforms, and infrastructure languages are covered in the literature? |
| RQ3 | How is LLM-generated IaC evaluated, and what metrics are used for correctness, deployability, and reliability? |
| RQ4 | What failure modes and error taxonomies have been reported for LLM-generated IaC? |
| RQ5 | How are security, compliance, and policy-conformance addressed in current research? |
| RQ6 | What key research gaps remain for robust, multi-cloud, and secure LLM-assisted IaC? |

---

## 4. Eligibility Criteria

### 4.1 Scope Definition

**In scope:**
- Declarative cloud provisioning (Terraform/OpenTofu, CloudFormation, Azure Bicep/ARM, GCP Deployment Manager)
- Programmatic IaC frameworks (AWS CDK, Pulumi) when the primary artifact is infrastructure specification
- Kubernetes manifests and Helm charts (as operational IaC)
- Policy-as-code when directly applied to IaC validation (OPA, Sentinel, Checkov)

**Out of scope:** General CI/CD pipeline YAML, shell scripts, monitoring/alerting rule generation, application code generation, configuration management tools (Ansible, Chef, Puppet) unless explicitly framed as IaC generation targets.

### 4.2 Unit of Analysis

The unit of analysis is the study, not the paper file. When multiple versions exist (e.g., arXiv + conference), the most complete version is the primary record.

### 4.3 Inclusion Criteria

- Proposes, evaluates, benchmarks, repairs, or validates LLM-assisted generation of IaC artifacts within scope
- Published 2023 or later
- Written in English
- Peer-reviewed publication OR arXiv preprint with reproducible methodology

### 4.4 Exclusion Criteria

- General code generation without IaC focus
- Position papers, editorials, or opinion pieces without methodology
- Duplicate or superseded versions of the same study
- Tool demos without evaluation
- Studies lacking sufficient methodological detail to support extraction
- Blog posts or vendor marketing content
- Papers where IaC is only incidental

### 4.5 Adjacent Study Rule

Adjacent studies are included only if they satisfy BOTH:
1. They evaluate LLM-based generation/repair/validation of artifacts that function as infrastructure specifications or deployment descriptors
2. They provide evidence or methods directly informative to at least one RQ

---

## 5. Information Sources

| Database | Search Scope |
|----------|-------------|
| IEEE Xplore | Full Text & Metadata |
| ACM Digital Library | Full Text |
| Scopus | Title, Abstract, Keywords |
| Web of Science | Topic (Title, Abstract, Keywords) |
| arXiv | cs.SE, cs.CL, cs.AI |
| Google Scholar | Supplementary (snowballing seeds only) |

**arXiv rationale:** LLM-assisted IaC research evolves faster than journal/conference cycles; publication status is recorded and quality-assessed.

---

## 6. Search Strategy

### 6.1 Concept Blocks

**Block A (LLM):**
```
"large language model" OR "LLM" OR "GPT" OR "GPT-4" OR "GPT-3.5"
OR "code generation model" OR "generative AI" OR "foundation model"
OR "code LLM" OR "Claude" OR "CodeLlama" OR "StarCoder" OR "Codex"
OR "Copilot" OR "DeepSeek" OR "WizardCoder" OR "CodeGen"
OR "language model" OR "transformer model"
```

**Block B (IaC):**
```
"infrastructure as code" OR "IaC" OR "Terraform" OR "OpenTofu"
OR "CloudFormation" OR "AWS CDK" OR "Bicep" OR "Pulumi"
OR "Kubernetes manifest" OR "Helm chart" OR "cloud provisioning"
OR "infrastructure configuration" OR "deployment manifest"
OR "cloud configuration" OR "ARM template" OR "HCL"
OR "infrastructure automation" OR "infrastructure specification"
OR "GCP Deployment Manager"
```

**Combined:** Block A AND Block B

### 6.2 Time Window

2023 to literature cutoff date (set at execution time).

### 6.3 Database Adaptations

Database-specific query syntax documented in `protocol/search-strings.md`. All queries pilot-tested before full execution.

### 6.4 Supplementary Search

- Forward snowballing via Google Scholar citations of core papers (IaC-Eval, TerraFormer, MACOG)
- Backward snowballing from reference lists of all included papers
- One iteration of snowballing

---

## 7. Study Selection

### 7.1 Screening Process

1. **Phase 1:** Title and abstract screening against inclusion/exclusion criteria
2. **Phase 2:** Full-text review of candidate papers
3. **Self-audit:** Two-pass screening with minimum 2-week gap between passes. Disagreements between Pass 1 and Pass 2 documented with rationale (single-author adaptation of dual-reviewer requirement)

### 7.2 Screening Ledger

For each excluded full-text paper, record: citation, exclusion reason, borderline notes. For merged/superseded records: source versions, primary retained version, reason. Maintained in `screening/screening-ledger.csv`.

---

## 8. Data Extraction

### 8.1 Extraction Form

45-field extraction form covering: bibliographic metadata, problem type, IaC languages, cloud providers, artifact granularity, primary technique, model details (type, version, closed/open), prompting method, fine-tuning details, RAG/knowledge injection, multi-agent architecture, tool use, dataset/benchmark, evaluation metrics, deployability testing, security testing, failure categories, reproducibility, benchmark realism indicators, key findings, and threats/limitations.

Full schema in `extraction/extraction-codebook.md`.

### 8.2 Pilot

Extraction form piloted on 5 representative seed papers (IaC-Eval, TerraFormer, MACOG, Knowledge Injection, Srivatsa Survey). Pilot led to 3 field additions: `primary_technique`, `num_models_tested`, `dataset_size`. Pilot results in `extraction/pilot-extraction.csv` and `extraction/pilot-notes.md`.

### 8.3 Quality and Relevance Assessment

**Methodological Rigor** (6 dimensions, max 6.0): clarity of objective, dataset adequacy, reproducibility, evaluation rigor, code/data availability, validity discussion.

**Practical Validation Depth** (2 dimensions, max 2.0): security assessment, deployment validation.

Scores reported descriptively. Not used for exclusion.

---

## 9. Synthesis

### 9.1 Synthesis Methods

- **Descriptive quantitative mapping** of study characteristics
- **Qualitative thematic synthesis** for approaches, failure modes, security themes
- **Narrative integration** across heterogeneous evaluation settings
- **Cross-tabulation** by artifact type, model type, technique, validation depth

### 9.2 Planned Outputs

| Output | Maps to RQ |
|--------|-----------|
| Taxonomy of LLM approaches for IaC | RQ1 |
| Study classification matrix | RQ2 |
| Evaluation framework (5 levels) | RQ3 |
| Unified error taxonomy | RQ4 |
| Security coverage matrix | RQ5 |
| Research agenda / gap matrix | RQ6 |

### 9.3 Security Cross-Cutting Analysis

Every included study coded against a 6-category security taxonomy: Identity & Access, Network Exposure, Data Protection, Configuration Integrity, Governance & Compliance, LLM-Specific Risks.

---

## 10. Illustrative Security Pilot

Run Checkov/tfsec/OPA on 5-10 sample LLM-generated IaC artifacts from published datasets (IaC-Eval, TerraFormer). Classify findings against security taxonomy. Presented as supplementary appendix, not a standalone benchmark.

---

## 11. Synthesis Audit

Before manuscript finalization: every cross-study claim must trace to an explicit count, coded matrix, or cited study cluster.

---

## 12. Reference Management

- **Tool:** Zotero
- **Deduplication:** By DOI / title / author-year
- **arXiv vs published:** Prefer peer-reviewed version; retain arXiv only if it contains supplementary material absent from reviewed version

---

## 13. Amendments

Any changes to this protocol after registration will be documented with date, change description, and rationale.

| Date | Change | Rationale |
|------|--------|-----------|
| | | |

---

*Protocol Version 1.0 -- March 15, 2026*
