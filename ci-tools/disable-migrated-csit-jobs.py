#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Disable the JJB CSIT jobs for projects that have moved to GitHub Actions.

Jobs are never deleted, only disabled, so the Jenkins history stays reachable
and re-enabling is a one-line revert.

``disable-job`` is set per ``jobs:`` entry rather than at project level so the
Gerrit patch-verify template (inttest-csit-verify-1node) keeps running: those
jobs stay on Jenkins until the Gerrit verify pipeline moves too.

Blocks declaring a ``build-timeout`` above the GitHub-hosted 6h ceiling are
skipped: those jobs (longevity, benchmark, scale) cannot run on GitHub-hosted
runners at all, so they stay on Jenkins and disabling them would drop the
coverage rather than move it.

Usage:
    disable-migrated-csit-jobs.py <jjb-dir> <project> [project ...]
    disable-migrated-csit-jobs.py --revert <jjb-dir> <project> [project ...]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Templates whose jobs are replaced by .github/workflows/csit-<project>.yaml.
MIGRATED_TEMPLATES = (
    "inttest-csit-1node",
    "inttest-csit-3node",
    "inttest-csit-3node-docker",
    "inttest-csit-3node-custom",
)

ENTRY_RE = re.compile(
    r"^(?P<indent>\s*)- (?P<tpl>" + "|".join(MIGRATED_TEMPLATES) + r")\s*$"
)
DISABLED_RE = re.compile(
    r"^(?P<indent>\s*)- (?P<tpl>"
    + "|".join(MIGRATED_TEMPLATES)
    + r"):\s*\n\s+disable-job: true\s*\n$"
)

# GitHub-hosted runners terminate any job at 6h, so a job declaring more than
# this cannot migrate; it stays on Jenkins and must never be disabled here.
# A block with no build-timeout inherits jjb/defaults.yaml (360) and migrates.
GH_HOSTED_MAX_MINUTES = 360
BLOCK_RE = re.compile(r"^- project:", re.M)
BUILD_TIMEOUT_RE = re.compile(r'^\s*build-timeout:\s*"?(\d+)"?\s*$', re.M)


def blocks(text: str) -> list[str]:
    """Split a JJB file into its top-level ``- project:`` blocks.

    Granularity matters: one file can hold several blocks with different
    timeouts. ``netconf-scale.yaml`` defines both ``scale`` (360, migrates)
    and ``scale-max-devices`` (720, stays), so deciding per file would be
    wrong in both directions.
    """
    starts = [m.start() for m in BLOCK_RE.finditer(text)]
    if not starts:
        return [text]
    head = [text[: starts[0]]] if starts[0] else []
    return head + [text[a:b] for a, b in zip(starts, starts[1:] + [len(text)])]


def stays_on_jenkins(block: str) -> bool:
    """True when this block's jobs exceed the GitHub-hosted 6h ceiling."""
    m = BUILD_TIMEOUT_RE.search(block)
    return bool(m) and int(m.group(1)) > GH_HOSTED_MAX_MINUTES


def project_of(text: str) -> str | None:
    """Return the JJB ``project:`` value, or None if the file has none."""
    m = re.search(r'^\s{4}project:\s*"?([\w-]+)"?\s*$', text, re.M)
    return m.group(1) if m else None


def disable(text: str) -> tuple[str, int, int]:
    """Add ``disable-job: true`` to each migrated template entry.

    Returns the new text, the number disabled, and the number deliberately
    left enabled because they cannot run on GitHub-hosted runners.
    """
    out, n, kept = [], 0, 0
    for block in blocks(text):
        keep = stays_on_jenkins(block)
        for line in block.splitlines(keepends=True):
            m = ENTRY_RE.match(line)
            if not m:
                out.append(line)
            elif keep:
                kept += 1
                out.append(line)
            else:
                out.append(f"{m['indent']}- {m['tpl']}:\n")
                out.append(f"{m['indent']}    disable-job: true\n")
                n += 1
    return "".join(out), n, kept


def revert(text: str) -> tuple[str, int, int]:
    """Undo :func:`disable`, restoring the bare template entries."""
    lines = text.splitlines(keepends=True)
    out, n, i = [], 0, 0
    while i < len(lines):
        m = re.match(
            r"^(?P<indent>\s*)- (?P<tpl>" + "|".join(MIGRATED_TEMPLATES) + r"):\s*$",
            lines[i].rstrip("\n"),
        )
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if m and nxt.strip() == "disable-job: true":
            out.append(f"{m['indent']}- {m['tpl']}\n")
            n += 1
            i += 2
            continue
        out.append(lines[i])
        i += 1
    return "".join(out), n, 0


def main() -> int:
    """Disable (or re-enable) CSIT jobs for the named projects."""
    args = sys.argv[1:]
    reverting = "--revert" in args
    args = [a for a in args if a != "--revert"]
    if len(args) < 2:
        print(__doc__)
        return 2

    jjb_dir, wanted = Path(args[0]), set(args[1:])
    changed = total = kept_total = 0

    for f in sorted(jjb_dir.rglob("*.yaml")):
        text = f.read_text()
        if not any(f"- {t}" in text for t in MIGRATED_TEMPLATES):
            continue
        if project_of(text) not in wanted:
            continue
        new, n, kept = (revert if reverting else disable)(text)
        kept_total += kept
        if kept:
            print(f"kept {kept} template(s) enabled in {f} (over the 6h ceiling)")
        if n and new != text:
            f.write_text(new)
            verb = "re-enabled" if reverting else "disabled"
            print(f"{verb} {n} template(s) in {f}")
            changed += 1
            total += n

    print(f"\n{total} job-template entries in {changed} file(s)")
    if kept_total:
        print(
            f"{kept_total} left on Jenkins: they declare a build-timeout above "
            f"{GH_HOSTED_MAX_MINUTES}m and cannot run on GitHub-hosted runners."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
