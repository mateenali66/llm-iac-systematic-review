#!/usr/bin/env python3
"""Normalize the raw JSON output of each scanner into a unified JSONL schema.

The unified schema (one row per finding):
{
  "scanner": "checkov" | "tfsec" | "kics" | "terrascan" | "trivy",
  "model": str,                 # LLM model name (from path: raw-dir/<model>/<prompt_id>/<sample>/)
  "prompt_id": str,
  "sample_id": str,             # e.g. "sample_1"
  "rule_id": str,
  "severity": "LOW" | "MEDIUM" | "HIGH" | "CRITICAL" | "INFO",
  "resource": str,              # resource path or address
  "message": str,
  "file": str | None            # source file relative to sample dir
}

Severities are upper-cased and mapped to a common set. Scanner-specific
severity strings are passed through with best-effort canonicalization.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys
from typing import Iterator


SEVERITY_MAP = {
    "info": "INFO",
    "informational": "INFO",
    "low": "LOW",
    "medium": "MEDIUM",
    "moderate": "MEDIUM",
    "high": "HIGH",
    "critical": "CRITICAL",
    "warning": "MEDIUM",
    "warn": "MEDIUM",
    "error": "HIGH",
    "unknown": "INFO",
    "": "INFO",
}


def canon_severity(s: object) -> str:
    if s is None:
        return "INFO"
    return SEVERITY_MAP.get(str(s).strip().lower(), str(s).upper())


def parse_checkov(data: dict) -> Iterator[dict]:
    # checkov json schema varies; handle both old & new layouts
    if "results" in data:
        for kind in ("failed_checks",):
            for r in data["results"].get(kind, []) or []:
                yield {
                    "rule_id": r.get("check_id") or "",
                    "severity": canon_severity(r.get("severity")),
                    "resource": r.get("resource") or r.get("file_path") or "",
                    "message": r.get("check_name") or "",
                    "file": r.get("file_path"),
                }
    elif isinstance(data, list):
        for r in data:
            yield from parse_checkov(r)


def parse_tfsec(data: dict) -> Iterator[dict]:
    for r in data.get("results", []) or []:
        loc = r.get("location") or {}
        yield {
            "rule_id": r.get("rule_id") or r.get("long_id") or "",
            "severity": canon_severity(r.get("severity")),
            "resource": r.get("resource") or loc.get("filename") or "",
            "message": r.get("description") or r.get("rule_description") or "",
            "file": loc.get("filename"),
        }


def parse_kics(data: dict) -> Iterator[dict]:
    for q in data.get("queries", []) or []:
        rid = q.get("query_id") or q.get("query_name") or ""
        sev = q.get("severity") or ""
        msg = q.get("description") or q.get("query_name") or ""
        for f in q.get("files", []) or []:
            yield {
                "rule_id": rid,
                "severity": canon_severity(sev),
                "resource": f.get("resource_name") or f.get("resource_type") or "",
                "message": msg,
                "file": f.get("file_name"),
            }


def parse_terrascan(data: dict) -> Iterator[dict]:
    # terrascan json: results -> violations -> [...]
    res = data.get("results") or {}
    for v in res.get("violations", []) or []:
        yield {
            "rule_id": v.get("rule_id") or "",
            "severity": canon_severity(v.get("severity")),
            "resource": v.get("resource_name") or v.get("resource_type") or "",
            "message": v.get("description") or "",
            "file": v.get("file"),
        }


def parse_trivy(data: dict) -> Iterator[dict]:
    for result in data.get("Results", []) or []:
        target = result.get("Target", "")
        for m in result.get("Misconfigurations", []) or []:
            yield {
                "rule_id": m.get("ID") or m.get("AVDID") or "",
                "severity": canon_severity(m.get("Severity")),
                "resource": target,
                "message": m.get("Title") or m.get("Description") or "",
                "file": target,
            }


PARSERS = {
    "checkov": parse_checkov,
    "tfsec": parse_tfsec,
    "kics": parse_kics,
    "terrascan": parse_terrascan,
    "trivy": parse_trivy,
}


def normalize_directory(raw_dir: pathlib.Path) -> Iterator[dict]:
    """Walk raw-dir/<model>/<prompt_id>/<sample>/ and yield unified findings."""
    for model_dir in sorted(p for p in raw_dir.iterdir() if p.is_dir()):
        model = model_dir.name
        for prompt_dir in sorted(p for p in model_dir.iterdir() if p.is_dir()):
            prompt_id = prompt_dir.name
            for sample_dir in sorted(p for p in prompt_dir.iterdir() if p.is_dir()):
                sample_id = sample_dir.name
                for scanner, parser in PARSERS.items():
                    f = sample_dir / f"{scanner}.json"
                    # Checkov writes a directory containing results_json.json
                    if f.is_dir():
                        candidate = f / "results_json.json"
                        f = candidate if candidate.exists() else f
                    if not f.exists() or not f.is_file() or f.stat().st_size == 0:
                        continue
                    try:
                        with f.open() as fh:
                            data = json.load(fh)
                    except json.JSONDecodeError:
                        sys.stderr.write(f"WARN: malformed JSON in {f}\n")
                        continue
                    for finding in parser(data):
                        out = {
                            "scanner": scanner,
                            "model": model,
                            "prompt_id": prompt_id,
                            "sample_id": sample_id,
                        }
                        out.update(finding)
                        yield out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw-dir", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with args.output.open("w") as out:
        for row in normalize_directory(args.raw_dir):
            out.write(json.dumps(row, ensure_ascii=False) + "\n")
            n += 1
    sys.stderr.write(f"Wrote {n} normalized findings to {args.output}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
