#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Pick the CSIT jobs a run should execute.

Reproduces how Jenkins decides which CSIT jobs to start. On Jenkins no CSIT
job triggers itself: an upstream job fans out to a named list via
``trigger-builds``. ``--pipeline`` reproduces those lists; the project /
stream / functionality filters cover ad-hoc runs, which on Jenkins meant
clicking "Build with Parameters" on one job.

A pipeline selection is authoritative: filters are ignored, because the
Jenkins lists name exact jobs.

Reads (relative to the repo root, override with --data/--pipelines):
    .github/csit/csit-jobs.json
    .github/csit/pipelines.json

Usage:
    select-csit-jobs.py [--pipeline X] [--project X] [--stream X]
                        [--functionality X] [--github-output]

Env vars PIPELINE / PROJECT / STREAM / FUNC are used when the matching flag
is absent, so the workflow can pass everything through the environment.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
NONE = {"", "none", "all", None}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Build the argument set, falling back to the workflow's env vars."""
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--pipeline", default=os.environ.get("PIPELINE", "none"))
    p.add_argument("--project", default=os.environ.get("PROJECT", "all"))
    p.add_argument("--stream", default=os.environ.get("STREAM", "all"))
    p.add_argument("--functionality", default=os.environ.get("FUNC", "all"))
    p.add_argument("--data", type=Path, default=ROOT / ".github/csit/csit-jobs.json")
    p.add_argument(
        "--pipelines", type=Path, default=ROOT / ".github/csit/pipelines.json"
    )
    p.add_argument("--github-output", action="store_true")
    return p.parse_args(argv)


def select(
    jobs: list[dict[str, Any]],
    pipelines: dict[str, dict[str, list[str]]],
    pipeline: str = "none",
    project: str = "all",
    stream: str = "all",
    functionality: str = "all",
) -> list[dict[str, Any]]:
    """Return the jobs to run, in the order Jenkins would have started them."""
    pipeline = (pipeline or "none").strip()
    if pipeline not in NONE:
        if pipeline not in pipelines:
            raise SystemExit(
                f"unknown pipeline {pipeline!r}, expected one of "
                f"{', '.join(sorted(pipelines))}"
            )
        per_stream = pipelines[pipeline]
        streams = [stream] if (stream or "all") not in NONE else sorted(per_stream)
        wanted: list[str] = []
        for st in streams:
            wanted += per_stream.get(st, [])
        by_name = {j["job"]: j for j in jobs}
        # Names with no job definition are dropped: Jenkins skips them too.
        return [by_name[n] for n in wanted if n in by_name]

    out = jobs
    for key, val in (
        ("project", project),
        ("stream", stream),
        ("functionality", functionality),
    ):
        if (val or "all").strip() not in NONE:
            out = [j for j in out if j.get(key) == val.strip()]
    return out


def main() -> int:
    """Select jobs and emit them as JSON, optionally to GITHUB_OUTPUT."""
    args = parse_args()
    jobs = json.loads(args.data.read_text())
    pipelines = json.loads(args.pipelines.read_text())
    chosen = select(
        jobs,
        pipelines,
        args.pipeline,
        args.project,
        args.stream,
        args.functionality,
    )

    for j in chosen:
        print(j["job"], file=sys.stderr)
    print(f"{len(chosen)} job(s) selected", file=sys.stderr)

    payload = json.dumps(chosen, separators=(",", ":"))
    if args.github_output and os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as fh:
            fh.write(f"jobs={payload}\n")
            fh.write(f"count={len(chosen)}\n")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
