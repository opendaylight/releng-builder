#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""What a CSIT job does on Jenkins today, so a GHA result can be judged.

Every wave gate asks the same question: is this failure something the
migration introduced, or has the job been failing on Jenkins all along? That
question is unanswerable from a GHA run alone, and answering it by hand for
148 jobs does not scale.

Jenkins already publishes the answer. The robot plugin exposes the same
pass/fail counts robot-gate.py computes, so the two are directly comparable:

    /job/<name>/lastBuild/robot/api/json  -> passed, failed, passPercentage

A job with no builds at all (`lastBuild: null`) has no baseline -- it is new,
and any result is a first observation rather than a regression.

Usage:
    ./ci-tools/jenkins-baseline.py [--project P] [--stream S] [--json]
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

JENKINS = "https://jenkins.opendaylight.org/releng"
JOBS_JSON = Path(__file__).resolve().parent.parent / ".github/csit/csit-jobs.json"
TIMEOUT = 30


def fetch(url: str) -> dict[str, Any] | None:
    """None for anything that is not a JSON 200 -- absence is a valid answer."""
    # Jenkins 403s urllib's default User-Agent; curl gets through, so the
    # block is on the agent string, not on anonymous reads.
    req = urllib.request.Request(url, headers={"User-Agent": "csit-migration/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return json.load(r)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return None


def baseline(job: str) -> dict[str, Any]:
    """Last build result plus robot counts, for one job."""
    out: dict[str, Any] = {"job": job, "result": None, "build": None}
    info = fetch(f"{JENKINS}/job/{job}/api/json?tree=lastBuild%5Bnumber,result%5D")
    if info is None:
        out["result"] = "UNREACHABLE"
        return out
    last = info.get("lastBuild")
    if not last:
        # Never built: the job exists in JJB but Jenkins has no history, so
        # there is nothing to regress against.
        out["result"] = "NEVER-BUILT"
        return out
    out["build"] = last.get("number")
    out["result"] = last.get("result")
    robot = fetch(f"{JENKINS}/job/{job}/lastBuild/robot/api/json")
    if robot:
        out["passed"] = robot.get("overallPassed" if "overallPassed" in robot else "passed")
        out["failed"] = robot.get("overallFailed" if "overallFailed" in robot else "failed")
        out["rate"] = robot.get("passPercentage")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project")
    ap.add_argument("--stream")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("jobs", nargs="*", help="explicit job names")
    a = ap.parse_args()

    if a.jobs:
        names = a.jobs
    else:
        entries = json.loads(JOBS_JSON.read_text(encoding="utf-8"))
        names = [
            e["job"]
            for e in entries
            if (not a.project or e["project"] == a.project)
            and (not a.stream or e["stream"] == a.stream)
        ]
    if not names:
        print("no jobs matched", file=sys.stderr)
        return 1

    # Jenkins is slow per request and these are independent reads.
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(baseline, names))

    if a.json:
        print(json.dumps(rows, indent=2))
        return 0

    print(f"{'job':<54} {'jenkins':<12} {'robot':>12}  build")
    for r in sorted(rows, key=lambda x: x["job"]):
        robot = (
            f"{r['passed']}/{r['passed'] + r['failed']}"
            if r.get("passed") is not None and r.get("failed") is not None
            else "-"
        )
        print(
            f"{r['job']:<54} {str(r['result']):<12} {robot:>12}  "
            f"{r['build'] or ''}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
