# Phase 5: Synthesis Report

Generated: March 16, 2026
Studies: 21 included

---

## 5.1 Data Normalization

Labels normalized using controlled vocabulary from codebook. No issues found. CDK/CDK (TypeScript) merged to CDK. Azure CLI/SDK treated as non-IaC interfaces (relevant only for C14's agent comparison).

---

## 5.2 Descriptive Field Map

### Publication Trend
| Year | Count | Trend |
|------|-------|-------|
| 2023 | 2 | Early work (Srivatsa survey, Pujar Ansible) |
| 2024 | 5 | IaC-Eval benchmark establishes field |
| 2025 | 9 | Explosion: techniques, benchmarks, security |
| 2026 | 5 | Maturation: journal articles, SLRs, ICSE |

**Observation:** The field effectively began in 2023 and has doubled year-over-year. 2025 was the breakout year with 9 studies (43%).

### Venue Distribution
| Type | Count | % |
|------|-------|---|
| arXiv preprint | 10 | 48% |
| Conference | 9 | 43% |
| Journal | 2 | 10% |

**Observation:** arXiv dominates, reflecting the fast-moving nature. Only 2 journal articles (both 2026), indicating the field has barely reached journal maturity. All 2025 studies are arXiv-only.

### Cloud Provider Coverage
| Provider | Count | % |
|----------|-------|---|
| AWS | 9 | 43% |
| Cloud-agnostic | 4 | 19% |
| Not specified | 6 | 29% |
| Azure | 1 | 5% |
| Multi-cloud | 1 | 5% |

**Observation:** AWS dominates (43%). Azure has exactly 1 study (C14). GCP has zero coverage. Multi-cloud evaluation is virtually absent.

---

## 5.3 RQ1: Taxonomy of Technical Approaches

### Taxonomy

| Family | Sub-categories | Studies | Count |
|--------|---------------|---------|-------|
| **A. Prompt-based** | Zero-shot, few-shot, structured | C01, C08, C10, C11, C14, C15, C17, C24 | 8 |
| **B. Retrieval-augmented (RAG)** | Provider docs, API schemas, Graph RAG | C04, C12, C23 | 3 |
| **C. Fine-tuned models** | SFT, instruction tuning, RL | C02, C09, C20 | 3 |
| **D. Verifier-guided iterative** | Compile feedback, deploy feedback, policy feedback | C07, C08 | 2 |
| **E. Multi-agent orchestration** | Planner + generator + validator + security prover | C03 | 1 |
| **F. Benchmark/survey** | Evaluation frameworks, literature reviews | C01, C05, C06, C21 | 4* |

*C01 is counted in both A (tests prompting) and F (creates benchmark). C08 spans A and D.

### Key Findings (RQ1)
1. **Prompting dominates** (8/21, 38%) but yields the weakest results (GPT-4 at 19% pass@1)
2. **Fine-tuning shows strongest gains:** TerraFormer +15.94% on IaC-Eval, GenSIaC F1 0.303→0.858
3. **Verifier-guided generation is emerging:** IaCGen achieves 100% passItr@7 with iterative feedback
4. **Multi-agent is rare but promising:** MACOG shows 54.90→74.02 with specialized agents
5. **RAG/knowledge injection improves technical correctness** (27.1%→75.3%) but plateaus on intent alignment (Correctness-Congruence Gap)
6. **No study combines all approaches** (e.g., fine-tuned + RAG + verifier + security)

---

## 5.4 RQ2: Tasks, Artifacts, and Platforms

### Study Classification Matrix

| Study | IaC Language | Provider | Task | Granularity | Multi-cloud | Deploy tested | Security tested |
|-------|-------------|----------|------|-------------|-------------|--------------|-----------------|
| C01 | Terraform | AWS | gen | single | No | static | No |
| C02 | Terraform | AWS | gen+mut | single+module | No | plan | Yes |
| C03 | Terraform | AWS | gen | single+module | No | plan | Yes |
| C04 | Terraform | AWS | gen | single | No | static | No |
| C05 | Terraform | - | mixed | - | No | - | No |
| C06 | TF+CF+CDK | AWS | gen+mut | single+stack | No | static | No |
| C07 | CloudFormation | AWS | gen | single | No | **deploy** | Yes |
| C08 | CloudFormation | AWS | gen | single | No | static | No |
| C09 | Ansible+Chef+Puppet | agnostic | gen | - | N/A | - | **Yes** |
| C10 | CDK | AWS | valid | stack | No | - | **Yes** |
| C11 | Terraform | AWS | repair | - | No | - | No |
| C12 | - | - | gen | - | No | - | No |
| C13 | 7 tools | agnostic | valid | - | N/A | - | **Yes** |
| C14 | TF+Azure | Azure | gen | - | No | - | No |
| C15 | - | - | repair | - | No | - | No |
| C17 | Ansible | agnostic | valid | - | N/A | - | No |
| C20 | Ansible | agnostic | gen | - | N/A | - | No |
| C21 | 9 tools | multi | survey | - | Yes | - | No |
| C22 | - | - | gen | - | - | - | - |
| C23 | - | - | valid | - | - | - | Yes |
| C24 | K8s | - | gen | - | - | - | No |

### Coverage Gaps
| Dimension | Finding |
|-----------|---------|
| **Terraform dominance** | 10/21 studies (48%). Justified by market share but creates coverage bias |
| **AWS lock-in** | 9/21 studies target AWS only (43%). Azure: 1. GCP: 0 |
| **No multi-cloud evaluation** | Zero studies evaluate same LLM across multiple cloud providers |
| **Bicep/Pulumi absent** | No study evaluates LLM generation of Azure Bicep or Pulumi code |
| **K8s/Helm underrepresented** | Only 1 study (C24) addresses K8s manifests. Zero for Helm charts |
| **Single-file only** | 10/21 (48%) are single-file. Only 1 (C10) uses multi-file. Zero test module reuse or state management |
| **Generation dominates** | 13/21 (62%) focus on generation. Only 2 on repair, 4 on validation |

---

## 5.5 RQ3: Evaluation Practices

### Evaluation Framework (5 Levels)

| Level | What It Measures | Studies Using | Count | % |
|-------|-----------------|---------------|-------|---|
| **L1: Syntactic** | Code parses/compiles | C01-C08, C20 | 9 | 43% |
| **L2: Semantic** | Correct resources/attributes | C01-C07, C20 | 8 | 38% |
| **L3: Deployability** | Plan/apply/deploy success | C02, C03, C07 | 3 | 14% |
| **L4: Security** | Compliance/misconfig detection | C02, C03, C07, C09, C10, C13, C23 | 7 | 33% |
| **L5: Human eval** | Expert judgment/usefulness | (none explicit) | 0 | 0% |

### Evaluation Depth Distribution
| Deepest level reached | Studies | Count |
|----------------------|---------|-------|
| L1 only (syntax) | C08, C12, C24 | 3 |
| L2 (semantic) | C01, C04, C05, C06, C20 | 5 |
| L3 (deployability) | C02, C03 | 2 |
| L4 (security) | C07, C09, C10, C13, C23 | 5 |
| Not applicable (survey/meta) | C05, C14, C15, C17, C21, C22 | 6 |

### Key Findings (RQ3)
1. **Most studies stop at L2 (semantic).** Only 3 test actual deployability, only 7 test security
2. **No study reaches L5 (human evaluation)** for IaC-specific quality
3. **Metrics are fragmented:** pass@1 (most common), BLEU, CodeBERTScore, custom metrics all used but not comparable
4. **Only 1 study (C07) does full deployment testing** to actual cloud infrastructure
5. **Security compliance rates are alarming when measured:** C07 reports 8.4%, C09 baseline F1 of 0.303
6. **Benchmark realism is low:** 48% single-file, 0% test module reuse, 0% test state management

---

## 5.6 RQ4: Failure Modes and Error Taxonomy

### Unified Cross-Study Error Taxonomy

| Category | Failure Types | Reported By | Count |
|----------|--------------|-------------|-------|
| **A. Syntactic** | Invalid HCL/YAML/JSON, schema violations | C01-C08, C20 | 9 |
| **B. Semantic** | Wrong resource type, missing attributes, invalid combinations | C01-C07, C20 | 8 |
| **C. Dependency** | Missing refs, broken outputs, ordering errors | C02, C03, C04, C07 | 4 |
| **D. Provider/API mismatch** | Outdated syntax, deprecated resources, wrong provider | C01, C04, C07 | 3 |
| **E. Deployability** | Plan/apply failure, unresolved prereqs, state assumptions | C02, C07 | 2 |
| **F. Security/governance** | Overly permissive IAM, public exposure, policy violations | C02, C03, C07, C09, C11, C13 | 6 |
| **G. LLM-specific** | Hallucinated resources, partial completion, copied insecure defaults | C04, C09, C10, C13 | 4 |

### Key Findings (RQ4)
1. **Syntactic and semantic errors are universally reported** (9 and 8 studies respectively)
2. **Security failures are the 4th most reported category** (6 studies) but rarely measured systematically
3. **The Correctness-Congruence Gap** (C04): LLMs can become technically correct "coders" but fail as "architects" for intent alignment
4. **Provider API mismatch** is a distinct failure mode caused by training data staleness (C04 analyzed AWS provider changelogs)
5. **LLM-specific failures** include hallucinated resources and insecure defaults copied from training priors
6. **Deployability failures are underreported** because most studies don't test deployment

---

## 5.7 RQ5: Security and Compliance Lens

### Security Coverage Matrix

| Study | Sec eval | Tool/Method | IAM | Network | Data | Compliance | LLM-specific | Repair loop |
|-------|----------|-------------|-----|---------|------|------------|-------------|-------------|
| C02 | Yes | Checkov, tfsec | ? | ? | ? | Yes (CIS) | No | Yes (RL) |
| C03 | Yes | OPA | ? | ? | ? | Yes (custom) | No | Yes (plan) |
| C07 | Yes | Checkov | ? | ? | ? | Yes (CIS) | No | Yes (deploy) |
| C09 | Yes | GLITCH | Yes* | Yes* | Yes* | No | Yes | No |
| C10 | Yes | Custom | Yes | Yes | Yes | Partial | Yes | No |
| C13 | Yes | Terrascan + custom | Yes | Yes | Yes | Partial | Yes | No |
| C23 | Yes | Agentic RAG | ? | ? | ? | Yes (PaC) | No | No |
| Other 14 | **No** | - | - | - | - | - | - | - |

*GenSIaC covers 9 security weakness types derived from GLITCH taxonomy

### Security Gap Analysis

| Gap | Evidence | Impact |
|-----|----------|--------|
| **67% of studies ignore security entirely** | 14/21 do not evaluate security | Field treats correctness and security as separate concerns |
| **No study covers all 6 security categories** | Best coverage: C09, C10, C13 (3-4 categories each) | Fragmented security analysis |
| **CIS compliance rates are catastrophic** | C07: 8.4% compliance rate | LLM-generated IaC is insecure by default |
| **Security evaluation is post-hoc only** | All 7 studies scan after generation | No secure-by-construction approach exists |
| **No secrets/credential detection** | Zero studies test for hardcoded secrets | Major real-world risk unaddressed |
| **Config mgmt vs provisioning split** | C09 covers Ansible/Chef/Puppet; C02/C03/C07 cover Terraform/CF | No unified cross-paradigm security analysis |
| **Repair loops for security are rare** | Only C02 (RL), C03 (plan), C07 (deploy) have security-aware feedback | Most approaches cannot self-correct security issues |

### Key Findings (RQ5)
1. **Security is the field's biggest blind spot.** 67% of studies completely ignore it
2. **When measured, results are alarming:** 8.4% CIS compliance (C07), F1 of 0.303 baseline (C09)
3. **Fine-tuning can dramatically improve security:** GenSIaC achieves F1 0.858 (+183% improvement)
4. **No secure-by-construction approach exists.** All security evaluation is scan-after-generate
5. **The security taxonomy reveals systematic gaps:** no study covers secrets detection, least-privilege, or encryption-at-rest validation

---

## RQ6: Research Agenda

### Gap Matrix

| Gap Theme | Evidence | Research Need | Priority |
|-----------|----------|---------------|----------|
| **1. Secure-by-construction generation** | 0/21 studies integrate security into generation process | Security-aware prompting, fine-tuning, or constrained decoding that prevents misconfigs during generation | Critical |
| **2. Deployability-first evaluation** | Only 1/21 (C07) tests actual deployment; 14/21 never test | Standardized deployment testing infrastructure for IaC benchmarks | High |
| **3. Multi-cloud generalization** | 0/21 evaluate same approach across AWS+Azure+GCP | Cross-provider benchmarks and transfer learning studies | High |
| **4. Benchmark realism** | 48% single-file, 0% module reuse, 0% state management | Benchmarks with multi-file repos, module dependencies, env overlays, state | High |
| **5. Unified evaluation standard** | Metrics fragmented: pass@1, BLEU, CodeBERTScore, custom | Community-agreed evaluation framework with layers (syntax→deploy→security) | Medium |
| **6. Platform coverage beyond Terraform** | Bicep: 0, Pulumi: 0 (in primary studies), K8s: 1, Helm: 0 | Benchmarks for underrepresented platforms | Medium |
| **7. Human-in-the-loop workflows** | 0/21 study practitioner interaction with LLM-generated IaC | Usability studies, trust calibration, enterprise adoption barriers | Medium |
| **8. Secrets and credential handling** | 0/21 test for hardcoded secrets in generated IaC | Automated secret detection + prevention in LLM generation pipelines | High |
| **9. IaC mutation (not just generation)** | Only 2/21 (C02, C06) address mutation of existing IaC | More realistic: engineers modify existing IaC more often than create from scratch | Medium |
| **10. Organizational policy context** | 1/21 (C10) includes org policy; rest ignore enterprise constraints | Policy-aware generation that respects org-specific rules (naming, tagging, regions) | Low |

---

## Core Visuals Produced

| # | Visual | Status |
|---|--------|--------|
| 1 | PRISMA flow diagram | Numbers ready (29 screened → 21 included) |
| 2 | Taxonomy of LLM approaches (5 families) | Table complete |
| 3 | Study classification matrix | Table complete |
| 4 | Evaluation framework (5 levels) | Table complete |
| 5 | Unified error taxonomy (7 categories) | Table complete |
| 6 | Security coverage matrix | Table complete |
| 7 | Research agenda / gap matrix (10 themes) | Table complete |

---

## Phase 5 Checklist

**Data readiness:**
- [x] Extraction table cleaned
- [x] Labels normalized with controlled vocabularies
- [x] Duplicates resolved
- [x] Missing values flagged (6 studies need full-text)

**Descriptive synthesis:**
- [x] Study counts by year
- [x] Study counts by venue type
- [x] Study counts by artifact/platform
- [x] Study counts by method family
- [x] Cross-tabulations built

**RQ synthesis:**
- [x] Taxonomy built (RQ1)
- [x] Tasks/platforms matrix built (RQ2)
- [x] Evaluation framework built (RQ3)
- [x] Failure taxonomy built (RQ4)
- [x] Security matrix built (RQ5)
- [x] Research agenda built (RQ6)

**Writing prep:**
- [ ] 1-2 page memo per RQ (deferred to Phase 7 -- synthesis report serves as memo)
- [x] Figure list finalized
- [x] Table list finalized
- [x] Every major claim tied to a count, table, or matrix

---

*Synthesis completed: March 16, 2026*
