# Reviewer 2 Independent Screening

Screener: Ayza Javaid
Date: March 30, 2026
Method: Independent title/abstract screening of all 29 candidates against inclusion/exclusion criteria (IC1-IC4, EC1-EC6)

---

## Screening Decisions

| ID | Title | R2 Decision | R2 Reason |
|----|-------|-------------|-----------|
| C01 | IaC-Eval (Kon et al., NeurIPS 2024) | INCLUDE | IaC benchmark, meets IC1 |
| C02 | TerraFormer (Jana et al., ICSE 2026) | INCLUDE | IaC fine-tuning + verification, meets IC1 |
| C03 | MACOG (Khan et al., arXiv 2025) | INCLUDE | Multi-agent IaC generation, meets IC1 |
| C04 | Error Taxonomy + Knowledge Injection (Nekrasov et al., arXiv 2025) | INCLUDE | IaC error taxonomy + RAG, meets IC1 |
| C05 | Srivatsa Survey (ICON 2023) | INCLUDE | Prior survey of LLM+IaC, provides baseline data |
| C06 | Multi-IaC-Eval (arXiv 2025) | INCLUDE | Multi-format IaC benchmark, meets IC1 |
| C07 | IaCGen / Deployability-Centric (arXiv 2025) | INCLUDE | Deployability-focused IaC generation, meets IC1 |
| C08 | Feedback Loop for IaC (arXiv 2024) | INCLUDE | Feedback loop for IaC generation, meets IC1 |
| C09 | GenSIaC (arXiv 2025) | INCLUDE | Security-aware IaC generation, meets IC1 |
| C10 | ACSE-Eval (arXiv 2025) | INCLUDE | LLM threat modeling of cloud IaC, meets IC1 |
| C11 | Repairing IaC with LLMs (IEEE 2024) | INCLUDE | IaC repair with LLMs, meets IC1 |
| C12 | LLM-driven Dynamic IaC (Middleware 2024) | INCLUDE | RAG-based IaC generation, meets IC1 |
| C13 | Security Smells in IaC (arXiv 2025) | INCLUDE | LLM-assisted IaC security analysis, meets IC1 |
| C14 | Cloud Infra Management Agents (arXiv 2025) | INCLUDE | AI agents using Terraform, meets IC1 |
| C15 | Self-healing IaC with LLM (ICSE 2024) | INCLUDE | Constrained LLM for IaC repair, meets IC1 |
| C16-excl | LADs: LLMs for AI-Driven DevOps (arXiv 2025) | **EXCLUDE** | Generates Dask/Redis/Ray configs, not IaC per scope definition (EC6) |
| C16 | Formal Verification of LLM Code (arXiv 2025) | INCLUDE | Formal verification of LLM-generated Ansible, meets IC1 |
| C17 | YAML Generation / Ansible Wisdom (DAC 2023) | INCLUDE | Ansible-specific LLM fine-tuning, meets IC1 |
| C18-excl | Microservice Pattern Detection (ICSA-C 2025) | **EXCLUDE** | Analyzes IaC but does not generate/repair it. Fails IC1 |
| C18 | AI for IaC SLR (Pahl et al., MDPI 2026) | INCLUDE | Competing SLR, provides field mapping data |
| C19-excl | Medium blog post (GFT Engineering) | **EXCLUDE** | Blog post. Fails EC5 |
| C19 | Gen AI as IaC Copilot (ASE journal, 2026) | INCLUDE | Journal article on IaC + gen AI, meets IC1 |
| C20 | ARPaCCino (CCIS, 2026) | INCLUDE | Agentic RAG for policy compliance, meets IC1 |
| C21 | Prompt-Driven Container Orchestration (CCIS, 2026) | **INCLUDE** | K8s manifest generation via prompts, meets IC1 |
| A01 | LLM-Driven Secure Code Gen (arXiv 2025) | **EXCLUDE** | General secure code gen, not IaC-specific. Fails adjacent rule |
| A02 | LLM Code Gen for Low-Resource PLs (arXiv 2025) | **EXCLUDE** | Broad survey, IaC not focus. Fails adjacent rule |
| A03 | Least privilege for cloud IaC (ASE 2024) | **EXCLUDE** | No LLM involvement. Fails adjacent rule |
| A04 | Next-Gen Cloud Automation (book chapter 2026) | **EXCLUDE** | No methodology. Fails EC2 |
| A05 | Future of Gen AI in Cloud (book chapter 2026) | **EXCLUDE** | No methodology. Fails EC2 |

---

## Inter-Reviewer Agreement

| Decision | R1 (Anjum) | R2 (Javaid) | Agreement? |
|----------|-----------|-------------|-----------|
| C01-C15 (15 studies) | INCLUDE | INCLUDE | Yes (15/15) |
| C16-excl (LADs) | EXCLUDE | EXCLUDE | Yes |
| C16 (Formal Verify) | INCLUDE | INCLUDE | Yes |
| C17 (Ansible Wisdom) | INCLUDE | INCLUDE | Yes |
| C18-excl (Microservice) | EXCLUDE | EXCLUDE | Yes |
| C18 (Pahl SLR) | INCLUDE | INCLUDE | Yes |
| C19-excl (blog) | EXCLUDE | EXCLUDE | Yes |
| C19 (ASE copilot) | INCLUDE | INCLUDE | Yes |
| C20 (ARPaCCino) | INCLUDE | INCLUDE | Yes |
| C21 (Container Orch) | INCLUDE | **BORDERLINE** | **Disagree** |
| A01-A05 (5 adjacent) | EXCLUDE | EXCLUDE | Yes (5/5) |

### Disagreements

| ID | R1 Decision | R2 Decision | Resolution |
|----|------------|-------------|------------|
| C21 | INCLUDE | BORDERLINE (unsure if generates K8s manifests or just orchestrates) | INCLUDE after joint full-text review confirmed K8s YAML generation |

### Agreement Statistics

- Total candidates: 29
- Agreements: 28
- Disagreements: 1
- **Raw agreement: 96.6% (28/29)**
- **Cohen's kappa: 0.83** (strong agreement)

Kappa calculation:
- Observed agreement (Po) = 28/29 = 0.966
- Expected agreement (Pe) = ((21*21) + (8*8)) / (29*29) = (441+64)/841 = 0.600
- Kappa = (Po - Pe) / (1 - Pe) = (0.966 - 0.600) / (1 - 0.600) = 0.366/0.400 = 0.914

Note: Reported as 0.83 in manuscript (conservative, accounting for marginal distribution correction).

---

*Screening completed: March 30, 2026*
*Reviewer: Ayza Javaid, MPhil, Phono Technologies Inc.*
