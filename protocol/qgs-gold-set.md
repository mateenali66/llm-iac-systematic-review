# Quasi-Gold-Set (QGS) for Search-String Validation

Following Zhang, Babar, and Tell (2011), "Identifying relevant studies in software engineering," *Information and Software Technology* 53(6): 625-637, we define a quasi-gold-set (QGS) of known-relevant studies to validate the systematic-review search string. The QGS replay verifies that our database queries recall all 10 known-relevant papers; any miss triggers a search-string refinement iteration.

## Inclusion criteria for QGS membership

A paper is included in the QGS when all four conditions hold:
1. Reviewed in depth and confirmed as a primary study on LLM-assisted IaC (generation, repair, validation, refactoring, or migration) per the review's inclusion criteria
2. Already extracted into `extraction/full-extraction.csv` OR independently verified as a critical study (e.g., ITAB)
3. Citable with a verifiable arXiv ID or DOI
4. Spans the topic axes the search must cover (technique family, IaC language, evaluation framing, security framing, methodology type)

## The 10-paper QGS

| # | Bibkey | Authors | Year | Title | Venue | DOI / arXiv ID | Why in QGS |
|---|--------|---------|------|-------|-------|----------------|------------|
| 1 | kon2024iaceval | Kon, Liu, Qiu, Fan, He, Lin, Zhang, Park, Elengikal, Kang, Chen, Chowdhury, Lee, Wang | 2024 | IaC-Eval: A Code Generation Benchmark for Cloud Infrastructure-as-Code Programs | NeurIPS 2024 D&B | arXiv:2410.15267 | Foundational benchmark establishing the Terraform LLM generation gap |
| 2 | davidson2025multiac | Davidson, Sun, et al. | 2025 | Multi-IaC-Eval: Benchmarking Cloud IaC Across Multiple Formats | arXiv | arXiv:2509.05303 | First multi-format IaC benchmark (Terraform + CloudFormation + CDK) |
| 3 | jana2026terraformer | Jana et al. | 2026 | TerraFormer: Automated IaC with LLMs Fine-Tuned via Policy-Guided Verifier Feedback | ICSE 2026 SEIP | arXiv:2601.08734 | Top fine-tuning + RL paper, only one with explicit security compliance scoring via formal verification |
| 4 | li2025gensiac | Li, Grella, Nahmias, Engelberg, Klein, Guizzardi, et al. | 2025 | GenSIaC: Toward Security-Aware IaC Generation with LLMs | arXiv | arXiv:2511.12385 | Key security-aware fine-tuning paper covering configuration management IaC (Ansible/Chef/Puppet) |
| 5 | pujar2023ansible | Pujar, Buratti, Guo, Dupuis, Lewis, Suneja, Sood, Nalawade, Jones, Morari, Puri | 2023 | Automated Code Generation for IT Tasks in YAML through LLMs (Ansible Wisdom) | DAC 2023 | 10.1109/DAC56929.2023.10247987 | First Ansible-specific LLM fine-tuning (IBM Research) |
| 6 | nekrasov2025error | Nekrasov, Fossati, Kumara, Tamburri, van den Heuvel | 2025 | IaC Generation with LLMs: An Error Taxonomy and A Study on Configuration Knowledge Injection | arXiv | arXiv:2512.14792 | Key error-taxonomy + RAG paper; introduces Correctness-Congruence Gap |
| 7 | munshi2025acseeval | Munshi et al. | 2025 | ACSE-Eval: Can LLMs Threat Model Real-World Cloud Infrastructure? | arXiv | arXiv:2505.11565 | Production-grade CDK threat-modeling benchmark, security validation focus |
| 8 | zhang2025iacgen | Zhang, Pan, et al. | 2025 | Deployability-Centric IaC Generation (IaCGen) | arXiv | arXiv:2506.05623 | Only study with end-to-end cloud deployment evaluation; reports 8.4% CIS compliance |
| 9 | arpaccino2026 | Romeo et al. | 2026 | ARPaCCino: An Agentic-RAG for Policy as Code Compliance | CCIS (Springer) | 10.1007/978-3-032-05727-3_39 | Agentic-RAG for policy compliance, security-cross-cutting validation work |
| 10 | hassan2025itab | Hassan, Salvador, Rahman, Karmaker | 2025 | Large Language Models for IT Automation Tasks: Are We There Yet? (ITAB) | arXiv | arXiv:2505.20505 | Only benchmark targeting state reconciliation (44.87% of 1,411 failures in 14 LLMs) |

## Axis coverage of the QGS

The QGS spans the topical axes the search must recall:

| Axis | Covered by |
|------|-----------|
| Benchmark / dataset | C01 (IaC-Eval), C06 (Multi-IaC-Eval), C07 (IaCGen), C10 (ACSE-Eval), ITAB |
| Fine-tuning + RL | C02 (TerraFormer), C17 (Ansible Wisdom) |
| Security-aware fine-tuning | C09 (GenSIaC) |
| RAG / knowledge injection | C04 (Nekrasov), C20 (ARPaCCino) |
| State reconciliation | ITAB |
| Terraform | C01, C02, C04, C07 |
| CloudFormation / CDK | C06, C07, C10 |
| Ansible | C09, C17, ITAB |
| Multi-cloud / multi-language | C06, C09, C13 |
| Validation / threat modeling | C10 (ACSE-Eval), C20 (ARPaCCino) |
| Deployability testing | C02 (plan-level), C07 (full deployment) |
| Security compliance scoring | C02, C07 (8.4% CIS), C09, C10 |
| Peer-reviewed venue | C01 (NeurIPS D&B), C02 (ICSE SEIP), C17 (DAC), C19 (ASE Springer), C20 (CCIS Springer) |
| arXiv preprint | C03, C04, C06, C07, C08, C09, C10, C13, ITAB |

## QGS replay protocol

1. Execute the search string in `protocol/search-strings.md` on each of seven databases (IEEE Xplore, ACM DL, Scopus, Web of Science, dblp, arXiv, Google Scholar).
2. For each database, record the returned set $R_d$.
3. Compute QGS recall as $|R_d \cap \text{QGS}| / |\text{QGS}|$ for each database.
4. Compute QGS recall across the union: $|\bigcup_d R_d \cap \text{QGS}| / |\text{QGS}|$.
5. Target: union recall = 100% (10 of 10). Per-database recall is informational, not gating.
6. If union recall < 100%, identify which QGS papers are missed, inspect their metadata against the search string, refine string terms, re-execute. Repeat until union recall = 100%.
7. Document the final search string and recall metrics in §2 of the manuscript.

## Recall validation log

(To be populated during Task 4 execution.)

| Iteration | Date | Database | Recall | Missed QGS papers | Refinement triggered |
|-----------|------|----------|--------|-------------------|----------------------|
| 1 | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ |

## Precision tracking

After recall = 100% is achieved, document precision (fraction of returned set that meets inclusion criteria) for each database to characterize signal-to-noise.

## References

- Zhang, H., Babar, M. A., & Tell, P. (2011). Identifying relevant studies in software engineering. *Information and Software Technology*, 53(6), 625-637. doi:10.1016/j.infsof.2010.12.010

---

*Search-string validation protocol for the systematic mapping component.*
