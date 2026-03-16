# Candidate Pool -- Literature Search Results

Search executed: March 16, 2026
Databases: arXiv, IEEE Xplore, ACM DL (via Brave Search API). Scopus and Web of Science pending (require institutional access).

---

## Core Papers (Directly LLM + IaC Generation/Evaluation)

| ID | Title | Authors | Year | Venue | arXiv/DOI | Source |
|----|-------|---------|------|-------|-----------|--------|
| C01 | IaC-Eval: A Code Generation Benchmark for Cloud Infrastructure-as-Code Programs | Kon et al. | 2024 | NeurIPS 2024 (D&B) | 2410.15267 | arXiv, known |
| C02 | TerraFormer: Automated IaC with LLMs Fine-Tuned via Policy-Guided Verifier Feedback | Jana et al. | 2026 | arXiv / ICSE 2026 SEIP | 2601.08734 | arXiv, known |
| C03 | Multi-Agent Code-Orchestrated Generation for Reliable IaC (MACOG) | Khan, Wasif et al. | 2025 | arXiv | 2510.03902 | arXiv, known |
| C04 | IaC Generation with LLMs: An Error Taxonomy and Configuration Knowledge Injection | Nekrasov et al. | 2025 | arXiv | 2512.14792 | arXiv, known |
| C05 | A Survey of using Large Language Models for Generating Infrastructure as Code | Srivatsa et al. | 2023 | ICON 2023 / arXiv | 2404.00227 | arXiv, known |
| C06 | Multi-IaC-Eval: Benchmarking Cloud IaC Across Multiple Formats | (unknown) | 2025 | arXiv | 2509.05303 | arXiv, known |
| C07 | Deployability-Centric IaC Generation (IaCGen) | Zhang et al. | 2025 | arXiv | 2506.05623 | arXiv, known |
| C08 | Using a Feedback Loop for LLM-based Infrastructure as Code Generation | Palavalli et al. | 2024 | arXiv | 2411.19043 | arXiv, pilot |
| C09 | GenSIaC: Toward Security-Aware IaC Generation with Large Language Models | Li et al. | 2025 | arXiv | 2511.12385 | arXiv, NEW |
| C10 | ACSE-Eval: Can LLMs Threat Model Real-World Cloud Infrastructure? | Munshi et al. | 2025 | arXiv | 2505.11565 | arXiv, NEW |
| C11 | Repairing Infrastructure-as-Code using Large Language Models | (unknown) | 2024 | IEEE conf | 10.1109/10734039 | IEEE, pilot |
| C12 | An LLM-driven Framework for Dynamic Infrastructure as Code Generation | (unknown) | 2024 | ACM Middleware 2024 | 10.1145/3704440.3704778 | ACM, pilot |
| C13 | Security Smells in IaC Scripts: A Taxonomy | (unknown) | 2025 | arXiv | 2509.18761 | arXiv, pilot |
| C14 | Cloud Infrastructure Management in the Age of AI Agents | (unknown) | 2025 | arXiv | 2506.12270 | arXiv, NEW |
| C15 | Towards self-healing of IaC projects using constrained LLM | (unknown) | 2024 | ICSE 2024 | (conf) | known |
| C16 | LADs: Leveraging LLMs for AI-Driven DevOps | (unknown) | 2025 | arXiv | (arXiv) | known |
| C17 | Towards Formal Verification of LLM-Generated Code from NL Prompts | (unknown) | 2025 | arXiv | 2507.13290 | arXiv, NEW |
| C18 | Automated Microservice Pattern Detection using IaC Artifacts and LLMs | (unknown) | 2025 | ICSA-C 2025 | IEEE | IEEE, pilot |
| C19 | Evaluating LLMs for Infrastructure as Code (GFT Engineering) | Lu Mao | 2024 | Medium (industry) | N/A | web, NEW |
| C20 | Automated code generation for IT tasks in YAML through LLMs | Pujar et al. | 2023 | DAC 2023 | IEEE | ref in C06 |

## Adjacent Papers (LLM + Cloud/DevOps Security, Potentially In-Scope)

| ID | Title | Authors | Year | Venue | arXiv/DOI | Relevance |
|----|-------|---------|------|-------|-----------|-----------|
| A01 | Guiding AI to Fix Its Own Flaws: LLM-Driven Secure Code Generation | (unknown) | 2025 | arXiv | 2506.23034 | Adjacent - secure code gen, not IaC-specific |
| A02 | A Survey on LLM-based Code Generation for Low-Resource and Domain-Specific PLs | (unknown) | 2025 | arXiv | 2410.03981 | Adjacent - mentions IaC-Eval, covers domain-specific code gen |
| A03 | Test-suite-guided discovery of least privilege for cloud IaC | (unknown) | 2024 | ASE journal | ACM | Adjacent - IaC security but not LLM generation |

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Core candidates | 20 |
| Adjacent candidates | 3 |
| **Total before screening** | **23** |

### By Source
| Source | Count |
|--------|-------|
| arXiv | 15 |
| IEEE conferences | 3 |
| ACM conferences | 2 |
| NeurIPS | 1 |
| Industry/blog | 1 |
| Journal | 1 |

### Status
- Scopus search: PENDING (requires institutional login)
- Web of Science search: PENDING (requires institutional login)
- Google Scholar snowballing: PENDING (execute after core screening)

---

## Deduplication Log

| Record | Action | Reason |
|--------|--------|--------|
| C07 (IaCGen) | v1 vs v2 vs v3 on arXiv | Use v3 (Jan 2026) as primary |
| C19 (Medium post) | Exclude at screening | Not peer-reviewed, no methodology; industry blog post |

---

## Notes

1. **GenSIaC (C09) is a major find.** Directly addresses security-aware IaC generation with LLMs. Fine-tunes LLMs for security misconfiguration detection. F1-score improvement from 0.303 to 0.858. This is highly relevant to our security lens.

2. **ACSE-Eval (C10) is another strong find.** 100 production-grade AWS scenarios with IaC implementations + security vulnerabilities. Tests LLM threat modeling of cloud infrastructure. 8.4% security compliance rate reported.

3. **IaCGen (C07) now has security data.** v2/v3 added security compliance analysis: only 8.4% security compliance rate across LLMs. Strong evidence for our thesis.

4. **The field is growing faster than expected.** Papers from 2025-2026 are multiplying. The ~40+ estimate seems achievable with snowballing.

5. **Scopus/WoS may add 5-10 more.** Especially IEEE/ACM papers not discoverable via web search.

---

*Last updated: March 16, 2026*
