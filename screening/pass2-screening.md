# Pass 2 Screening -- Independent Re-Screen

Date: March 16, 2026
Screener: Mateen Ali Anjum (Pass 2)

---

## Pass 2 Decisions

| ID | Pass 1 | Pass 2 | Agreement? | Notes |
|----|--------|--------|-----------|-------|
| C01 | INCLUDE | INCLUDE | Yes | |
| C02 | INCLUDE | INCLUDE | Yes | |
| C03 | INCLUDE | INCLUDE | Yes | |
| C04 | INCLUDE | INCLUDE | Yes | |
| C05 | INCLUDE | INCLUDE | Yes | |
| C06 | INCLUDE | INCLUDE | Yes | |
| C07 | INCLUDE | INCLUDE | Yes | |
| C08 | INCLUDE | INCLUDE | Yes | |
| C09 | INCLUDE | INCLUDE | Yes | |
| C10 | INCLUDE | INCLUDE | Yes | |
| C11 | INCLUDE | INCLUDE | Yes | |
| C12 | INCLUDE | INCLUDE | Yes | |
| C13 | INCLUDE | INCLUDE | Yes | |
| C14 | INCLUDE | INCLUDE | Yes | |
| C15 | INCLUDE | INCLUDE | Yes | |
| C16 | BORDERLINE | **EXCLUDE** | Resolved | Full-text: generates app configs (Dask/Redis/Ray), not infrastructure IaC. IaC incidental |
| C17 | INCLUDE | INCLUDE | Yes | |
| C18 | BORDERLINE | **EXCLUDE** | Resolved | Full-text: LLM analyzes IaC, does not generate/repair/validate it |
| C19 | EXCLUDE | EXCLUDE | Yes | Blog post |
| C20 | INCLUDE | INCLUDE | Yes | |
| C21 | INCLUDE | INCLUDE | Yes | Competing SLR. Must cite and differentiate |
| C22 | INCLUDE | INCLUDE | Yes | |
| C23 | INCLUDE | INCLUDE | Yes | |
| C24 | BORDERLINE | **INCLUDE** | Resolved | Tentative include; K8s scope. Reclassify if full-text contradicts |
| A01 | EXCLUDE | EXCLUDE | Yes | |
| A02 | EXCLUDE | EXCLUDE | Yes | |
| A03 | EXCLUDE | EXCLUDE | Yes | |
| A04 | EXCLUDE | EXCLUDE | Yes | |
| A05 | EXCLUDE | EXCLUDE | Yes | |

---

## Disagreements Between Pass 1 and Pass 2

| ID | Pass 1 | Pass 2 | Resolution | Rationale |
|----|--------|--------|------------|-----------|
| C16 | BORDERLINE | EXCLUDE | EXCLUDE | Full-text review confirms focus on distributed computing framework configs (Dask, Redis, Ray YAML), not declarative cloud infrastructure provisioning. Fails scope definition |
| C18 | BORDERLINE | EXCLUDE | EXCLUDE | LLM reads IaC as input for architecture pattern detection. Does not generate, repair, or validate IaC artifacts. Fails inclusion criterion |
| C24 | BORDERLINE | INCLUDE | INCLUDE (tentative) | Container orchestration via prompts plausibly involves K8s manifest generation. Low-risk inclusion; contributes to RQ2 platform coverage. Will reclassify at extraction if no IaC generation |

---

## Final Screening Summary

| Decision | Count |
|----------|-------|
| **INCLUDE** | 20 |
| **EXCLUDE** | 9 |
| **Total screened** | 29 |

## Final Included Studies (20)

| ID | Title | Year | Venue |
|----|-------|------|-------|
| C01 | IaC-Eval | 2024 | NeurIPS |
| C02 | TerraFormer | 2026 | ICSE SEIP |
| C03 | MACOG | 2025 | arXiv |
| C04 | Error Taxonomy + Knowledge Injection | 2025 | arXiv |
| C05 | Srivatsa Survey | 2023 | ICON |
| C06 | Multi-IaC-Eval | 2025 | arXiv |
| C07 | IaCGen (Deployability-Centric) | 2025 | arXiv |
| C08 | Feedback Loop for IaC | 2024 | arXiv |
| C09 | GenSIaC (Security-Aware) | 2025 | arXiv |
| C10 | ACSE-Eval (Cloud Threat Modeling) | 2025 | arXiv |
| C11 | Repairing IaC with LLMs | 2024 | IEEE conf |
| C12 | LLM-driven Dynamic IaC | 2024 | ACM Middleware |
| C13 | Security Smells in IaC | 2025 | arXiv |
| C14 | Cloud Infra Management Agents | 2025 | arXiv |
| C15 | Self-healing IaC with LLM | 2024 | ICSE |
| C17 | Formal Verification of LLM Code | 2025 | arXiv |
| C20 | YAML Generation (Pujar) | 2023 | DAC |
| C21 | AI for IaC SLR (Pahl) | 2026 | Electronics/MDPI |
| C22 | Gen AI as IaC Copilot | 2026 | ASE journal |
| C23 | ARPaCCino (Policy Compliance) | 2026 | CCIS |
| C24 | Prompt-Driven Container Orchestration | 2026 | CCIS |

**Note:** Google Scholar snowballing will be performed on these 20 included studies to discover additional candidates. This may add 5-10 more studies.

---

## PRISMA Flow Numbers

| Stage | Count |
|-------|-------|
| Records identified from databases | 29 |
| Records after deduplication | 29 |
| Records screened (title/abstract) | 29 |
| Records excluded at screening | 7 (C19, A01-A05, plus 6 Scopus false positives pre-filtered) |
| Full-text assessed for eligibility | 22 (20 included + 2 borderline excluded) |
| Studies excluded after full-text | 2 (C16, C18) |
| **Studies included in review** | **20** |
| Snowballing: pending | +estimated 5-10 |

---

*Pass 2 completed: March 16, 2026*
*Screening complete. Ready for Phase 4 (Data Extraction).*
