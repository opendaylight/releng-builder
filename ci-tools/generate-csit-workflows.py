#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Generate GHA CSIT caller workflows from the expanded JJB job XML.

Reading the *expanded* XML (``jenkins-jobs test -r jjb/ -o DIR``) rather than
the JJB source YAML means every template default, stream override and job-group
expansion is already resolved, so the generated workflows are faithful by
construction and can be regenerated whenever JJB changes.

Usage:
    generate-csit-workflows.py <jjb-xml-dir> <output-dir> [project ...]
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Any

# A CSIT job is one built from the inttest-csit-* templates. Its fingerprint is
# carrying both a TESTPLAN and the Heat VM counts; distribution-check,
# distribution-sanity and multipatch jobs carry DISTROSTREAM but neither.
CSIT_MARKER = "DISTROSTREAM"
CSIT_FINGERPRINT = ("TESTPLAN", "VM_0_COUNT", "CONTROLLERSCOPE")

# JJB parameter -> csit-run.yaml input. Anything not listed is either derived
# (node counts, from the Heat parameters) or Jenkins-only (STACK_NAME, OS_CLOUD).
PARAM_TO_INPUT = {
    "CONTROLLERFEATURES": "install-features",
    "CONTROLLERSCOPE": "controller-scope",
    "CONTROLLERMAXMEM": "controller-max-mem",
    "CONTROLLERDEBUGMAP": "debug-map",
    "ELASTICSEARCHATTRIBUTE": "elasticsearch-attribute",
    "USEFEATURESBOOT": "use-features-boot",
    "KARAF_VERSION": "karaf-version",
    "JDKVERSION": "jdk-version",
    "BUNDLE_URL": "bundle-url",
    "SUITES": "suites",
    "TESTOPTIONS": "robot-options",
}

# Inputs whose csit-run.yaml default already matches, so emitting them is noise.
INPUT_DEFAULTS = {
    "install-features": "",
    "controller-scope": "only",
    "controller-max-mem": "2048m",
    "debug-map": "",
    "elasticsearch-attribute": "disabled",
    "use-features-boot": "True",
    "karaf-version": "karaf4",
    "jdk-version": "openjdk21",
    "bundle-url": "last",
    "suites": "",
    "robot-options": "",
}

# The stream comes from the DISTROSTREAM parameter rather than the job name, so
# a new (or stale) stream needs no change here. Only the project is parsed from
# the name; the functionality comes from TESTPLAN.
NAME_RE = re.compile(r"^(?P<project>.+?)-csit-(?P<rest>.+)$")


def params(root: ET.Element) -> dict[str, str]:
    out: dict[str, str] = {}
    for p in root.iter():
        if not p.tag.rsplit("}", 1)[-1].endswith("ParameterDefinition"):
            continue
        name = p.findtext("name")
        if name:
            out[name] = (p.findtext("defaultValue") or "").strip()
    return out


def node_counts(p: dict[str, str]) -> tuple[int, int]:
    """VM_0 is the ODL/controller group, VM_1 the tools (mininet) group."""

    def n(key: str, default: int) -> int:
        v = p.get(key, "")
        return int(v) if v.isdigit() else default

    return n("VM_0_COUNT", 1), n("VM_1_COUNT", 0)


def functionality(project: str, p: dict[str, str], fallback: str) -> str:
    plan = p.get("TESTPLAN", "")
    if plan.endswith(".txt"):
        stem = plan[: -len(".txt")]
        prefix = f"{project}-"
        if stem.startswith(prefix):
            return stem[len(prefix) :]
    return fallback


def scan(xml_dir: Path) -> tuple[dict[str, list[dict[str, Any]]], list[str], list[str]]:
    by_project: dict[str, list[dict[str, Any]]] = defaultdict(list)
    verify: list[str] = []
    unknown: list[str] = []
    for f in sorted(xml_dir.iterdir()):
        if not f.is_file():
            continue
        text = f.read_text(errors="replace")
        if CSIT_MARKER not in text:
            continue
        try:
            root = ET.fromstring(text)
        except ET.ParseError:
            continue
        p = params(root)
        if any(k not in p for k in CSIT_FINGERPRINT) or not p.get("DISTROSTREAM"):
            continue
        m = NAME_RE.match(f.name)
        if not m or "-csit-verify-" in f.name:
            # Gerrit patch-verify jobs (*-csit-verify-1node-*) have no stream
            # suffix. They are real CSIT jobs but are triggered per patchset,
            # so they belong in the Gerrit verify pipeline, not a nightly
            # matrix. Reported separately rather than generated here.
            if "-csit-verify-" in f.name:
                verify.append(f.name)
            else:
                unknown.append(f.name)
            continue
        odl, tools = node_counts(p)
        by_project[m["project"]].append(
            {
                "job": f.name,
                # TESTPLAN is authoritative: the job name also carries the
                # install scope ("basic-only"), while csit-run.yaml rebuilds
                # TESTPLAN as <project>-<functionality>.txt.
                "functionality": functionality(m["project"], p, m["rest"]),
                "stream": p["DISTROSTREAM"],
                "branch": p.get("DISTROBRANCH") or p.get("GERRIT_BRANCH") or "master",
                "odl_nodes": odl,
                "tools_nodes": tools,
                "disabled": "<disabled>true</disabled>" in text,
                "params": p,
            }
        )
    return by_project, verify, unknown


def job_entry(j: dict[str, Any]) -> dict[str, Any]:
    """One matrix entry per Jenkins job keeps the mapping 1:1 and auditable."""
    p = j["params"]
    entry: dict[str, Any] = {
        "job": j["job"],
        "functionality": j["functionality"],
        "stream": j["stream"],
        "branch": j["branch"],
        "odl_nodes": j["odl_nodes"],
        "tools_nodes": j["tools_nodes"],
    }
    for param, inp in PARAM_TO_INPUT.items():
        # JJB folded scalars leave ", " separators; the CSIT scripts expect
        # a bare comma-separated list.
        val = " ".join(p.get(param, "").split())
        if inp == "install-features":
            val = val.replace(", ", ",")
        if val and val != INPUT_DEFAULTS.get(inp):
            entry[inp] = val
    return entry


def render(project: str, jobs: list[dict[str, Any]]) -> str:
    """The workflow is deliberately thin: the job list lives in JSON beside it,
    so regenerating after a JJB change touches data, not control flow."""
    streams = sorted({j["stream"] for j in jobs})
    with_lines = "\n".join(
        f"      {inp}: ${{{{ matrix.job['{inp}'] || '{INPUT_DEFAULTS[inp]}' }}}}"
        for inp in sorted(set(PARAM_TO_INPUT.values()))
    )
    return f"""---
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
#
# GENERATED by ci-tools/generate-csit-workflows.py from the expanded JJB job
# XML. Do not edit by hand: change jjb/{project}/ and regenerate.
#
# Replaces {len(jobs)} Jenkins job(s) built from jjb/{project}/*.yaml.
# The job list lives in .github/csit/{project}.json.

name: {project} CSIT

# yamllint disable-line rule:truthy
on:
  workflow_dispatch:
    inputs:
      stream:
        description: "Single stream to run, or 'all'"
        required: false
        default: "{streams[-1] if streams else 'all'}"
        type: choice
        options: [all, {", ".join(streams)}]
      functionality:
        description: "Single functionality to run, or 'all'"
        required: false
        default: "all"
        type: string
  schedule:
    # Jenkins triggered these from the distribution build; nightly is the
    # closest equivalent until distribution itself moves to GHA.
    - cron: "0 6 * * *"

permissions:
  contents: read

jobs:
  matrix:
    name: Build job matrix
    runs-on: ubuntu-24.04
    outputs:
      jobs: ${{{{ steps.build.outputs.jobs }}}}
    steps:
      - name: Checkout releng/builder
        uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8  # v5.0.0

      - name: Select jobs
        id: build
        env:
          STREAM: ${{{{ inputs.stream || 'all' }}}}
          FUNC: ${{{{ inputs.functionality || 'all' }}}}
        run: |
          jobs=$(jq -c --arg s "$STREAM" --arg f "$FUNC" \\
            '[ .[] | select($s == "all" or .stream == $s)
                   | select($f == "all" or .functionality == $f) ]' \\
            .github/csit/{project}.json)
          echo "jobs=$jobs" >> "$GITHUB_OUTPUT"
          echo "$jobs" | jq -r '.[].job'

  csit:
    needs: matrix
    if: needs.matrix.outputs.jobs != '[]'
    strategy:
      fail-fast: false
      matrix:
        job: ${{{{ fromJson(needs.matrix.outputs.jobs) }}}}
    uses: ./.github/workflows/csit-run.yaml
    with:
      project: {project}
      functionality: ${{{{ matrix.job.functionality }}}}
      stream: ${{{{ matrix.job.stream }}}}
      branch: ${{{{ matrix.job.branch }}}}
      odl-nodes: ${{{{ matrix.job.odl_nodes }}}}
      tools-nodes: ${{{{ matrix.job.tools_nodes }}}}
{with_lines}
"""


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    xml_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    data_dir = out_dir.parent / "csit"
    wanted = set(sys.argv[3:])

    by_project, verify, unknown = scan(xml_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    for project, jobs in sorted(by_project.items()):
        if wanted and project not in wanted:
            continue
        entries = [job_entry(j) for j in sorted(jobs, key=lambda x: (x["functionality"], x["stream"]))]
        (data_dir / f"{project}.json").write_text(json.dumps(entries, indent=2) + "\n")
        (out_dir / f"csit-{project}.yaml").write_text(render(project, jobs))
        total += len(jobs)
        shapes = sorted({(j["odl_nodes"], j["tools_nodes"]) for j in jobs})
        print(
            f"csit-{project}.yaml  <- {len(jobs):3d} job(s)  shapes="
            + ",".join(f"{o}|{t}" for o, t in shapes)
        )
    print(f"\n{total} CSIT jobs across {len(by_project)} project(s)")
    if verify:
        print(f"\n{len(verify)} Gerrit verify job(s) -> map to the verify pipeline:")
        for v in verify:
            print(f"  {v}")
    if unknown:
        print(f"\n{len(unknown)} unclassified CSIT job(s):")
        for u in unknown:
            print(f"  {u}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
