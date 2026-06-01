#!/usr/bin/env python3
"""Statistical analysis pipeline for the empirical security study.

Consumes the unified findings JSONL produced by scanners/normalize.py and the
prompt metadata JSONL, and computes:

  - Per-(model, scanner) misconfiguration counts with Wilson 95% CIs
  - Per-(model, language) and per-(model, provider) misconfiguration rates
  - Pairwise model comparisons with Fisher's-exact-test, Holm-Bonferroni corrected
  - Severity-weighted compliance scores with 10,000-iteration bootstrap CIs
  - Pairwise Cohen's kappa across the 10 scanner pairs

All outputs are written as CSV + JSON in ../results/ and as figures (forest
plots, heatmaps) in ../results/figures/.

Usage:
    pip install pandas numpy scipy matplotlib seaborn statsmodels
    python analyze.py \\
        --findings ../scanner-reports/all-findings.jsonl \\
        --prompts ../prompts/prompts.jsonl \\
        --validation ../manual-validation/validation-labels.jsonl \\
        --out ../results
"""
from __future__ import annotations

import argparse
import itertools
import json
import pathlib
from math import sqrt
from typing import Iterable

import numpy as np
import pandas as pd
from scipy import stats


# ---------------------------------------------------------------------------
# Wilson 95% CI
# ---------------------------------------------------------------------------

def wilson_ci(k: int, n: int, z: float = 1.96) -> tuple[float, float, float]:
    """Return (point_estimate, lower, upper) of the Wilson score interval."""
    if n == 0:
        return (0.0, 0.0, 0.0)
    p = k / n
    denom = 1.0 + z * z / n
    centre = (p + z * z / (2.0 * n)) / denom
    halfwidth = z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
    return (p, max(0.0, centre - halfwidth), min(1.0, centre + halfwidth))


# ---------------------------------------------------------------------------
# Severity weighting
# ---------------------------------------------------------------------------

SEVERITY_WEIGHTS = {"INFO": 0.0, "LOW": 1.0, "MEDIUM": 3.0, "HIGH": 7.0, "CRITICAL": 15.0}


def severity_weighted_score(findings: pd.DataFrame) -> float:
    """Lower is more compliant. Sum of severity weights, normalised by sample count."""
    if findings.empty:
        return 0.0
    w = findings["severity"].map(SEVERITY_WEIGHTS).fillna(0.0)
    n_samples = findings[["model", "prompt_id", "sample_id"]].drop_duplicates().shape[0]
    return float(w.sum() / max(n_samples, 1))


def _stable_seed(key: str) -> int:
    """Deterministic per-model seed. The previous implementation used the
    built-in hash(), which is salted per interpreter (PYTHONHASHSEED) and so
    produced non-reproducible bootstrap CIs across runs."""
    import hashlib
    return int.from_bytes(hashlib.md5(key.encode()).digest()[:4], "little")


def bootstrap_severity_ci(findings: pd.DataFrame, n_boot: int = 10000, seed: int = 0) -> tuple[float, float, float]:
    """Prompt-cluster (block) bootstrap of the mean severity weight per flagged
    sample. The unit of resampling is the prompt, not the individual sample: the
    three samples of a prompt answer the same task and are correlated, so
    resampling samples independently understates the variance (the design is
    prompt-blocked). The point estimate is the ratio (total severity weight) /
    (number of flagged samples); each bootstrap replicate resamples the prompts
    with replacement and recomputes that ratio over the resampled block."""
    if findings.empty:
        return (0.0, 0.0, 0.0)
    rng = np.random.default_rng(seed)
    fw = findings.copy()
    fw["__w"] = fw["severity"].map(SEVERITY_WEIGHTS).fillna(0.0)
    per_prompt = fw.groupby("prompt_id").apply(
        lambda g: pd.Series({
            "sumw": float(g["__w"].sum()),
            "nflag": float(g["sample_id"].nunique()),
        }),
        include_groups=False,
    )
    sumw = per_prompt["sumw"].to_numpy()
    nflag = per_prompt["nflag"].to_numpy()
    total_flag = nflag.sum()
    point = float(sumw.sum() / total_flag) if total_flag > 0 else 0.0
    n_clusters = len(per_prompt)
    if n_clusters < 2:
        return (point, point, point)
    boots = np.empty(n_boot)
    for i in range(n_boot):
        idx = rng.integers(0, n_clusters, n_clusters)
        denom = nflag[idx].sum()
        boots[i] = sumw[idx].sum() / denom if denom > 0 else np.nan
    return (point, float(np.nanquantile(boots, 0.025)), float(np.nanquantile(boots, 0.975)))


# ---------------------------------------------------------------------------
# Pairwise model comparisons with Holm-Bonferroni
# ---------------------------------------------------------------------------

def pairwise_fisher(per_model: dict[str, tuple[int, int]]) -> pd.DataFrame:
    """Per-model dict: model -> (clean_samples, flagged_samples).

    Computes Fisher's exact test for every model pair and Holm-Bonferroni
    corrects the resulting p-values across the pair set.
    """
    rows = []
    names = list(per_model.keys())
    for a, b in itertools.combinations(names, 2):
        ka, na = per_model[a]
        kb, nb = per_model[b]
        try:
            _, p = stats.fisher_exact([[ka, na - ka], [kb, nb - kb]], alternative="two-sided")
        except Exception:
            p = float("nan")
        rows.append({"model_a": a, "model_b": b, "p_raw": p,
                     "rate_a": ka / na if na else 0.0,
                     "rate_b": kb / nb if nb else 0.0})
    df = pd.DataFrame(rows)
    if df.empty:
        return df
    # Holm-Bonferroni
    df_sorted = df.sort_values("p_raw").reset_index(drop=True)
    m = len(df_sorted)
    adjusted = []
    running_max = 0.0
    for i, p in enumerate(df_sorted["p_raw"].fillna(1.0)):
        adj = min(1.0, p * (m - i))
        running_max = max(running_max, adj)
        adjusted.append(running_max)
    df_sorted["p_holm"] = adjusted
    df_sorted["significant_at_0.05"] = df_sorted["p_holm"] < 0.05
    return df_sorted


# ---------------------------------------------------------------------------
# Cohen's kappa on per-finding alignment
# ---------------------------------------------------------------------------

def scanner_pair_kappa(findings: pd.DataFrame, scanner_a: str, scanner_b: str) -> float:
    """Compute Cohen's kappa between two scanners.

    Treat each (model, prompt_id, sample_id, rule_id) cell as a unit of agreement.
    A scanner 'agrees' on a finding if it also reports a finding for the same
    (model, prompt_id, sample_id) regardless of rule_id mapping.

    For inter-scanner alignment we use a coarser cell: per-sample any-finding.
    """
    base = findings[["model", "prompt_id", "sample_id"]].drop_duplicates()
    if base.empty:
        return float("nan")
    has_a = findings[findings["scanner"] == scanner_a][["model", "prompt_id", "sample_id"]].drop_duplicates()
    has_b = findings[findings["scanner"] == scanner_b][["model", "prompt_id", "sample_id"]].drop_duplicates()
    has_a["a"] = 1
    has_b["b"] = 1
    merged = base.merge(has_a, on=["model", "prompt_id", "sample_id"], how="left") \
                 .merge(has_b, on=["model", "prompt_id", "sample_id"], how="left")
    merged["a"] = merged["a"].fillna(0).astype(int)
    merged["b"] = merged["b"].fillna(0).astype(int)
    a_vec = merged["a"].to_numpy()
    b_vec = merged["b"].to_numpy()
    po = (a_vec == b_vec).mean()
    pa = (a_vec == 1).mean()
    pb = (b_vec == 1).mean()
    pe = pa * pb + (1 - pa) * (1 - pb)
    if pe == 1.0:
        return 1.0
    return float((po - pe) / (1.0 - pe))


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", type=pathlib.Path, required=True)
    ap.add_argument("--prompts", type=pathlib.Path, required=True)
    ap.add_argument("--validation", type=pathlib.Path, default=None)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--samples-per-pair", type=int, default=3)
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    # Load findings
    findings = pd.read_json(args.findings, lines=True) if args.findings.exists() else pd.DataFrame()
    prompts = pd.read_json(args.prompts, lines=True)

    if findings.empty:
        (args.out / "EMPTY_INPUT.md").write_text(
            "Findings input is empty. Run the LLM generation pipeline and scanner "
            "pipeline first, then re-run analyze.py.\n"
        )
        print(f"WARNING: findings file is empty at {args.findings}. Wrote stub.")
        return 0

    # ---------- Per-(model, scanner) misconfiguration rates ----------
    # Denominator: total attempted samples per model = N_prompts * samples_per_pair.
    # The earlier "distinct sample_id from findings" form silently excluded
    # samples with zero findings (clean code), biasing every rate upward and
    # collapsing pairwise comparisons to p=1.0.
    n_prompts_total = prompts.shape[0]
    n_attempted_per_model = n_prompts_total * args.samples_per_pair
    n_per_model = {m: n_attempted_per_model for m in findings["model"].unique()}
    rows = []
    for (model, scanner), grp in findings.groupby(["model", "scanner"]):
        flagged_samples = grp[["model", "prompt_id", "sample_id"]].drop_duplicates().shape[0]
        n_samples = n_per_model.get(model, 0)
        p, lo, hi = wilson_ci(flagged_samples, n_samples)
        rows.append({"model": model, "scanner": scanner,
                     "flagged_samples": flagged_samples, "total_samples": n_samples,
                     "rate": p, "ci_lo": lo, "ci_hi": hi})
    per_model_scanner = pd.DataFrame(rows).sort_values(["model", "scanner"])
    per_model_scanner.to_csv(args.out / "per_model_scanner_rates.csv", index=False)

    # ---------- Per-(model, language) misconfiguration rates ----------
    findings_lang = findings.merge(prompts[["prompt_id", "language", "provider", "category"]],
                                   on="prompt_id", how="left")
    rows = []
    for (model, language), grp in findings_lang.groupby(["model", "language"]):
        flagged = grp[["model", "prompt_id", "sample_id"]].drop_duplicates().shape[0]
        denom_prompts = prompts[prompts["language"] == language].shape[0]
        n_samples = denom_prompts * args.samples_per_pair
        p, lo, hi = wilson_ci(flagged, n_samples)
        rows.append({"model": model, "language": language,
                     "flagged_samples": flagged, "total_samples": n_samples,
                     "rate": p, "ci_lo": lo, "ci_hi": hi})
    pd.DataFrame(rows).sort_values(["model", "language"]).to_csv(
        args.out / "per_model_language_rates.csv", index=False)

    # ---------- Per-(model, provider) misconfiguration rates ----------
    rows = []
    for (model, provider), grp in findings_lang.groupby(["model", "provider"]):
        flagged = grp[["model", "prompt_id", "sample_id"]].drop_duplicates().shape[0]
        denom_prompts = prompts[prompts["provider"] == provider].shape[0]
        n_samples = denom_prompts * args.samples_per_pair
        p, lo, hi = wilson_ci(flagged, n_samples)
        rows.append({"model": model, "provider": provider,
                     "flagged_samples": flagged, "total_samples": n_samples,
                     "rate": p, "ci_lo": lo, "ci_hi": hi})
    pd.DataFrame(rows).sort_values(["model", "provider"]).to_csv(
        args.out / "per_model_provider_rates.csv", index=False)

    # ---------- Pairwise model comparisons with Holm correction ----------
    per_model = {}
    for model, grp in findings.groupby("model"):
        flagged = grp[["model", "prompt_id", "sample_id"]].drop_duplicates().shape[0]
        per_model[model] = (flagged, n_per_model.get(model, 0))
    pairwise = pairwise_fisher(per_model)
    pairwise.to_csv(args.out / "pairwise_model_comparisons.csv", index=False)

    # ---------- Bootstrap severity-weighted compliance scores ----------
    rows = []
    for model, grp in findings.groupby("model"):
        point, lo, hi = bootstrap_severity_ci(grp, n_boot=10000, seed=_stable_seed(model))
        rows.append({"model": model, "severity_weighted_score": point,
                     "ci_lo": lo, "ci_hi": hi})
    pd.DataFrame(rows).sort_values("severity_weighted_score").to_csv(
        args.out / "severity_weighted_scores.csv", index=False)

    # ---------- Pairwise Cohen's kappa across scanner pairs ----------
    scanners = sorted(findings["scanner"].unique())
    rows = []
    for a, b in itertools.combinations(scanners, 2):
        kappa = scanner_pair_kappa(findings, a, b)
        rows.append({"scanner_a": a, "scanner_b": b, "cohens_kappa": kappa})
    pd.DataFrame(rows).to_csv(args.out / "scanner_pairwise_kappa.csv", index=False)

    # ---------- Manual validation FP/FN if provided ----------
    if args.validation and args.validation.exists():
        val = pd.read_json(args.validation, lines=True)
        # Expected columns: scanner, severity, label in {TP, FP, TN, FN}
        if not val.empty:
            agg = (val.groupby(["scanner", "severity", "label"])
                      .size().unstack(fill_value=0).reset_index())
            agg.to_csv(args.out / "manual_validation_summary.csv", index=False)

    # ---------- Headline report ----------
    headline = {
        "total_findings": int(len(findings)),
        "total_samples": int(sum(n_per_model.values())),
        "models": list(n_per_model.keys()),
        "scanners": scanners,
        "languages": sorted(prompts["language"].unique().tolist()),
        "providers": sorted(prompts["provider"].unique().tolist()),
        "wilson_ci_methodology": "Wilson 1927 score interval, z=1.96",
        "pairwise_correction": "Holm-Bonferroni across "
                              f"{len(pairwise)} pairs",
        "bootstrap_iterations": 10000,
        "severity_weights": SEVERITY_WEIGHTS,
    }
    (args.out / "headline.json").write_text(json.dumps(headline, indent=2))
    print(f"Wrote results to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
