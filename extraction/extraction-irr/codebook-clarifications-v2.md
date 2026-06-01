# Codebook Clarifications (v2) — refined after the pilot inter-rater check

The first independent double-extraction (10 studies, 31 fields) surfaced a small number
of field definitions that two coders read differently. None of these were factual
disagreements about the papers; they were ambiguities in the *coding rules*. This
addendum tightens those rules. It is a normal "pilot IRR refined the protocol" step.

Apply these clarifications, then re-code ONLY the fields listed in
`ayza-RECODE-BLANK.csv` for the 10 studies.

---

## 1. The "absent" vs "not_specified" vs "present" distinction (3-state fields)

Applies to: `module_reuse_state`, `org_policy_context`, `provider_docs_used`.

Use this rule for all three:

- **present / yes** — the paper explicitly shows or states the feature is used
  (e.g. it reuses Terraform modules; it injects provider docs; it encodes org policy).
- **absent / no** — the paper's setup makes clear the feature is **not** used, even if it
  is not called out in words. For a single-resource synthetic benchmark with no modules,
  `module_reuse_state = absent` (not `not_specified`), because the design precludes it.
- **not_specified** — you genuinely cannot tell from the paper whether it is used or not;
  the design neither shows it nor rules it out.

Rule of thumb: if the **study design** answers the question (a single-file synthetic
prompt cannot exercise module reuse), code `absent`/`no`. Reserve `not_specified` for true
"the paper is silent and it could go either way."

`provider_docs_used` specifically: code **yes** only if the method feeds provider
documentation/schemas to the model (e.g. RAG over AWS docs). A model that was merely
pre-trained on public docs is **no**, not yes.

---

## 2. "yes (describe)" fields — code the leading token only

Applies to: `tool_use_external_verifier`.

The codebook value set is `yes (describe), no, not_reported`. The **code** is the first
token. Write the description after it for our records, but for agreement the code is:

- `yes` — any external tool/verifier is used in the loop (linter, plan, scanner, compiler,
  test harness, static-analysis baseline used as an oracle). The specific tools are a free
  note, not part of the code.
- `no` — no external verifier/tool in the loop.
- `not_reported` — the paper does not say.

(So "yes - tflint, Checkov" and "yes" are the SAME code: `yes`.) For consistency, enter
just `yes` / `no` / `not_reported` in the re-code sheet; keep tool lists in the notes.

Also: if a study uses static-analysis tools **as the thing being evaluated against**
(baselines/oracles), that still counts as `yes` for tool use.

---

## 3. Rigor / validation scores — anchored 0 / 0.5 / 1

Applies to: `rigor_clarity`, `rigor_dataset`, `rigor_reproducibility`,
`rigor_evaluation`, `rigor_code_data`, `rigor_validity`, `validation_security`,
`validation_deployment`.

Score each dimension with these anchors (the pilot showed coders split on 0.5 vs 1):

- **1.0** — the dimension is done **fully and explicitly**: a dedicated, complete treatment
  (e.g. a named "Threats to Validity" section for `rigor_validity`; a public repo with
  code AND data AND prompts for `rigor_code_data`).
- **0.5** — done **partially or implicitly**: the dimension is touched but incomplete
  (limitations mentioned in passing but no dedicated section; code public but not data;
  evaluation present but no baselines).
- **0.0** — **absent**: the dimension is not addressed at all.

Field-specific anchors:
- `rigor_validity`: 1.0 only with an explicit limitations/threats discussion of reasonable
  depth; a one-line caveat is 0.5; nothing is 0.
- `rigor_code_data`: 1.0 = code + data + prompts all public; 0.5 = some but not all; 0 = none.
- `rigor_clarity`: 1.0 = explicit RQs or a clearly stated objective; 0.5 = objective only
  inferable; 0 = unclear.
- `validation_security` / `validation_deployment`: 1.0 = a real, reported assessment;
  0.5 = partial/ad-hoc; 0 = none.

When in doubt between two anchors, pick the lower and note why.

---

## 4. Multi-value fields — "code all that apply", primary first

Applies to: `iac_languages`, `cloud_providers`, `failure_categories`,
`security_scanner`, `knowledge_source`, `prompting_method`.

- List **every** value the paper genuinely covers, comma-separated, **primary/dominant
  one first**. Do not omit secondary languages/categories just because they are minor.
- Use the exact controlled spelling (`K8s_YAML`, not "Kubernetes"; `provider_api_mismatch`,
  not "API mismatch").
- For `iac_languages`, `CDK (TypeScript)` and `CDK` are the same code → write `CDK`
  (put the sub-language in notes if needed).
- `prompting_method`: pick the **single dominant** method if the paper has one; use `mixed`
  only when two or more are used roughly equally and none dominates; `structured` is for
  decomposition/sub-task prompting; `not_specified` only if the paper never says.
- `security_scanner`: list the actual tools; `custom security eval` and `custom` are the
  same code → write `custom`. `none` only if no scanner at all.

---

## 5. Two specific recurring calls

- `synthetic_vs_realworld`: code `realworld` if tasks/inputs are drawn from real
  repositories/production artifacts; `synthetic` if authors hand-built the tasks for the
  study; `mixed` if both. A benchmark of hand-written prompts is `synthetic` even if it
  targets real cloud APIs.
- `deployability_tested`: `full_deployment` requires actually applying to a (real or
  simulated) cloud/runtime; `plan_level` is terraform-plan-equivalent; `static_only` is
  parse/syntax checks; `not_tested` is none.

---

After re-coding the listed fields with these rules, return `ayza-RECODE-FILLED.csv`.
We then recompute kappa, adjudicate any remaining disagreements to consensus, and report
the post-clarification figure (noting the codebook was refined after the pilot IRR).
