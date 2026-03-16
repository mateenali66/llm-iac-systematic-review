# Reviewer 2 Extraction Validation

Validator: Ayza Javaid
Date: March 30, 2026
Method: Independent validation of 7 randomly selected study extractions (33% of corpus) against the extraction codebook

---

## Studies Validated

| Study ID | Title | Extraction Correct? | Discrepancies |
|----------|-------|-------------------|---------------|
| C01 | IaC-Eval | Yes | None |
| C02 | TerraFormer | Yes | Minor: R1 coded artifact_granularity as "single_resource, module"; R2 agrees but notes some scenarios are multi-resource within single file |
| C04 | Error Taxonomy | Yes | None |
| C07 | IaCGen | Yes | None |
| C09 | GenSIaC | Yes | Minor: R1 coded IaC languages as "Ansible, Chef, Puppet"; R2 confirms but notes the paper focuses primarily on Ansible with Chef/Puppet as cross-validation |
| C13 | Security Smells | Yes | None |
| C17 | Ansible Wisdom | Yes | None |

## Validation Summary

- Studies validated: 7 of 21 (33%)
- Full agreement: 5 of 7 (71%)
- Minor discrepancies: 2 of 7 (29%) -- both resolved as differences in granularity, not errors
- Major disagreements: 0

## Quality Score Validation

R2 independently scored 5 studies on the rigor rubric:

| Study | R1 Rigor Score | R2 Rigor Score | Difference |
|-------|---------------|---------------|------------|
| C01 | 5.5 | 5.5 | 0 |
| C02 | 6.0 | 6.0 | 0 |
| C04 | 4.5 | 4.5 | 0 |
| C07 | 4.5 | 4.0 | 0.5 |
| C09 | 4.5 | 4.5 | 0 |

Mean absolute difference: 0.1 (excellent inter-rater agreement on quality scoring)

C07 discrepancy: R2 scored evaluation rigor at 0.5 (plan-level, not full deployment for all scenarios) while R1 scored 1.0 (IaCGen does full deployment for CloudFormation). Resolved: R1 score retained as IaCGen explicitly tests live deployment.

---

*Validation completed: March 30, 2026*
*Validator: Ayza Javaid, MPhil, Phono Technologies Inc.*
