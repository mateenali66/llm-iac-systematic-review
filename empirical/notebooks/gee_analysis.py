#!/usr/bin/env python3
"""Prompt-clustered GEE logistic regression for the cross-model (RQ7) analysis.

This is the model behind Table `tab:emp-gee` in the manuscript. The pooled
Fisher's exact tests in analyze.py treat the 348 samples per model as
independent, but the design is blocked: the same 116 prompts are issued to
every model with three samples each. This script models that structure
directly with a generalized estimating equations (GEE) logistic regression of
the per-artefact flagged outcome on model, clustering on prompt with an
exchangeable working correlation. It reports population-averaged odds ratios
with cluster-robust standard errors over the 116 prompt clusters, relative to
Gemini-2.5-Pro as the reference model.

The artefact-level binary outcome `flagged` is 1 if at least one of the five
scanners reported a finding for that (model, prompt, sample) triple, and 0
otherwise. The denominator is the full 7 x 116 x 3 = 2,436 generation grid:
prompts that produced no findings for a model still contribute clean (0)
artefacts, so the grid is reconstructed from the prompt set, not from the
findings file alone.

Usage:
    pip install pandas numpy statsmodels scipy
    python gee_analysis.py \\
        --findings ../scanner-reports/all-findings.jsonl \\
        --prompts ../prompts/prompts.jsonl \\
        --out ../results/gee_model_vs_gemini.csv

Reproduces ../results/gee_model_vs_gemini.csv. A `--provider-adjusted` flag
adds cloud-provider fixed effects (the robustness check reported in the text).
"""
from __future__ import annotations

import argparse
import pathlib

import numpy as np
import pandas as pd
import statsmodels.api as sm
import statsmodels.formula.api as smf

REFERENCE_MODEL = "gemini-2.5-pro"
SAMPLE_IDS = ["sample_1", "sample_2", "sample_3"]


def build_artefact_grid(findings: pd.DataFrame, prompts: pd.DataFrame) -> pd.DataFrame:
    """Reconstruct the full (model, prompt_id, sample_id) grid with a binary
    `flagged` outcome. flagged = 1 iff the triple appears in findings."""
    models = sorted(findings["model"].unique())
    prompt_ids = prompts["prompt_id"].tolist()
    grid = pd.MultiIndex.from_product(
        [models, prompt_ids, SAMPLE_IDS],
        names=["model", "prompt_id", "sample_id"],
    ).to_frame(index=False)

    flagged_triples = (
        findings[["model", "prompt_id", "sample_id"]]
        .drop_duplicates()
        .assign(flagged=1)
    )
    grid = grid.merge(
        flagged_triples, on=["model", "prompt_id", "sample_id"], how="left"
    )
    grid["flagged"] = grid["flagged"].fillna(0).astype(int)
    return grid


def fit_gee(grid: pd.DataFrame, provider_adjusted: bool = False) -> pd.DataFrame:
    """Fit the prompt-clustered exchangeable-correlation GEE and return a tidy
    frame of odds ratios vs the reference model."""
    grid = grid.copy()
    grid["model"] = pd.Categorical(
        grid["model"],
        categories=[REFERENCE_MODEL]
        + [m for m in sorted(grid["model"].unique()) if m != REFERENCE_MODEL],
    )

    formula = "flagged ~ C(model, Treatment(reference=%r))" % REFERENCE_MODEL
    if provider_adjusted:
        formula += " + C(provider)"

    model = smf.gee(
        formula,
        groups="prompt_id",
        data=grid,
        family=sm.families.Binomial(),
        cov_struct=sm.cov_struct.Exchangeable(),
    )
    res = model.fit()

    rows = []
    conf = res.conf_int()
    for term in res.params.index:
        if not term.startswith("C(model"):
            continue
        # term looks like: C(model, Treatment(reference='gemini-2.5-pro'))[T.llama-3.3-70b]
        name = term.split("[T.")[-1].rstrip("]")
        coef = res.params[term]
        lo, hi = conf.loc[term]
        rows.append(
            {
                "model": name,
                "OR_vs_gemini": float(np.exp(coef)),
                "ci_lo": float(np.exp(lo)),
                "ci_hi": float(np.exp(hi)),
                "p": float(res.pvalues[term]),
            }
        )
    out = pd.DataFrame(rows).sort_values("model").reset_index(drop=True)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", type=pathlib.Path, required=True)
    ap.add_argument("--prompts", type=pathlib.Path, required=True)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--provider-adjusted", action="store_true")
    args = ap.parse_args()

    findings = pd.read_json(args.findings, lines=True)
    prompts = pd.read_json(args.prompts, lines=True)

    grid = build_artefact_grid(findings, prompts)
    if args.provider_adjusted:
        grid = grid.merge(
            prompts[["prompt_id", "provider"]], on="prompt_id", how="left"
        )

    print(
        f"grid: {len(grid)} artefacts "
        f"({grid['model'].nunique()} models x {prompts.shape[0]} prompts x {len(SAMPLE_IDS)} samples), "
        f"flagged={int(grid['flagged'].sum())} ({grid['flagged'].mean():.3%})"
    )

    out = fit_gee(grid, provider_adjusted=args.provider_adjusted)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(args.out, index=False)
    print(f"Wrote {args.out}")
    print(out.to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
