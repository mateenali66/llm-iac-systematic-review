# Replication Package: Towards Reliable LLM-Assisted Infrastructure as Code

Systematic review of LLM-assisted infrastructure as code (IaC) generation, evaluation, and security.

**Author:** Mateen Ali Anjum, Phono Technologies Inc., Kitchener, ON, Canada
**ORCID:** [0009-0001-7231-8515](https://orcid.org/0009-0001-7231-8515)
**Target Journal:** Journal of Systems and Software (Elsevier)

## Contents

```
protocol/           Review protocol (PRISMA 2020)
  search-strings.md   Database-specific search queries
  prisma-protocol.md  Full review protocol
extraction/         Data extraction artifacts
  extraction-form.csv    Extraction template
  extraction-codebook.md Controlled vocabulary and coding rules
  pilot-extraction.csv   Pilot on 5 seed papers
  pilot-notes.md         Pilot findings and refinements
screening/          Screening artifacts
  screening-ledger.csv   Inclusion/exclusion decisions with rationale
synthesis/          Synthesis outputs (taxonomy, matrices, figures)
pilot/              Security pilot (Checkov/tfsec/OPA scan results)
figures/            Publication-ready figures
template/           Elsevier CAS LaTeX template
```

## Methodology

This review follows PRISMA 2020 reporting guidelines and Kitchenham-style SLR best practices for software engineering research. Security and compliance serve as a cross-cutting analytical dimension across all included studies.

## License

Data and extraction artifacts: CC BY 4.0
