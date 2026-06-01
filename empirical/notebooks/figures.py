#!/usr/bin/env python3
"""Plot figures for the empirical security study.

Consumes the CSV outputs of analyze.py and renders publication-quality figures
to ../results/figures/.

Figures:
  - F1 forest plot: per-model misconfiguration rate with Wilson 95% CIs
  - F2 heatmap: per-(model, language) misconfiguration rate
  - F3 heatmap: per-(model, provider) misconfiguration rate
  - F4 heatmap: pairwise Cohen's kappa across scanner pairs
  - F5 bar chart: severity-weighted compliance score per model with bootstrap CIs

All figures: 300 DPI PNG, max 3000 px per side.
"""
from __future__ import annotations

import argparse
import pathlib

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns


def fig_forest_per_model(per_model_scanner: pd.DataFrame, out: pathlib.Path) -> None:
    """One panel per scanner; within each, models on the y-axis with CI bars."""
    if per_model_scanner.empty:
        return
    scanners = sorted(per_model_scanner["scanner"].unique())
    models = sorted(per_model_scanner["model"].unique())
    n_scanners = len(scanners)
    fig, axes = plt.subplots(1, n_scanners, figsize=(3 * n_scanners, 0.4 * len(models) + 1.5),
                             sharey=True, squeeze=False)
    axes = axes[0]
    for ax, scanner in zip(axes, scanners):
        sub = per_model_scanner[per_model_scanner["scanner"] == scanner].sort_values("model")
        y = np.arange(len(sub))
        ax.errorbar(sub["rate"], y, xerr=[sub["rate"] - sub["ci_lo"],
                                          sub["ci_hi"] - sub["rate"]],
                    fmt="o", capsize=3, lw=1)
        ax.set_yticks(y)
        ax.set_yticklabels(sub["model"])
        ax.set_xlim(0, 1)
        ax.set_xlabel("Misconfiguration rate (Wilson 95% CI)")
        ax.set_title(scanner)
        ax.grid(alpha=0.3, axis="x")
        ax.set_axisbelow(True)
    fig.suptitle("Per-model misconfiguration rates by scanner", y=1.02)
    fig.tight_layout()
    fig.savefig(out / "F1_forest_per_model.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def fig_heatmap(df: pd.DataFrame, x: str, y: str, out_path: pathlib.Path, title: str) -> None:
    if df.empty:
        return
    pivot = df.pivot(index=y, columns=x, values="rate")
    fig, ax = plt.subplots(figsize=(max(6, 0.8 * pivot.shape[1] + 2), 0.5 * pivot.shape[0] + 2))
    sns.heatmap(pivot, ax=ax, cmap="RdYlGn_r", annot=True, fmt=".2f",
                vmin=0, vmax=1, cbar_kws={"label": "Misconfiguration rate"})
    ax.set_title(title)
    fig.tight_layout()
    fig.savefig(out_path, dpi=300, bbox_inches="tight")
    plt.close(fig)


def fig_kappa_heatmap(kappa: pd.DataFrame, out: pathlib.Path) -> None:
    if kappa.empty:
        return
    scanners = sorted(set(kappa["scanner_a"]) | set(kappa["scanner_b"]))
    mat = pd.DataFrame(np.eye(len(scanners)), index=scanners, columns=scanners, dtype=float)
    for _, row in kappa.iterrows():
        mat.loc[row["scanner_a"], row["scanner_b"]] = row["cohens_kappa"]
        mat.loc[row["scanner_b"], row["scanner_a"]] = row["cohens_kappa"]
    fig, ax = plt.subplots(figsize=(max(5, 0.8 * len(scanners) + 1), 0.8 * len(scanners) + 1))
    sns.heatmap(mat, ax=ax, cmap="RdBu", annot=True, fmt=".2f",
                vmin=-1, vmax=1, center=0, cbar_kws={"label": "Cohen's kappa"})
    ax.set_title("Pairwise scanner agreement (Cohen's kappa)")
    fig.tight_layout()
    fig.savefig(out / "F4_scanner_kappa.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def fig_severity_bars(scores: pd.DataFrame, out: pathlib.Path) -> None:
    if scores.empty:
        return
    sub = scores.sort_values("severity_weighted_score")
    y = np.arange(len(sub))
    fig, ax = plt.subplots(figsize=(7, 0.45 * len(sub) + 1.5))
    ax.errorbar(sub["severity_weighted_score"], y,
                xerr=[sub["severity_weighted_score"] - sub["ci_lo"],
                      sub["ci_hi"] - sub["severity_weighted_score"]],
                fmt="o", capsize=3, lw=1)
    ax.set_yticks(y)
    ax.set_yticklabels(sub["model"])
    ax.set_xlabel("Severity-weighted compliance score (lower = more compliant)\nPrompt-cluster bootstrap 95% CI")
    ax.set_title("Per-model severity-weighted compliance (prompt-cluster bootstrap 95% CIs)")
    ax.grid(alpha=0.3, axis="x")
    ax.set_axisbelow(True)
    fig.tight_layout()
    fig.savefig(out / "F5_severity_bars.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", type=pathlib.Path, required=True,
                    help="Directory containing CSVs produced by analyze.py")
    args = ap.parse_args()

    figures = args.results / "figures"
    figures.mkdir(parents=True, exist_ok=True)

    pms_path = args.results / "per_model_scanner_rates.csv"
    if pms_path.exists():
        fig_forest_per_model(pd.read_csv(pms_path), figures)

    pml_path = args.results / "per_model_language_rates.csv"
    if pml_path.exists():
        fig_heatmap(pd.read_csv(pml_path), x="language", y="model",
                    out_path=figures / "F2_heatmap_model_language.png",
                    title="Misconfiguration rate by (model, IaC language)")

    pmp_path = args.results / "per_model_provider_rates.csv"
    if pmp_path.exists():
        fig_heatmap(pd.read_csv(pmp_path), x="provider", y="model",
                    out_path=figures / "F3_heatmap_model_provider.png",
                    title="Misconfiguration rate by (model, cloud provider)")

    kappa_path = args.results / "scanner_pairwise_kappa.csv"
    if kappa_path.exists():
        fig_kappa_heatmap(pd.read_csv(kappa_path), figures)

    sev_path = args.results / "severity_weighted_scores.csv"
    if sev_path.exists():
        fig_severity_bars(pd.read_csv(sev_path), figures)

    print(f"Figures written to {figures}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
