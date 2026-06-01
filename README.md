# Replication Package: Towards Reliable LLM-Assisted Infrastructure as Code

A mixed-methods study of LLM-assisted infrastructure as code (IaC) generation, evaluation, and security: a systematic mapping of 31 studies combined with a multi-LLM empirical security study.

**Author:** Mateen Ali Anjum, Phono Technologies Inc., Kitchener, ON, Canada
**ORCID:** [0009-0001-7231-8515](https://orcid.org/0009-0001-7231-8515)
**License:** Creative Commons Attribution 4.0 International (CC BY 4.0)

## Contents

```
protocol/           Review protocol (PRISMA 2020) and search strategy
  search-strings.md     Database-specific search queries
  prisma-protocol.md    Full review protocol
  qgs-gold-set.md       Quasi-gold-set for search-string validation
extraction/         Data extraction artefacts
  extraction-form.csv     Extraction template
  extraction-codebook.md  Controlled vocabulary and coding rules
  pilot-extraction.csv    Pilot on five seed papers
  pilot-notes.md          Pilot findings and refinements
  full-extraction.csv     Full extraction for all 31 included studies
  corpus-statistics-n31.md  Corpus-level descriptive statistics
screening/          Screening artefacts
  screening-ledger.csv    Inclusion/exclusion decisions with rationale
  pass1-screening.md, pass2-screening.md, borderline-resolution.md,
  candidate-pool.md, reviewer2-screening.md
synthesis/          Synthesis outputs (taxonomy, matrices)
empirical/          Multi-LLM empirical security study
  prompts/              116-prompt JSONL set with provenance
  generations/          LLM-generated IaC artefacts and run summary
  scanner-reports/      Raw and normalized scanner findings (5 scanners)
  results/              Aggregated statistics, GEE model, severity scores
  manual-validation/    Stratified true/false-positive and false-negative labels
  notebooks/            Analysis and figure-generation scripts
  figures/              Publication-ready figures
```

## Empirical study at a glance

- 7 LLMs x 116 hand-crafted prompts x 3 samples = 2,436 generated IaC artefacts
- 5 open-source static scanners (Checkov, tfsec, KICS, Terrascan, Trivy) = 19,727 normalized findings
- 202-finding stratified manual validation and a 50-artefact false-negative screen
- Statistics: Wilson 95% confidence intervals, prompt-clustered GEE logistic regression, Holm-corrected Fisher's exact pairwise tests, bootstrap severity-weighted scores

## Methodology

The mapping component follows PRISMA 2020 reporting guidelines and the mixed-methods empirical-software-engineering design described by Storey et al. (2025). Search-string recall is validated against an author-constructed quasi-gold-set following Zhang, Babar, and Tell (2011). Security and compliance are treated as a cross-cutting analytical dimension across all included studies. The empirical component is exploratory rather than pre-registered; its full design is documented in `empirical/`.

## Citation

If you use these artefacts, please cite the associated article and this archive (concept DOI 10.5281/zenodo.20450830, which always resolves to the latest version).
