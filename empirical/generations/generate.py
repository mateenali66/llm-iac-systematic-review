#!/usr/bin/env python3
"""LLM generation pipeline for the empirical security study.

Uses Abacus.AI RouteLLM (https://routellm.abacus.ai/v1) as the single
OpenAI-compatible endpoint to access all seven evaluated models.

Features:
  - Per-(model, prompt, sample) idempotency: skips already-written outputs
  - Per-request retries with exponential backoff on transient errors
    (524, 503, 502, 500, 429, network timeouts)
  - Thread-pool concurrency across models (one worker per model by default)
    so a slow/throttled model doesn't block the others
  - Chunked execution via --chunk-id / --chunk-count for splitting work
    across multiple machines or runs
  - Heartbeat log every N completions for progress monitoring

Usage:
    pip install -r requirements.txt
    export ABACUS_API_KEY=...
    # Local laptop (single chunk, parallel models):
    python generate.py --prompts ../prompts/prompts.jsonl --out . --samples 3 --workers 7

    # EC2 (chunked, e.g. chunk 1 of 4):
    python generate.py --prompts ../prompts/prompts.jsonl --out . \\
        --samples 3 --workers 7 --chunk-id 1 --chunk-count 4
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import pathlib
import random
import re
import sys
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


ABACUS_BASE_URL = "https://routellm.abacus.ai/v1"


@dataclass
class ModelConfig:
    name: str
    model_id: str
    family: str


MODELS: list[ModelConfig] = [
    ModelConfig("gpt-5",           "gpt-5",                                          "closed-source"),
    ModelConfig("claude-opus-4-7", "claude-opus-4-7",                                "closed-source"),
    ModelConfig("gemini-2.5-pro",  "gemini-2.5-pro",                                 "closed-source"),
    ModelConfig("llama-3.3-70b",   "llama-3.3-70b-versatile",                        "open-weight"),
    ModelConfig("qwen3-coder",     "qwen/qwen3-coder-480b-a35b-instruct",            "code-specialist"),
    ModelConfig("deepseek-v4-flash", "deepseek-v4-flash",                             "reasoning"),
    ModelConfig("grok-4-3",        "grok-4.3",                                       "closed-source"),
]


SYSTEM_PROMPT = (
    "You are an expert DevOps engineer. Generate production-quality "
    "Infrastructure as Code (IaC) in response to the user's natural-language "
    "request. Output ONLY the IaC code (no explanation, no markdown fences) "
    "in the language explicitly specified by the user. Apply best practices "
    "appropriate to a real production deployment, including security defaults."
)


LANGUAGE_LABELS = {
    "terraform":      "Terraform (HCL .tf format)",
    "cloudformation": "AWS CloudFormation (YAML)",
    "cdk_python":     "AWS CDK in Python",
    "cdk_typescript": "AWS CDK in TypeScript",
    "azure_bicep":    "Azure Bicep",
    "gcp_dm":         "GCP Deployment Manager (YAML config)",
    "k8s_yaml":       "Kubernetes manifest (YAML)",
    "helm":           ("Helm chart templates (YAML; provide Chart.yaml, values.yaml, and templates/ "
                       "as separate files concatenated with '---' YAML document separators and clearly "
                       "labeled '# FILE: <path>' comments)"),
    "ansible":        "Ansible playbook (YAML)",
}


LANG_TO_EXT = {
    "terraform":      "tf",
    "cloudformation": "yaml",
    "cdk_python":     "py",
    "cdk_typescript": "ts",
    "azure_bicep":    "bicep",
    "gcp_dm":         "yaml",
    "k8s_yaml":       "yaml",
    "helm":           "yaml",
    "ansible":        "yml",
}


# ---------------------------------------------------------------------------
# Provider client
# ---------------------------------------------------------------------------

_client_lock = threading.Lock()
_client = None


def get_client():
    global _client
    with _client_lock:
        if _client is None:
            from openai import OpenAI
            api_key = os.environ.get("ABACUS_API_KEY")
            if not api_key:
                raise RuntimeError("ABACUS_API_KEY environment variable is not set")
            _client = OpenAI(api_key=api_key, base_url=ABACUS_BASE_URL, timeout=180.0)
        return _client


TRANSIENT_STATUS = {429, 500, 502, 503, 504, 524}


def call_abacus_with_retry(model_id: str, prompt: str, max_retries: int = 4) -> tuple[str, dict]:
    """Retry on transient errors with exponential backoff and jitter."""
    client = get_client()
    delay = 5.0  # initial backoff
    last_exc: Optional[BaseException] = None
    for attempt in range(max_retries + 1):
        try:
            resp = client.chat.completions.create(
                model=model_id,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
                max_tokens=2048,
            )
            text = resp.choices[0].message.content or ""
            return text, resp.model_dump()
        except Exception as e:  # noqa: BLE001
            last_exc = e
            # Heuristic: retry on transient HTTP errors, ECONNRESET, timeouts
            msg = str(e).lower()
            status_match = re.search(r"\b(429|500|502|503|504|524)\b", msg)
            transient = bool(status_match) or "timeout" in msg or "connection" in msg or "reset" in msg
            if attempt < max_retries and transient:
                jitter = random.uniform(0.5, 1.5)
                sleep_s = delay * jitter
                time.sleep(min(sleep_s, 60.0))
                delay = min(delay * 2.0, 60.0)
                continue
            raise
    assert last_exc is not None
    raise last_exc  # type: ignore[misc]


# ---------------------------------------------------------------------------
# Output post-processing
# ---------------------------------------------------------------------------

_FENCE_RE = re.compile(r"^```[a-zA-Z0-9]*\s*\n?|\n```\s*$", re.MULTILINE)


def strip_markdown_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = _FENCE_RE.sub("", text).strip()
    return text


def build_user_message(prompt: dict) -> str:
    lang_label = LANGUAGE_LABELS.get(prompt["language"], prompt["language"])
    return (
        f"Target IaC language: {lang_label}\n\n"
        f"Task: {prompt['prompt']}\n\n"
        f"Output only the {lang_label} code, no commentary or markdown fences."
    )


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

@dataclass
class RunStats:
    requested: int = 0
    written: int = 0
    skipped: int = 0
    failed: int = 0
    errors: list[str] = field(default_factory=list)
    lock: threading.Lock = field(default_factory=threading.Lock)

    def add(self, **kwargs) -> None:
        with self.lock:
            for k, v in kwargs.items():
                setattr(self, k, getattr(self, k) + v)


def generate_one(
    model: ModelConfig,
    prompt: dict,
    sample_idx: int,
    out_root: pathlib.Path,
    dry_run: bool,
    max_retries: int,
) -> tuple[bool, Optional[str]]:
    sample_id = f"sample_{sample_idx}"
    out_dir = out_root / model.name / prompt["prompt_id"] / sample_id
    out_file = out_dir / f"output.{LANG_TO_EXT.get(prompt['language'], 'txt')}"
    provenance = out_dir / "provenance.json"
    if out_file.exists() and provenance.exists():
        return True, "already-exists"

    out_dir.mkdir(parents=True, exist_ok=True)
    if dry_run:
        return True, "dry-run"

    user_msg = build_user_message(prompt)
    started = time.time()
    started_iso = datetime.now(timezone.utc).isoformat()
    try:
        text, meta = call_abacus_with_retry(model.model_id, user_msg, max_retries=max_retries)
    except Exception as e:  # noqa: BLE001
        return False, f"{type(e).__name__}: {str(e)[:200]}"
    elapsed = time.time() - started

    cleaned = strip_markdown_fences(text)
    out_file.write_text(cleaned)

    provenance.write_text(json.dumps({
        "model": model.name,
        "model_id": model.model_id,
        "provider": "abacus-routellm",
        "family": model.family,
        "prompt_id": prompt["prompt_id"],
        "language": prompt["language"],
        "sample_id": sample_id,
        "temperature": 0.2,
        "max_tokens": 2048,
        "system_prompt": SYSTEM_PROMPT,
        "original_prompt": prompt["prompt"],
        "user_message_sent": user_msg,
        "raw_response": text,
        "cleaned_response": cleaned,
        "provider_meta": meta,
        "started_at": started_iso,
        "elapsed_seconds": round(elapsed, 3),
    }, indent=2))
    return True, None


def run_for_model(
    model: ModelConfig,
    work: list[tuple[dict, int]],
    out_root: pathlib.Path,
    dry_run: bool,
    max_retries: int,
    stats: RunStats,
    heartbeat_every: int,
) -> None:
    done = 0
    for prompt, sample_idx in work:
        stats.add(requested=1)
        ok, msg = generate_one(model, prompt, sample_idx, out_root, dry_run, max_retries)
        if ok and msg in (None, "dry-run"):
            stats.add(written=1)
        elif ok and msg == "already-exists":
            stats.add(skipped=1)
        else:
            stats.add(failed=1)
            with stats.lock:
                stats.errors.append(f"{model.name}/{prompt['prompt_id']}/sample_{sample_idx}: {msg}")
            print(f"[fail] {model.name}/{prompt['prompt_id']}/sample_{sample_idx}: {msg}",
                  file=sys.stderr, flush=True)
        done += 1
        if done % heartbeat_every == 0:
            print(f"[hb {model.name}] done={done}/{len(work)} "
                  f"written={stats.written} skipped={stats.skipped} failed={stats.failed}",
                  flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompts", type=pathlib.Path, required=True)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--samples", type=int, default=3)
    ap.add_argument("--models", nargs="+",
                    help="Filter by model short names (default: all)")
    ap.add_argument("--prompt-ids", nargs="+",
                    help="Filter by prompt_id (default: all)")
    ap.add_argument("--workers", type=int, default=7,
                    help="Thread-pool size; default 7 = one per model in parallel")
    ap.add_argument("--max-retries", type=int, default=4,
                    help="Per-request retries on transient errors")
    ap.add_argument("--chunk-id", type=int, default=1)
    ap.add_argument("--chunk-count", type=int, default=1,
                    help="Split prompts across N machines / chunks")
    ap.add_argument("--heartbeat", type=int, default=10,
                    help="Print heartbeat every N completions per model")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.prompts.exists():
        print(f"ERROR: prompts file not found at {args.prompts}", file=sys.stderr)
        return 2

    with args.prompts.open() as f:
        all_prompts = [json.loads(l) for l in f if l.strip()]

    if args.prompt_ids:
        prompts = [p for p in all_prompts if p["prompt_id"] in set(args.prompt_ids)]
    else:
        # Sort by prompt_id for deterministic chunking
        all_prompts.sort(key=lambda p: p["prompt_id"])
        # Round-robin into chunks
        prompts = [p for i, p in enumerate(all_prompts) if (i % args.chunk_count) + 1 == args.chunk_id]

    model_filter = set(args.models or [])
    selected_models = [m for m in MODELS if not model_filter or m.name in model_filter]

    total = len(selected_models) * len(prompts) * args.samples
    print(f"[plan] chunk {args.chunk_id}/{args.chunk_count}: "
          f"{len(selected_models)} models x {len(prompts)} prompts x "
          f"{args.samples} samples = {total} generations", flush=True)
    if args.dry_run:
        print("[plan] dry-run: no API calls will be made", flush=True)

    args.out.mkdir(parents=True, exist_ok=True)

    stats = RunStats()

    # Build per-model work lists (each = list of (prompt, sample_idx))
    per_model_work: dict[str, list[tuple[dict, int]]] = {}
    for m in selected_models:
        per_model_work[m.name] = [(p, s) for p in prompts for s in range(1, args.samples + 1)]

    started_iso = datetime.now(timezone.utc).isoformat()

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {
            ex.submit(run_for_model, m, per_model_work[m.name], args.out,
                      args.dry_run, args.max_retries, stats, args.heartbeat): m.name
            for m in selected_models
        }
        for fut in concurrent.futures.as_completed(futures):
            name = futures[fut]
            try:
                fut.result()
                print(f"[model-done] {name}", flush=True)
            except Exception as e:  # noqa: BLE001
                print(f"[model-failed] {name}: {e}", file=sys.stderr, flush=True)

    summary = args.out / f"run-summary-chunk{args.chunk_id}of{args.chunk_count}.json"
    summary.write_text(json.dumps({
        "started_at": started_iso,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "endpoint": ABACUS_BASE_URL,
        "chunk_id": args.chunk_id,
        "chunk_count": args.chunk_count,
        "models": [m.name for m in selected_models],
        "model_ids": [m.model_id for m in selected_models],
        "prompt_count": len(prompts),
        "samples": args.samples,
        "workers": args.workers,
        "max_retries": args.max_retries,
        "requested": stats.requested,
        "written": stats.written,
        "skipped": stats.skipped,
        "failed": stats.failed,
        "errors": stats.errors[:500],
        "dry_run": args.dry_run,
    }, indent=2))
    print(f"[done] requested={stats.requested} written={stats.written} "
          f"skipped={stats.skipped} failed={stats.failed}", flush=True)
    print(f"[done] summary at {summary}", flush=True)
    return 0 if stats.failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
