#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Check ci-tools/select-csit-jobs.py against the real CSIT data.

The selector decides which of the 148 CSIT jobs a run executes, so a silent
mistake here either skips coverage or starts the whole fleet by accident.

Usage: ci-tools/test-select-csit-jobs.py
"""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    "sel", ROOT / "ci-tools" / "select-csit-jobs.py"
)
sel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sel)

jobs = json.loads((ROOT / ".github/csit/csit-jobs.json").read_text())
pipelines = json.loads((ROOT / ".github/csit/pipelines.json").read_text())


def names(**kw) -> list[str]:
    """Return the selected job names for the given filters."""
    return [j["job"] for j in sel.select(jobs, pipelines, **kw)]


# No filter runs the whole fleet, matching a manual "run everything".
assert len(names()) == len(jobs) == 148, len(names())

# Filters compose, and "all"/"none" are treated as unset.
assert names(project="daexim", stream="vanadium") == [
    "daexim-csit-1node-basic-only-vanadium",
    "daexim-csit-3node-clustering-basic-only-vanadium",
], names(project="daexim", stream="vanadium")
assert names(project="all", stream="all") == names()
assert names(pipeline="none") == names()
assert len(names(project="openflowplugin")) == 57
assert names(project="daexim", functionality="basic") == [
    "daexim-csit-1node-basic-only-chromium",
    "daexim-csit-1node-basic-only-manganese",
    "daexim-csit-1node-basic-only-vanadium",
]

# A pipeline reproduces the Jenkins fan-out list exactly, and ignores filters
# because those lists name exact jobs.
van = names(pipeline="distribution", stream="vanadium")
assert van == [
    j for j in pipelines["distribution"]["vanadium"] if j in {x["job"] for x in jobs}
], van
assert "daexim-csit-1node-basic-only-vanadium" in van
# distribution-csit-managed-vanadium is in the .lst but is not a CSIT job.
assert "distribution-csit-managed-vanadium" not in van
assert names(pipeline="distribution", stream="vanadium", project="daexim") == van

# Every pipeline resolves for every stream, and sanity is the smallest.
for kind in pipelines:
    assert names(pipeline=kind), kind
assert len(names(pipeline="sanity", stream="vanadium")) == 1

# Selecting across all streams unions them without duplicates being lost.
alls = names(pipeline="sanity")
assert len(alls) == sum(
    len(names(pipeline="sanity", stream=s)) for s in pipelines["sanity"]
)

# An unknown pipeline must fail loudly rather than silently run nothing.
try:
    names(pipeline="nope")
except SystemExit as exc:
    assert "unknown pipeline" in str(exc)
else:
    raise AssertionError("unknown pipeline should raise")

# Every selected job carries what csit-run.yaml's matrix needs.
for j in sel.select(jobs, pipelines):
    for key in ("job", "project", "functionality", "stream", "branch"):
        assert j.get(key), (j["job"], key)
    assert isinstance(j["odl_nodes"], int) and j["odl_nodes"] >= 1
    assert isinstance(j["tools_nodes"], int) and j["tools_nodes"] >= 0

print("PASS: select-csit-jobs covers filters, pipelines and matrix fields")
