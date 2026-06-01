#!/usr/bin/env python3
"""Parallel scanner runner. Cross-platform (macOS BSD xargs lacks -d).

Runs all 5 scanners on every sample concurrently using a thread pool.
Per-sample, the 5 scanner containers run sequentially (they share /in
and write distinct output files). Concurrency is across samples.

Idempotent: skips samples with a .done marker.
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import pathlib
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

SCANNERS = [
    # (name, docker_args_factory)
    # Each factory takes (sample_dir, out_base) and returns the docker run argv list.
    ("checkov", lambda sd, ob: [
        "docker", "run", "--rm",
        "-v", f"{sd}:/in:ro", "-v", f"{ob}:/out",
        "bridgecrew/checkov:3.2.358",
        "-d", "/in", "-o", "json",
        "--output-file-path", "/out/checkov.json", "--soft-fail",
    ]),
    ("tfsec", lambda sd, ob: [
        "docker", "run", "--rm",
        "-v", f"{sd}:/in:ro", "-v", f"{ob}:/out",
        "aquasec/tfsec:v1.28.13",
        "/in", "--no-color", "--soft-fail", "--format", "json",
        "--out", "/out/tfsec.json",
    ]),
    ("kics", lambda sd, ob: [
        "docker", "run", "--rm",
        "-v", f"{sd}:/in:ro", "-v", f"{ob}:/out",
        "checkmarx/kics:v2.1.7",
        "scan", "-p", "/in", "-o", "/out",
        "--output-name", "kics", "--report-formats", "json",
    ]),
    ("terrascan", lambda sd, ob: [
        "docker", "run", "--rm",
        "-v", f"{sd}:/in:ro", "-v", f"{ob}:/out",
        "tenable/terrascan:1.19.9",
        "scan", "-d", "/in", "-o", "json",
    ]),
    ("trivy", lambda sd, ob: [
        "docker", "run", "--rm",
        "-v", f"{sd}:/in:ro", "-v", f"{ob}:/out",
        "aquasec/trivy:0.58.1",
        "config", "--format", "json", "--output", "/out/trivy.json", "/in",
    ]),
]


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def scan_one(sample_dir: pathlib.Path, target_rel: str, reports_dir: pathlib.Path,
             timeout: int = 120) -> tuple[str, str | None]:
    """Run all 5 scanners on a sample. Return (target_rel, error_msg or None)."""
    out_base = reports_dir / "raw" / target_rel
    out_base.mkdir(parents=True, exist_ok=True)

    for name, build_cmd in SCANNERS:
        cmd = build_cmd(str(sample_dir), str(out_base))
        try:
            if name == "terrascan":
                # Terrascan writes to stdout; redirect to file.
                with (out_base / "terrascan.json").open("w") as f:
                    subprocess.run(cmd, stdout=f, stderr=subprocess.DEVNULL,
                                   timeout=timeout, check=False)
            else:
                subprocess.run(cmd, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL,
                               timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            return target_rel, f"{name} timeout"
        except Exception as e:
            return target_rel, f"{name} error: {e}"

    (out_base / ".done").touch()
    return target_rel, None


def build_worklist(gen_root: pathlib.Path, reports_dir: pathlib.Path) -> list[tuple[pathlib.Path, str]]:
    work = []
    for model_dir in sorted(gen_root.iterdir()):
        if not model_dir.is_dir():
            continue
        for prompt_dir in sorted(model_dir.iterdir()):
            if not prompt_dir.is_dir():
                continue
            for sample_dir in sorted(prompt_dir.iterdir()):
                if not sample_dir.is_dir() or not sample_dir.name.startswith("sample_"):
                    continue
                target_rel = f"{model_dir.name}/{prompt_dir.name}/{sample_dir.name}"
                done_marker = reports_dir / "raw" / target_rel / ".done"
                if done_marker.exists():
                    continue
                work.append((sample_dir, target_rel))
    return work


def main() -> int:
    ap = argparse.ArgumentParser()
    here = pathlib.Path(__file__).parent.resolve()
    ap.add_argument("--generations", type=pathlib.Path,
                    default=here.parent / "generations")
    ap.add_argument("--reports", type=pathlib.Path,
                    default=here.parent / "scanner-reports")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--timeout", type=int, default=180,
                    help="Per-scanner timeout in seconds")
    ap.add_argument("--progress-interval", type=int, default=30)
    args = ap.parse_args()

    if not args.generations.exists() or not any(args.generations.iterdir()):
        print(f"ERROR: empty generations dir {args.generations}", file=sys.stderr)
        return 1

    args.reports.mkdir(parents=True, exist_ok=True)
    (args.reports / "raw").mkdir(exist_ok=True)

    print(f"[{now()}] building worklist...", flush=True)
    work = build_worklist(args.generations, args.reports)
    total = len(work)
    if total == 0:
        print(f"[{now()}] nothing to do; all samples have .done markers.", flush=True)
        return 0

    print(f"[{now()}] {total} samples queued, workers={args.workers}", flush=True)
    est_hours = total * 16 / 3600 / args.workers
    print(f"[{now()}] estimated wall time: {est_hours:.2f} hours", flush=True)

    completed = 0
    errors = 0
    last_progress = time.time()
    start = time.time()
    lock = threading.Lock()

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(scan_one, sd, tr, args.reports, args.timeout): tr
                   for sd, tr in work}
        for fut in as_completed(futures):
            tr = futures[fut]
            try:
                target_rel, err = fut.result()
                if err:
                    with lock:
                        errors += 1
                    print(f"[{now()}] ERR {target_rel}: {err}", flush=True)
            except Exception as e:
                with lock:
                    errors += 1
                print(f"[{now()}] EXC {tr}: {e}", flush=True)
            with lock:
                completed += 1
                if time.time() - last_progress >= args.progress_interval:
                    elapsed = time.time() - start
                    rate = completed / elapsed if elapsed > 0 else 0
                    eta = (total - completed) / rate / 60 if rate > 0 else 0
                    print(f"[{now()}] progress: {completed}/{total} "
                          f"({100*completed/total:.1f}%) "
                          f"rate={rate*60:.1f}/min ETA={eta:.1f}min errors={errors}",
                          flush=True)
                    last_progress = time.time()

    print(f"[{now()}] done. completed={completed} errors={errors}", flush=True)
    return 0 if errors == 0 else 0  # don't fail on per-sample errors


if __name__ == "__main__":
    raise SystemExit(main())
