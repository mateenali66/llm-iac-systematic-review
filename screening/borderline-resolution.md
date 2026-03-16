# Borderline Case Resolution + Competing SLR Analysis

Date: March 16, 2026

---

## Borderline Cases

### C16: LADs -- Leveraging LLMs for AI-Driven DevOps
**Source:** arXiv 2502.20825 (Khan et al., Feb 2025)

**Full-text findings:**
- Generates configuration files for Dask, Redis, and Ray using LLMs
- Uses few-shot learning, RAG, and prompt chaining
- Focuses on cloud configuration and deployment automation
- Does NOT specifically generate Terraform/CloudFormation/K8s manifests
- Targets distributed system configs (YAML for Dask, Redis, Ray), not declarative IaC

**Decision: EXCLUDE**
**Reason:** While it generates configuration YAML, the focus is on distributed computing framework configs (Dask, Redis, Ray), not infrastructure provisioning. The generated artifacts are application-layer configurations, not infrastructure specifications within our scope definition. IaC is incidental.

---

### C18: Automated Microservice Pattern Instance Detection Using IaC Artifacts and LLMs
**Source:** arXiv 2502.04188 / ICSA 2025 (Duarte, Feb 2025)

**Full-text findings:**
- Uses LLMs to ANALYZE existing IaC artifacts (not generate them)
- Goal: detect microservice architecture patterns from IaC code
- PhD research, early prototype (MicroPAD tool)
- LLM reads IaC to extract architecture knowledge, does not generate/repair/validate IaC

**Decision: EXCLUDE**
**Reason:** The LLM analyzes IaC but does not generate, repair, or validate it. The study uses IaC as input to the LLM rather than producing IaC as output. Fails inclusion criterion: "Proposes, evaluates, benchmarks, repairs, or validates LLM-assisted generation of IaC artifacts."

---

### C24: Prompt-Driven Container Orchestration
**Source:** CCIS/Springer 2026 (DOI: 10.1007/978-3-032-17286-0_4)

**Full-text findings:**
- Could not access full text
- Title suggests prompt-driven orchestration of containers, not IaC generation
- Published in CCIS (Springer conference proceedings)

**Decision: INCLUDE (tentatively)**
**Reason:** Container orchestration via prompts likely involves generating or modifying K8s manifests/configs. K8s manifests are in scope. If full-text reveals it only orchestrates running containers without generating IaC artifacts, reclassify to exclude. Low-risk inclusion since it would contribute to RQ2 (platform coverage).

---

## Competing SLR Analysis: C21

### Paper Details
- **Title:** Artificial Intelligence for Infrastructure-as-Code: A Systematic Literature Review
- **Authors:** Pahl, Barzegar, El Ioini (Free University of Bozen-Bolzano, Italy)
- **Journal:** Electronics (MDPI), 2026, 15(4), 755
- **DOI:** 10.3390/electronics15040755

### Key Facts
- **Methodology:** PRISMA-compliant SLR
- **Databases:** Scopus, SpringerLink, Google Scholar, IEEE Xplore
- **Time period:** 2020-2025 (cutoff Oct 1, 2025)
- **Studies included:** 44 total (34 technical + 11 reviews/surveys)
- **Initial pool:** 102 studies extracted
- **IaC tools covered:** Chef, Puppet, Ansible, Pulumi, Heat, DOML, Terraform, TOSCA, CloudFormation
- **Framework:** Maps contributions to a 4-phase DevOps lifecycle model

### Their Research Approach
- Broad "AI for IaC" scope (not limited to LLMs; includes ML, NLP, and other AI techniques)
- Organizes findings by DevOps phases: Dev (code gen, testing) and Ops (deployment, monitoring/self-healing)
- Key terms extraction from studies mapped to DevOps phases and AI techniques
- Includes 11 review/survey papers in their count (inflates the number)

### Their Coverage
- **Code generation:** Covers LLM-based Terraform generation
- **Security:** Mentions linters for security smell detection, security vulnerability detection and repair
- **Benchmarking:** Notes IaC-Eval as the main benchmark
- **Self-healing:** Covers monitoring and remediation

### Their Weaknesses (Our Differentiation Points)

| Weakness | Our Advantage |
|----------|---------------|
| **Broad AI scope** (ML, NLP, generic AI) dilutes LLM-specific analysis | We focus exclusively on LLMs, enabling deeper taxonomy of LLM-specific techniques |
| **Published in MDPI Electronics** (Q2, IF ~2.6, frequently criticized venue) | JSS is Q1, IF 5.88, established SE venue |
| **No security cross-cutting analysis** (security mentioned but not systematically coded) | Security is our first-class analytical dimension with 6-category taxonomy |
| **No quality assessment rubric** for included studies | We have split rigor/relevance scoring |
| **Cutoff Oct 2025** -- misses TerraFormer (Jan 2026), MACOG, GenSIaC, IaCGen security data | Our cutoff will be later, capturing the 2026 explosion |
| **44 studies includes 11 reviews** (only 34 are primary studies) | We focus on primary research with explicit adjacent-study rules |
| **No illustrative pilot** | We run Checkov/tfsec/OPA on actual LLM-generated IaC |
| **No unified error taxonomy** across studies | We build a cross-study failure model |
| **No evaluation framework** (5 levels from syntax to human eval) | We produce a reusable evaluation framework |
| **No study classification matrix** | We produce a detailed cross-tabulation |
| **DevOps lifecycle framing** is generic; does not produce reusable artifacts | Our taxonomy, evaluation framework, error model, and research agenda are concrete artifacts |

### How to Position Our Review

In our manuscript introduction/related work:

> While Pahl et al. (2026) provide a broad survey of AI techniques across the IaC lifecycle, their scope encompasses all AI approaches (including traditional ML and NLP) rather than focusing specifically on LLMs. Their review, which covers studies up to October 2025, predates several significant advances including neuro-symbolic fine-tuning approaches, multi-agent IaC generation, and security-aware generation frameworks. Our review differs in three key respects: (1) exclusive focus on LLM-based approaches, enabling a deeper taxonomy of generation techniques; (2) security and compliance as a systematic cross-cutting analytical dimension rather than an incidental mention; and (3) production of concrete reusable artifacts including a unified evaluation framework, cross-study error model, and security coverage matrix.

### Impact on Our Paper

- **No change to strategy.** The competing SLR actually strengthens our case: it shows the field needs synthesis, but its broad scope and MDPI venue leave significant room for a deeper, LLM-focused review in a Q1 journal.
- **Must cite it** as the most recent prior review alongside Srivatsa (2023).
- **Must differentiate clearly** in intro and related work sections.

---

*Completed: March 16, 2026*
