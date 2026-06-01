#!/usr/bin/env python3
"""Compute inter-rater agreement between the author's extraction and Ayza's
independent re-extraction of the stratified 10-study sample.

Run AFTER Ayza returns `ayza-extraction-FILLED.csv`:

    python3 compute_extraction_kappa.py \
        --author .author-codings-DO-NOT-SHARE.csv \
        --ayza   ayza-extraction-FILLED.csv \
        --out    extraction-irr-results.json

Reports, per field and pooled:
  - raw percent agreement
  - Cohen's kappa (with the standard small-sample / single-category guards)
For comma-separated multi-value fields (e.g. iac_languages, failure_categories)
agreement is exact set match after normalization. Ordinal rigor/validation
scores (0 / 0.5 / 1) are treated as nominal categories for kappa, and a
quadratic-weighted kappa is additionally reported for them.

No external dependencies (pure stdlib), so it runs anywhere Python 3 runs.
"""
import argparse, csv, json, math
from collections import defaultdict

MULTI = {"iac_languages", "cloud_providers", "failure_categories",
         "knowledge_source", "security_scanner", "evaluation_metrics"}
ORDINAL = {"rigor_clarity", "rigor_dataset", "rigor_reproducibility",
           "rigor_evaluation", "rigor_code_data", "rigor_validity",
           "validation_security", "validation_deployment"}


def norm(v):
    return (v or "").strip().lower().replace(" ", "")


def norm_multi(v):
    parts = [p.strip().lower() for p in (v or "").split(",") if p.strip()]
    return frozenset(parts)


def cohen_kappa(pairs):
    """pairs: list of (a, b) hashable labels. Returns (kappa, p_observed, n)."""
    n = len(pairs)
    if n == 0:
        return None, None, 0
    agree = sum(1 for a, b in pairs if a == b)
    po = agree / n
    cats = set()
    for a, b in pairs:
        cats.add(a); cats.add(b)
    if len(cats) == 1:
        # both raters used a single identical category for every item:
        # perfect agreement, kappa undefined (no variance) -> report 1.0 by convention
        return (1.0 if po == 1.0 else 0.0), po, n
    ca = defaultdict(int); cb = defaultdict(int)
    for a, b in pairs:
        ca[a] += 1; cb[b] += 1
    pe = sum((ca[c] / n) * (cb[c] / n) for c in cats)
    if pe == 1.0:
        return 1.0 if po == 1.0 else 0.0, po, n
    return (po - pe) / (1 - pe), po, n


def weighted_kappa_ordinal(pairs):
    """Quadratic-weighted kappa for ordinal numeric labels (e.g. 0,0.5,1)."""
    vals = sorted({v for p in pairs for v in p})
    if len(vals) < 2:
        return None
    idx = {v: i for i, v in enumerate(vals)}
    k = len(vals)
    n = len(pairs)
    O = [[0] * k for _ in range(k)]
    for a, b in pairs:
        O[idx[a]][idx[b]] += 1
    ra = [sum(O[i]) for i in range(k)]
    cb = [sum(O[i][j] for i in range(k)) for j in range(k)]
    W = [[((i - j) ** 2) / ((k - 1) ** 2) for j in range(k)] for i in range(k)]
    num = sum(W[i][j] * O[i][j] for i in range(k) for j in range(k))
    den = sum(W[i][j] * ra[i] * cb[j] / n for i in range(k) for j in range(k))
    if den == 0:
        return None
    return 1 - num / den


def to_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--author", required=True)
    ap.add_argument("--ayza", required=True)
    ap.add_argument("--out", default="extraction-irr-results.json")
    a = ap.parse_args()

    A = {r["study_id"]: r for r in csv.DictReader(open(a.author, newline=""))}
    B = {r["study_id"]: r for r in csv.DictReader(open(a.ayza, newline=""))}
    ids = sorted(set(A) & set(B))
    if not ids:
        raise SystemExit("No overlapping study_id rows between the two files.")

    # fields = the recoded fields present in the author file (minus study_id)
    fields = [f for f in A[ids[0]].keys() if f != "study_id"]

    per_field = {}
    all_pairs = []  # for pooled nominal kappa across non-ordinal categorical fields
    for f in fields:
        pairs = []
        for sid in ids:
            av, bv = A[sid].get(f, ""), B[sid].get(f, "")
            if f in MULTI:
                pairs.append((norm_multi(av), norm_multi(bv)))
            elif f in ORDINAL:
                pairs.append((to_float(av), to_float(bv)))
            else:
                pairs.append((norm(av), norm(bv)))
        k, po, n = cohen_kappa(pairs)
        entry = {"n": n, "raw_agreement": round(po, 4) if po is not None else None,
                 "cohen_kappa": round(k, 4) if k is not None else None}
        if f in ORDINAL:
            wk = weighted_kappa_ordinal([(x, y) for x, y in pairs if x is not None and y is not None])
            entry["weighted_kappa_quadratic"] = round(wk, 4) if wk is not None else None
        else:
            all_pairs.extend(pairs)  # pool only nominal fields
        # record disagreements for adjudication
        dis = []
        for sid in ids:
            av, bv = A[sid].get(f, ""), B[sid].get(f, "")
            same = (norm_multi(av) == norm_multi(bv)) if f in MULTI else \
                   (to_float(av) == to_float(bv)) if f in ORDINAL else (norm(av) == norm(bv))
            if not same:
                dis.append({"study_id": sid, "author": av, "ayza": bv})
        entry["disagreements"] = dis
        per_field[f] = entry

    pk, ppo, pn = cohen_kappa(all_pairs)
    overall = {
        "pooled_nominal_kappa": round(pk, 4) if pk is not None else None,
        "pooled_nominal_raw_agreement": round(ppo, 4) if ppo is not None else None,
        "pooled_decisions": pn,
        "mean_per_field_kappa": round(
            sum(v["cohen_kappa"] for v in per_field.values() if v["cohen_kappa"] is not None) /
            max(1, sum(1 for v in per_field.values() if v["cohen_kappa"] is not None)), 4),
        "fields": len(fields),
        "studies_compared": len(ids),
    }

    result = {"overall": overall, "per_field": per_field, "studies": ids}
    json.dump(result, open(a.out, "w"), indent=2)

    # human-readable summary
    print(f"Studies compared: {len(ids)}  ({', '.join(ids)})")
    print(f"Fields compared:  {len(fields)}")
    print(f"\nPOOLED nominal Cohen's kappa : {overall['pooled_nominal_kappa']}  "
          f"(raw agreement {overall['pooled_nominal_raw_agreement']}, n={pn} decisions)")
    print(f"Mean per-field kappa         : {overall['mean_per_field_kappa']}")
    print("\nPer-field (kappa | raw):")
    for f, v in per_field.items():
        nd = len(v["disagreements"])
        wk = f"  wq={v['weighted_kappa_quadratic']}" if "weighted_kappa_quadratic" in v else ""
        print(f"  {f:28} k={str(v['cohen_kappa']):>7} | raw={str(v['raw_agreement']):>6} | {nd} disagree{wk}")
    print(f"\nFull results + disagreement log written to {a.out}")
    print("Adjudicate each disagreement, record the final agreed value, and report "
          "the pooled kappa (and, for rigor scores, the quadratic-weighted kappa) in the manuscript.")


if __name__ == "__main__":
    main()
