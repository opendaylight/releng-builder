#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Disable the JJB CSIT jobs for projects that have moved to GitHub Actions.

Jobs are never deleted, only disabled, so the Jenkins history stays reachable
and re-enabling is a one-line revert.

``disable-job`` is set per ``jobs:`` entry rather than at project level so the
Gerrit patch-verify template (inttest-csit-verify-1node) keeps running: those
jobs stay on Jenkins until the Gerrit verify pipeline moves too.

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


def project_of(text: str) -> str | None:
    """Return the JJB ``project:`` value, or None if the file has none."""
    m = re.search(r'^\s{4}project:\s*"?([\w-]+)"?\s*$', text, re.M)
    return m.group(1) if m else None


def disable(text: str) -> tuple[str, int]:
    """Add ``disable-job: true`` to each migrated template entry."""
    out, n = [], 0
    for line in text.splitlines(keepends=True):
        m = ENTRY_RE.match(line)
        if m:
            out.append(f"{m['indent']}- {m['tpl']}:\n")
            out.append(f"{m['indent']}    disable-job: true\n")
            n += 1
        else:
            out.append(line)
    return "".join(out), n


def revert(text: str) -> tuple[str, int]:
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
    return "".join(out), n


def main() -> int:
    """Disable (or re-enable) CSIT jobs for the named projects."""
    args = sys.argv[1:]
    reverting = "--revert" in args
    args = [a for a in args if a != "--revert"]
    if len(args) < 2:
        print(__doc__)
        return 2

    jjb_dir, wanted = Path(args[0]), set(args[1:])
    changed = total = 0

    for f in sorted(jjb_dir.rglob("*.yaml")):
        text = f.read_text()
        if not any(f"- {t}" in text for t in MIGRATED_TEMPLATES):
            continue
        if project_of(text) not in wanted:
            continue
        new, n = (revert if reverting else disable)(text)
        if n and new != text:
            f.write_text(new)
            verb = "re-enabled" if reverting else "disabled"
            print(f"{verb} {n} template(s) in {f}")
            changed += 1
            total += n

    print(f"\n{total} job-template entries in {changed} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
