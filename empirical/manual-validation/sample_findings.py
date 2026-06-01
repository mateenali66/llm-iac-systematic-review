#!/usr/bin/env python3
"""Stratified sampler for the manual-validation sub-study.

Reads ../scanner-reports/all-findings.jsonl and selects ~150 findings
stratified by (scanner, severity, model_family) so that every cell has at
least the floor sample count (default 3) and the overall sample size hits
the requested target. Writes:

    validation-input.jsonl   one row per sampled finding with the fields
                             needed to validate it (including the IaC source
                             snippet path)

    validation-template.jsonl one row per sampled finding with empty 'label'
                             and 'rationale' fields ready for human entry

Usage:
    python sample_findings.py \\
        --findings ../scanner-reports/all-findings.jsonl \\
        --prompts ../prompts/prompts.jsonl \\
        --generations ../generations \\
        --out . \\
        --target 150
"""
from __future__ import annotations

import argparse
import json
import pathlib
import random
import sys
from collections import Counter, defaultdict


MODEL_TO_FAMILY = {
    "gpt-5":           "closed-source",
    "claude-opus-4-7": "closed-source",
    "gemini-2.5-pro":  "closed-source",
    "grok-4-3":        "closed-source",
    "llama-3.3-70b":   "open-weight",
    "qwen3-coder":     "code-specialist",
    "deepseek-v3-2":   "reasoning",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", required=True, type=pathlib.Path)
    ap.add_argument("--prompts", required=True, type=pathlib.Path)
    ap.add_argument("--generations", required=True, type=pathlib.Path,
                    help="Generations root; used to attach IaC source snippet paths")
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--target", type=int, default=150)
    ap.add_argument("--floor-per-cell", type=int, default=3)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    if not args.findings.exists():
        print(f"ERROR: findings not found at {args.findings}", file=sys.stderr)
        return 2

    # Load prompts for language/provider metadata
    with args.prompts.open() as f:
        prompts = {json.loads(l)["prompt_id"]: json.loads(l) for l in f if l.strip()}
    # re-parse since dict comprehension above re-reads the line twice incorrectly; do it cleanly:
    prompts = {}
    with args.prompts.open() as f:
        for l in f:
            if l.strip():
                p = json.loads(l)
                prompts[p["prompt_id"]] = p

    # Bucket findings by (scanner, severity, model_family)
    rng = random.Random(args.seed)
    buckets: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    n_total = 0
    with args.findings.open() as f:
        for line in f:
            if not line.strip():
                continue
            r = json.loads(line)
            n_total += 1
            family = MODEL_TO_FAMILY.get(r["model"], "unknown")
            buckets[(r["scanner"], r["severity"], family)].append(r)

    if n_total == 0:
        print("ERROR: findings file is empty; run scanner pipeline first.", file=sys.stderr)
        return 2

    print(f"Loaded {n_total} findings across {len(buckets)} (scanner, severity, family) cells.")

    args.out.mkdir(parents=True, exist_ok=True)

    # 1) Floor-fill: take min(floor, len) from each non-empty cell
    selected: list[dict] = []
    selected_ids: set[tuple] = set()
    for key in sorted(buckets.keys()):
        cell = buckets[key]
        take = min(args.floor_per_cell, len(cell))
        rng.shuffle(cell)
        for f in cell[:take]:
            uid = (f["scanner"], f["model"], f["prompt_id"],
                   f["sample_id"], f["rule_id"], f["resource"])
            if uid in selected_ids:
                continue
            selected_ids.add(uid)
            selected.append(f)

    # 2) Top-up: fill the remaining slots proportionally to bucket size
    remaining_target = max(0, args.target - len(selected))
    if remaining_target > 0:
        flat = [f for key, cell in buckets.items() for f in cell]
        rng.shuffle(flat)
        for f in flat:
            uid = (f["scanner"], f["model"], f["prompt_id"],
                   f["sample_id"], f["rule_id"], f["resource"])
            if uid in selected_ids:
                continue
            selected_ids.add(uid)
            selected.append(f)
            if len(selected) >= args.target:
                break

    rng.shuffle(selected)  # randomize validation order

    # Write input + template files
    input_path = args.out / "validation-input.jsonl"
    template_path = args.out / "validation-template.jsonl"

    with input_path.open("w") as fi, template_path.open("w") as ft:
        for i, f in enumerate(selected, 1):
            p = prompts.get(f["prompt_id"], {})
            generation_path = (args.generations / f["model"] / f["prompt_id"] / f["sample_id"])
            input_row = {
                "validation_id": f"V{i:03d}",
                "scanner": f["scanner"],
                "model": f["model"],
                "model_family": MODEL_TO_FAMILY.get(f["model"], "unknown"),
                "prompt_id": f["prompt_id"],
                "language": p.get("language"),
                "provider": p.get("provider"),
                "category": p.get("category"),
                "sample_id": f["sample_id"],
                "rule_id": f["rule_id"],
                "severity": f["severity"],
                "resource": f.get("resource"),
                "message": f.get("message"),
                "file": f.get("file"),
                "generation_path": str(generation_path),
                "original_prompt": p.get("prompt"),
            }
            fi.write(json.dumps(input_row, ensure_ascii=False) + "\n")

            template_row = {
                "validation_id": input_row["validation_id"],
                "scanner": f["scanner"],
                "model": f["model"],
                "prompt_id": f["prompt_id"],
                "sample_id": f["sample_id"],
                "rule_id": f["rule_id"],
                "severity": f["severity"],
                "label": "",          # TP | FP | TN | FN
                "rationale": "",      # 1-2 sentence justification, may cite CIS rule ID
                "cis_benchmark_id": "" # optional, e.g. "CIS AWS 2.1.1"
            }
            ft.write(json.dumps(template_row, ensure_ascii=False) + "\n")

    # Cell-coverage summary
    sel_buckets: Counter = Counter()
    for f in selected:
        sel_buckets[(f["scanner"], f["severity"],
                     MODEL_TO_FAMILY.get(f["model"], "unknown"))] += 1

    summary_path = args.out / "sample-summary.json"
    summary_path.write_text(json.dumps({
        "seed": args.seed,
        "target": args.target,
        "floor_per_cell": args.floor_per_cell,
        "selected": len(selected),
        "n_total_findings": n_total,
        "n_cells": len(buckets),
        "n_cells_with_at_least_1_selected": len(sel_buckets),
        "by_scanner": dict(Counter(f["scanner"] for f in selected)),
        "by_severity": dict(Counter(f["severity"] for f in selected)),
        "by_model_family": dict(Counter(
            MODEL_TO_FAMILY.get(f["model"], "unknown") for f in selected
        )),
        "by_model": dict(Counter(f["model"] for f in selected)),
    }, indent=2))

    print(f"Selected {len(selected)} findings stratified across "
          f"{len(sel_buckets)} (scanner, severity, family) cells")
    print(f"Wrote: {input_path}")
    print(f"Wrote: {template_path}  (fill 'label' and 'rationale' per row)")
    print(f"Wrote: {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
