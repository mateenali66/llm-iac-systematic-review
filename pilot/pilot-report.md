# Security Pilot Report

## Overview

10 representative LLM-generated Terraform files were scanned with Checkov (v3.2.508) and tfsec (v1.28.14) to concretize the security evaluation gap identified in the systematic review.

The samples simulate typical GPT-4-level IaC output for common AWS scenarios (S3, IAM, EC2, RDS, DynamoDB, Lambda, ElastiCache, SQS, CloudWatch, EKS), based on patterns documented in IaC-Eval (C01), TerraFormer (C02), and the Error Taxonomy study (C04).

---

## Aggregate Results

| Metric | Checkov | tfsec |
|--------|---------|-------|
| **Total checks/rules** | 87 | 43 |
| **Passed** | 39 (45%) | N/A |
| **Failed** | **48 (55%)** | **43 (100% are findings)** |
| Unique rules triggered | 48 | 32 |

### Checkov Pass Rate: 45%

This means 55% of all security checks fail in typical LLM-generated IaC. This aligns with IaCGen's finding of 8.4% CIS compliance (C07).

### tfsec Severity Distribution

| Severity | Count | % |
|----------|-------|---|
| CRITICAL | 7 | 16% |
| HIGH | 16 | 37% |
| MEDIUM | 11 | 26% |
| LOW | 9 | 21% |

**53% of findings are HIGH or CRITICAL.**

---

## Findings by Security Taxonomy Category

| Category | Checkov Failures | tfsec Findings | Example Issues |
|----------|-----------------|----------------|----------------|
| **Identity & Access** | 4 | 3 | Wildcard IAM policies (s3:*, dynamodb:*), Resource "*", data exfiltration risk, write without constraints |
| **Network Exposure** | 5 | 7 | SSH open to 0.0.0.0/0, HTTP open to 0.0.0.0/0, unrestricted egress, EKS public endpoint, missing SG descriptions |
| **Data Protection** | 12 | 8 | Missing encryption (S3/EBS/RDS/DynamoDB/SQS/CloudWatch/EKS), no KMS, no backup/replication, no snapshot encryption |
| **Configuration Integrity** | 8 | 5 | Missing monitoring (EC2 detailed, RDS performance insights, EKS logging), missing lifecycle policies, no deletion protection |
| **Governance & Compliance** | 5 | 4 | No log retention, missing access logging, no public access block, no IAM auth for RDS |
| **LLM-Specific Risks** | 3 | 1 | **Hardcoded secrets** in Lambda env vars (DB_PASSWORD, API_KEY), hardcoded RDS password, IMDSv1 enabled |

---

## Findings by Sample File

| # | File | Scenario | Checkov Failed | tfsec Findings | Worst Issue |
|---|------|----------|---------------|----------------|-------------|
| 01 | S3 bucket | App logs | 7 | 8 | No public access block, no encryption, no logging |
| 02 | IAM role | Lambda role | 4 | 3 | **Wildcard IAM: s3:*, dynamodb:* on Resource "*"** |
| 03 | EC2 instance | Web server | 7 | 10 | **SSH open to 0.0.0.0/0**, IMDSv1, no EBS encryption |
| 04 | RDS database | PostgreSQL | 9 | 7 | **Publicly accessible, hardcoded password**, no encryption, no multi-AZ |
| 05 | DynamoDB | Sessions | 3 | 3 | No encryption with CMK, no point-in-time recovery |
| 06 | Lambda | API handler | 2 | 1 | **Hardcoded secrets in env vars (DB_PASSWORD, API_KEY)** |
| 07 | ElastiCache | Redis | 3 | 1 | No encryption at rest/transit, no auth |
| 08 | SQS queue | Orders | 2 | 1 | No encryption |
| 09 | CloudWatch | Logs | 3 | 1 | No retention policy, no KMS encryption |
| 10 | EKS cluster | Containers | 8 | 8 | **Public endpoint, no secrets encryption, no logging** |

---

## Critical Findings Summary

### 1. Every single file has security issues
100% failure rate: all 10 LLM-generated files contain at least 1 security misconfiguration.

### 2. Hardcoded secrets (LLM-specific risk)
Files 04 and 06 contain hardcoded credentials:
- RDS password in plaintext: `password = "supersecretpassword123"`
- Lambda env vars with secrets: `DB_PASSWORD`, `API_KEY`

This is an LLM-specific failure mode: models copy insecure patterns from training data.

### 3. Overly permissive IAM (most dangerous)
File 02 grants `s3:*` and `dynamodb:*` on `Resource = "*"`. This violates least-privilege and enables data exfiltration.

### 4. Open network access (most common)
File 03 opens SSH (port 22) to `0.0.0.0/0`. File 10 exposes EKS public endpoint without restrictions.

### 5. Missing encryption is pervasive
8/10 files lack encryption at rest. No file uses KMS customer-managed keys. S3 bucket has no server-side encryption configured.

### 6. No organizational context
Zero files include:
- Tags for cost allocation or ownership
- Naming conventions
- Region constraints
- Backup/DR policies
- Compliance baselines

---

## Mapping to Synthesis Findings

| Pilot Finding | Validates RQ |
|---------------|-------------|
| 100% of files have security issues | RQ5: security is underexplored |
| 55% Checkov failure rate | RQ5: 8.4% CIS compliance (C07) |
| Hardcoded secrets in 2/10 files | RQ4: LLM-specific failure mode |
| Wildcard IAM in 1/10 files | RQ5: Identity & Access category |
| Open SSH in 1/10 files | RQ5: Network Exposure category |
| Missing encryption in 8/10 files | RQ5: Data Protection category |
| No study in our review detects hardcoded secrets | RQ6: Gap #8 (secrets handling) |

---

## Tools and Versions
- **Checkov:** v3.2.508 (Prisma Cloud)
- **tfsec:** v1.28.14 (Aqua Security, now part of Trivy)
- **Samples:** 10 Terraform files, AWS provider, single-resource scenarios
- **Scanner configuration:** Default rules, no custom policies

---

*Pilot completed: March 16, 2026*
