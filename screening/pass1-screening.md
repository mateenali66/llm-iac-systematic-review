# Pass 1 Screening -- Title/Abstract Review

Date: March 16, 2026
Screener: Mateen Ali Anjum (Pass 1)

## Criteria Applied

**Include if:** Proposes, evaluates, benchmarks, repairs, or validates LLM-assisted generation of IaC artifacts within scope. Published 2023+. English. Peer-reviewed or arXiv with methodology.

**Exclude if:** General code gen without IaC focus. Position/opinion without methodology. Duplicate/superseded. Tool demo without evaluation. Blog/marketing. IaC only incidental.

**Adjacent rule:** Must evaluate LLM + infrastructure-specification artifacts AND inform at least one RQ.

---

## Core Candidates

| ID | Title | Decision | Reason |
|----|-------|----------|--------|
| C01 | IaC-Eval (Kon et al., NeurIPS 2024) | **INCLUDE** | Foundational IaC benchmark. 458 Terraform scenarios. GPT-4 19.36% pass@1. Directly informs RQ2, RQ3, RQ4 |
| C02 | TerraFormer (Jana et al., ICSE 2026) | **INCLUDE** | Fine-tuning + RL + verification for IaC. 152k+52k datasets. Security compliance scoring. Informs RQ1, RQ3, RQ4, RQ5 |
| C03 | MACOG (Khan et al., arXiv 2025) | **INCLUDE** | Multi-agent IaC generation with OPA policy. GPT-5 54.90→74.02. Informs RQ1, RQ3, RQ5 |
| C04 | Error Taxonomy + Knowledge Injection (Nekrasov et al., arXiv 2025) | **INCLUDE** | Two-dimensional error taxonomy. RAG improves 27.1%→62.6%. Informs RQ1, RQ3, RQ4 |
| C05 | Srivatsa Survey (ICON 2023) | **INCLUDE** | Only prior survey. Weak but necessary baseline comparison. Informs RQ6 |
| C06 | Multi-IaC-Eval (arXiv 2025) | **INCLUDE** | Extends IaC-Eval to CloudFormation + CDK. Multi-format benchmarking. Informs RQ2, RQ3 |
| C07 | IaCGen / Deployability-Centric (Zhang et al., arXiv 2025) | **INCLUDE** | Iterative deployment feedback. DPIaC-Eval benchmark. 8.4% security compliance. Informs RQ1, RQ3, RQ4, RQ5 |
| C08 | Feedback Loop for IaC (Palavalli et al., arXiv 2024) | **INCLUDE** | Feedback loop on CloudFormation generation. GPT-4o. Informs RQ1, RQ3 |
| C09 | GenSIaC (Li et al., arXiv 2025) | **INCLUDE** | Security-aware IaC generation. Fine-tunes LLMs for misconfiguration detection. F1: 0.303→0.858. KEY PAPER for RQ5 |
| C10 | ACSE-Eval (Munshi et al., arXiv 2025) | **INCLUDE** | 100 AWS scenarios with IaC + security vulns. LLM threat modeling. Informs RQ2, RQ5 |
| C11 | Repairing IaC using LLMs (IEEE 2024) | **INCLUDE** | LLM for IaC repair (misconfigurations). Informs RQ1, RQ4 |
| C12 | LLM-driven Dynamic IaC Generation (ACM Middleware 2024) | **INCLUDE** | RAG-based IaC generation framework. Informs RQ1 |
| C13 | Security Smells in IaC: A Taxonomy (arXiv 2025) | **INCLUDE** | LLM-assisted security smell detection across 7 IaC tools. Uses GPT-3.5/4o. Informs RQ4, RQ5 |
| C14 | Cloud Infrastructure Management with AI Agents (arXiv 2025) | **INCLUDE** | AI agents using SDK/CLI/IaC/web for cloud management. Tests Terraform agent. Informs RQ1, RQ2 |
| C15 | Self-healing IaC with constrained LLM (ICSE 2024) | **INCLUDE** | Constrained LLM for IaC repair. Peer-reviewed at ICSE. Informs RQ1, RQ4 |
| C16 | LADs: LLMs for AI-Driven DevOps (arXiv 2025) | **BORDERLINE** | Broad DevOps scope. Need full-text review to confirm IaC-specific content. Tentatively include |
| C17 | Formal Verification of LLM-Generated Code (arXiv 2025) | **INCLUDE** | Focuses on Ansible (IaC). Formal verification of LLM-generated IaC. Informs RQ1, RQ3 |
| C18 | Microservice Pattern Detection with IaC + LLMs (ICSA-C 2025) | **BORDERLINE** | Uses IaC + LLM but for architecture detection, not IaC generation. Adjacent at best. Need full-text |
| C19 | Evaluating LLMs for IaC (Medium blog) | **EXCLUDE** | Blog post. No peer review. No methodology. Exclusion criterion: blog/marketing content |
| C20 | Automated YAML generation (Pujar et al., DAC 2023) | **INCLUDE** | LLM for Ansible YAML generation. 56.81% functional equivalency. Informs RQ1, RQ2, RQ3 |
| C21 | AI for IaC: A Systematic Literature Review (Electronics/MDPI, 2026) | **INCLUDE** | Competing SLR. Must analyze for positioning and differentiation. Informs RQ6 |
| C22 | Generative AI as IaC copilot across DevSecOps (ASE journal, 2026) | **INCLUDE** | Journal article on gen AI + IaC across lifecycle. Informs RQ1, RQ2, RQ5 |
| C23 | ARPaCCino: Agentic-RAG for Policy as Code Compliance (CCIS, 2026) | **INCLUDE** | Agentic RAG for policy compliance checking of IaC. Directly informs RQ5 |
| C24 | Prompt-Driven Container Orchestration (CCIS, 2026) | **BORDERLINE** | Container orchestration via prompts. Need full-text to confirm if it generates K8s manifests or just orchestrates |

## Adjacent Candidates

| ID | Title | Decision | Reason |
|----|-------|----------|--------|
| A01 | LLM-Driven Secure Code Generation (arXiv 2025) | **EXCLUDE** | General secure code gen. Not IaC-specific. Fails adjacent rule criterion 1 |
| A02 | LLM Code Gen for Low-Resource PLs (arXiv 2025) | **EXCLUDE** | Survey mentions IaC-Eval but not focused on IaC. Too broad |
| A03 | Least privilege for cloud IaC (ASE journal 2024) | **EXCLUDE** | IaC security but no LLM involvement. Fails adjacent rule criterion 1 |
| A04 | Next-Gen Cloud Automation with Gen AI (book chapter 2026) | **EXCLUDE** | Overview/position chapter. No methodology. Exclusion criterion: position paper |
| A05 | Future of Gen AI in Cloud Infrastructure (book chapter 2026) | **EXCLUDE** | Overview chapter. No methodology. Exclusion criterion: position paper |

---

## Pass 1 Summary

| Decision | Count |
|----------|-------|
| **INCLUDE** | 21 |
| **BORDERLINE** (need full-text) | 3 (C16, C18, C24) |
| **EXCLUDE** | 5 (C19, A01-A05) |
| **Total** | 29 |

## Borderline Cases -- Full-Text Review Needed

1. **C16 (LADs):** Broad "AI-Driven DevOps" scope. If it has substantial IaC-specific evaluation, include. If IaC is incidental, exclude.
2. **C18 (Microservice Pattern Detection):** Uses IaC artifacts + LLMs but for architecture pattern detection, not IaC generation/repair/validation. Include only if methods/findings directly inform our RQs.
3. **C24 (Prompt-Driven Container Orchestration):** If it generates K8s manifests from prompts, include. If it only orchestrates existing containers, exclude.

---

## Pass 2 Instructions

Wait minimum 2 weeks (until March 30, 2026 or later). Then:
1. Re-screen all 29 candidates independently
2. Compare Pass 1 and Pass 2 decisions
3. Document any disagreements with rationale
4. Resolve borderline cases with full-text review

---

*Pass 1 completed: March 16, 2026*
*Pass 2 scheduled: March 30, 2026 or later*
