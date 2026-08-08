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

# Jenkins build-timeout, per job. Most CSIT jobs take the jjb/defaults.yaml
# value; longevity, benchmark and scale jobs override it and run for far
# longer. Carried through so a hung job is cut at the same point Jenkins
# cuts it, instead of at a blanket value.
TIMEOUT_RE = re.compile(r"<timeoutMinutes>(\d+)</timeoutMinutes>")
DEFAULT_TIMEOUT = 360
# GitHub-hosted runners terminate any job at 6h regardless of timeout-minutes,
# so a job declaring more than this cannot complete on them. Not clamped here:
# emitting the true value keeps the JSON an honest record of the Jenkins
# contract, and such a job fails visibly on time rather than reporting a
# truncated pass.
# GHA identifies a schedule by its cron string, so mri is offset 30m off the
# weekly slot they share on Jenkins.
CRONS = {
    # D9: no Jenkins->GHA bridge exists (gerrit-to-platform handles Gerrit
    # events, and a Jenkins build is not one), so distribution cannot be
    # pushed by autorelease the way it is today. autorelease-release-* is
    # itself a timer at H 0 * * * and takes hours, so CSIT runs on its own
    # timer afterwards against bundle-url: last -- the same artifact
    # autorelease would have handed it.
    "distribution": "0 5 * * *",
    "sanity": "0 6 * * *",
    "weekly": "0 23 * * 6",
    "mri": "30 23 * * 6",
}
JJB_TIMERS = {
    "distribution": "autorelease-release-* -> integration-distribution-test-*",
    "sanity": "integration-sanity-test-*                       timed daily",
    "weekly": "integration-distribution-weekly-test-trigger-*  timed H 23 * * 6",
    "mri": "integration-distribution-mri-test-*             timed H 23 * * 6",
}
PRINT_WIDTH = 80  # prettier default
GH_HOSTED_MAX_MINUTES = 360

# Pinned to a SHA, per the org policy on external actions.
CHECKOUT_SHA = "08c6903cd8c0fde910a37f88322edcfb5dd907a8"
CHECKOUT_VER = "v5.0.0"
DEPLOY_PAGES_SHA = "cd2ce8fcbc39b97be8ca5fce6e763baed58fa128"
DEPLOY_PAGES_VER = "v5.0.0"
# The shared engine. Kept in releng/builder so 13 project repos do not each
# carry a copy of the CSIT logic; they are public and in one org, so a
# cross-repo workflow_call needs no PAT.
CSIT_ENGINE = "opendaylight/releng-builder/.github/workflows/csit-run.yaml@master"


def engine_source(engine: str) -> tuple[str, str]:
    """Split an engine reference into the repo and ref to check out.

    actions/checkout defaults to the caller's repository, so csit-run.yaml
    has to be told where the CSIT scripts live. Deriving it from the same
    string that `uses:` points at means the scripts and the workflow running
    them can never come from different commits.
    """
    path, _, ref = engine.partition("@")
    owner, repo, *_ = path.split("/")
    return f"{owner}/{repo}", ref
# ponytail: becomes lfreleng-actions/csit-build-action once proven.
CSIT_ACTION = "askb/csit-build-action@main"
ORG = "opendaylight"

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

# A CSIT job's identity is the name JJB generates and uploads to Jenkins:
#
#   {prefix}{project}-csit-{1,3}node-{functionality}-{install}-{stream}
#     jjb/integration/integration-templates.yaml:410 (1node), :764 (3node)
#
# Every component of that name is carried by the job's own parameters, so the
# fields are read from JJB's output rather than parsed back out of the string:
#
#   project, functionality  <- TESTPLAN        ("{project}-{functionality}.txt")
#   install                 <- CONTROLLERSCOPE ("all" / "only")
#   1node / 3node           <- VM_0_COUNT
#   stream                  <- DISTROSTREAM
#   branch                  <- DISTROBRANCH    (per project AND stream: an MRI
#                                               project pins 0.22.x where a
#                                               managed one uses stable/vanadium)
#
# jjb_job_name() reassembles the name from those fields and scan() refuses any
# job where it does not match, so a parse that drifts fails loudly instead of
# emitting a plausible but wrong entry.


def jjb_job_name(
    project: str, odl_nodes: int, functionality: str, install: str, stream: str
) -> str:
    """The job name JJB generates, rebuilt from the job's own parameters."""
    return f"{project}-csit-{odl_nodes}node-{functionality}-{install}-{stream}"


def params(root: ET.Element) -> dict[str, str]:
    """Return the job's Jenkins parameters as a flat name to value map."""
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


def testplan(p: dict[str, str]) -> tuple[str, str] | None:
    """Split TESTPLAN into (project, functionality), JJB's own two values.

    TESTPLAN is `{project}-{functionality}.txt`. The functionality itself
    contains hyphens ("upstream-clustering", "cs-chasing-leader"), the project
    never does, so the split is on the first hyphen only.
    """
    plan = p.get("TESTPLAN", "")
    if not plan.endswith(".txt"):
        return None
    project, sep, func = plan.removesuffix(".txt").partition("-")
    return (project, func) if sep and func else None


def scan(
    xml_dir: Path,
) -> tuple[dict[str, list[dict[str, Any]]], list[str], list[str]]:
    """Group every expanded JJB CSIT job by project.

    The unit here is the job JJB uploads to Jenkins, so the file is only a
    carrier: every field comes from the job's own parameters, and the name JJB
    would generate from those fields must match the job it was read from.
    """
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
        split = testplan(p)
        if "-csit-verify-" in f.name:
            # Gerrit patch-verify jobs (*-csit-verify-1node-*) carry no install
            # or stream component in their name, so jjb_job_name() does not
            # apply. Their GerritTrigger is scoped to integration/test master
            # filtered by csit/suites/<project>/**, which is a patch on the
            # test repo, not on the project repo -- so they belong in
            # integration/test, keyed by the paths that trigger them.
            if split:
                verify.append(
                    entry_common(f.name, split, p, text)
                    | {"paths": sorted(gerrit_paths(root))}
                )
            else:
                unknown.append(f.name)
            continue
        if not split:
            unknown.append(f.name)
            continue
        project, func = split
        odl, tools = node_counts(p)
        name = jjb_job_name(project, odl, func, p.get("CONTROLLERSCOPE", ""), p["DISTROSTREAM"])
        if name != f.name:
            # The parameters no longer describe the job they belong to, so any
            # entry built from them would be wrong in a way nothing downstream
            # could detect.
            unknown.append(f"{f.name} (parameters describe {name})")
            continue
        by_project[project].append(entry_common(name, split, p, text))
    return by_project, verify, unknown


def gerrit_paths(root: ET.Element) -> set[str]:
    """The file globs a job's GerritTrigger is filtered on.

    These translate 1:1 onto `on.pull_request.paths`, so the verify jobs keep
    firing on exactly the patches they fire on today.
    """
    return {
        pattern
        for fp in root.iter("filePaths")
        for c in fp
        if (pattern := c.findtext("pattern"))
    }


def entry_common(name: str, split: tuple[str, str], p: dict, text: str) -> dict[str, Any]:
    """The fields every CSIT job entry carries, verify jobs included."""
    project, func = split
    odl, tools = node_counts(p)
    return {
        "job": name,
        "project": project,
        "functionality": func,
        "stream": p["DISTROSTREAM"],
        # per project AND stream, not per stream: a self-managed MRI
        # project pins its own version branch
        "branch": p.get("DISTROBRANCH") or p.get("GERRIT_BRANCH") or "master",
        "odl_nodes": odl,
        "tools_nodes": tools,
        "timeout": int(t.group(1)) if (t := TIMEOUT_RE.search(text)) else DEFAULT_TIMEOUT,
        "disabled": "<disabled>true</disabled>" in text,
        "params": p,
    }


def pipeline_lists(jjb_dir: Path) -> dict[str, dict[str, list[str]]]:
    """Extract the CSIT fan-out lists that the Jenkins orchestrators trigger.

    On Jenkins no CSIT job triggers itself: 148 of 152 have an empty trigger
    block and are started by an upstream job through `trigger-builds ...
    block: true`, which passes BUNDLE_URL of the distribution just built.
    Those downstream lists live in two places, so read both:

      jjb/integration/csit-jobs-<stream>.lst   integration-distribution-test
      jjb/defaults.yaml csit-<kind>-list-<s>   sanity / weekly / mri
    """
    out: dict[str, dict[str, list[str]]] = defaultdict(dict)
    for f in sorted(jjb_dir.glob("integration/csit-jobs-*.lst")):
        stream = f.name.removeprefix("csit-jobs-").removesuffix(".lst")
        jobs = [x.strip().rstrip(",") for x in f.read_text().splitlines()]
        out["distribution"][stream] = [j for j in jobs if j]

    defaults = (jjb_dir / "defaults.yaml").read_text()
    pat = r"^    csit-(mri|weekly|sanity)-list-(\w+): >\n((?:      .*\n)+)"
    for m in re.finditer(pat, defaults, re.M):
        kind, stream, body = m.group(1), m.group(2), m.group(3)
        jobs = [j.strip() for j in body.replace("\n", " ").split(",")]
        out[kind][stream] = [j for j in jobs if j]
    return dict(out)


def job_entry(j: dict[str, Any]) -> dict[str, Any]:
    """One matrix entry per Jenkins job keeps the mapping 1:1 and auditable."""
    p = j["params"]
    entry: dict[str, Any] = {
        "job": j["job"],
        "project": j["project"],
        "functionality": j["functionality"],
        "stream": j["stream"],
        "branch": j["branch"],
        "odl_nodes": j["odl_nodes"],
        "tools_nodes": j["tools_nodes"],
    }
    if j["timeout"] != DEFAULT_TIMEOUT:
        entry["timeout-minutes"] = j["timeout"]
    for param, inp in PARAM_TO_INPUT.items():
        # JJB folded scalars leave ", " separators; the CSIT scripts expect
        # a bare comma-separated list.
        val = " ".join(p.get(param, "").split())
        if inp == "install-features":
            val = val.replace(", ", ",")
        if val and val != INPUT_DEFAULTS.get(inp):
            entry[inp] = val
    return entry


def timers(pipelines: list[str]) -> tuple[str, str]:
    """`schedule:` block and the cron->pipeline expression, for one job list.

    A pipeline whose jobs all stay on Jenkins must not be scheduled at all: the
    cron would fire, select nothing, and an empty matrix is a workflow error.
    """
    timed = [(c, k) for k, c in CRONS.items() if k in pipelines]
    return (
        "".join(f'    # {JJB_TIMERS[k]}\n    - cron: "{c}"\n' for c, k in timed),
        "".join(
            f"               || (github.event.schedule == '{c}' && '{k}')\n"
            for c, k in timed
        ),
    )


def render_dispatcher(
    projects: list[str], streams: list[str], kinds: list[str], total: int
) -> str:
    """Render the dispatcher; csit-run.yaml does the actual work.

    Jenkins needed one job per CSIT configuration because a Jenkins job *is*
    the unit of scheduling. In GHA the unit is a matrix entry, so 148 job
    definitions collapse into one workflow reading .github/csit/csit-jobs.json.
    """
    schedule, pick = timers(kinds)
    return f"""---
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
#
# GENERATED by ci-tools/generate-csit-workflows.py from the expanded JJB job
# XML. Do not edit by hand: change jjb/ and regenerate.
#
# Replaces {total} Jenkins CSIT jobs across {len(projects)} projects, plus the
# Jenkins fan-out jobs integration-distribution-test-*, integration-sanity-*,
# integration-distribution-weekly-* and integration-distribution-mri-*.
#
# Data:
#   .github/csit/csit-jobs.json  every CSIT configuration
#   .github/csit/pipelines.json  which jobs each fan-out list triggers

name: CSIT

# yamllint disable-line rule:truthy
on:
  workflow_dispatch:
    inputs:
      pipeline:
        description: "Jenkins fan-out list to reproduce"
        required: false
        default: "none"
        type: choice
        {options(["none"] + kinds)}
      project:
        description: "Project to run, or 'all'"
        required: false
        default: "all"
        type: choice
        {options(["all"] + projects)}
      stream:
        description: "Stream to run, or 'all'"
        required: false
        default: "{streams[-1] if streams else 'all'}"
        type: choice
        {options(["all"] + streams)}
      functionality:
        description: "Functionality to run, or 'all'"
        required: false
        default: "all"
        type: string
      bundle-url:
        description: "Distribution zip URL, or 'last' to resolve from Nexus"
        required: false
        default: "last"
        type: string
  workflow_call:
    # Lets a distribution build reproduce Jenkins' `trigger-builds ...
    # block: true`: call this with the bundle it just built and the run
    # fails if any CSIT job fails.
    inputs:
      pipeline:
        required: false
        default: "none"
        type: string
      project:
        required: false
        default: "all"
        type: string
      stream:
        required: false
        default: "all"
        type: string
      functionality:
        required: false
        default: "all"
        type: string
      bundle-url:
        required: false
        default: "last"
        type: string
  schedule:
    # Mirrors the Jenkins timers, plus one that Jenkins does not need:
    # 'distribution' is pushed there by the distribution build, and D9 found no
    # way to push it from Jenkins to GHA. It still accepts a bundle-url from a
    # caller; the timer is the fallback so the release pipeline cannot silently
    # stop running.
{schedule}
permissions:
  contents: read

jobs:
  select:
    name: Select CSIT jobs
    runs-on: ubuntu-24.04
    outputs:
      jobs: ${{{{ steps.select.outputs.jobs }}}}
      count: ${{{{ steps.select.outputs.count }}}}
    steps:
      - name: Checkout releng/builder
        uses: actions/checkout@{CHECKOUT_SHA} # {CHECKOUT_VER}

      - name: Select
        id: select
        env:
          # Cron cannot pass inputs, so map each schedule onto its Jenkins list.
          PIPELINE: >-
            ${{{{ inputs.pipeline
{pick}               || 'none' }}}}
          PROJECT: ${{{{ inputs.project || 'all' }}}}
          STREAM: ${{{{ inputs.stream || 'all' }}}}
          FUNC: ${{{{ inputs.functionality || 'all' }}}}
        run: ./ci-tools/select-csit-jobs.py --github-output

  csit:
    needs: select
    if: needs.select.outputs.count != '0'
    uses: ./.github/workflows/csit-run.yaml
    with:
      jobs: ${{{{ needs.select.outputs.jobs }}}}
      bundle-url: ${{{{ inputs.bundle-url || 'last' }}}}
      # A local `uses:` still runs in this repository's context, so the CSIT
      # scripts must come from this commit and not from ODL master.
      builder-repo: ${{{{ github.repository }}}}
      builder-ref: ${{{{ github.sha }}}}
      # This dispatcher owns the whole fan-out, so it is the one caller
      # allowed to replace the published report.
      publish-pages: true
      report-title: >-
        ${{{{ inputs.pipeline || 'all' }}}} / ${{{{ inputs.stream || 'all' }}}}

  # Deploying lives here, not in csit-run.yaml: deploy-pages needs
  # pages: write and id-token: write, and a called workflow may not request a
  # permission its caller lacks. Keeping it in the engine would force every
  # caller -- including a Gerrit patch verify job -- to hand out an OIDC
  # token. The report job uploads the site; this job publishes it.
  #
  # always(): a failed CSIT job must not suppress the release report. The
  # report exists to show failures, so publishing only on a green run would
  # hide exactly the runs a reader needs.
  deploy:
    name: Publish report
    needs: [select, csit]
    if: always() && needs.select.outputs.count != '0'
    runs-on: ubuntu-24.04
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{{{ steps.deploy.outputs.page_url }}}}
    steps:
      - name: Deploy to GitHub Pages
        id: deploy
        # yamllint disable-line rule:line-length
        uses: actions/deploy-pages@{DEPLOY_PAGES_SHA} # {DEPLOY_PAGES_VER}
"""


# --- per-repo layout -------------------------------------------------------
#
# A CSIT job clones integration/test@master and tests a pre-built distribution
# zip. It never checks out the project repo, so nothing here needs to live on
# a release branch: the stream is an input, not a branch. The workflow lives
# on the project's default branch because `schedule` and `workflow_dispatch`
# only fire from there.

PROJECT_WORKFLOW = r"""---
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
#
# CSIT for {project}. Generated by releng/builder ci-tools -- do not edit.
#
# Replaces the JJB jobs {project}-csit-*. The job definitions live next door in
# .github/csit-jobs.json so this project owns its own CSIT configuration.
#
# This is a thin caller: the engine is releng-builder's csit-run.yaml, which
# runs jjb/integration/*.sh unmodified via csit-build-action. Nothing about
# CSIT is reimplemented per project.

name: CSIT {project}

# yamllint disable-line rule:truthy
on:
  workflow_call:
    inputs:
      pipeline:
        description: "Pipeline to reproduce, or 'none' for no filter"
        required: false
        default: "none"
        type: string
      stream:
        description: "Stream to run, or 'all'"
        required: false
        default: "all"
        type: string
      functionality:
        description: "Functionality to run, or 'all'"
        required: false
        default: "all"
        type: string
      bundle-url:
        description: "Distribution zip URL, or 'last' to resolve from Nexus"
        required: false
        default: "last"
        type: string
    outputs:
      jobs:
        description: >-
          The jobs this project selected, so a caller can report on a job that
          never started instead of silently leaving it out.
        value: ${{{{ jobs.select.outputs.jobs }}}}
  workflow_dispatch:
    inputs:
      pipeline:
        description: "Pipeline to reproduce, or 'none' for no filter"
        required: false
        default: "none"
        type: choice
        options: [none, distribution, mri, sanity, weekly]
      stream:
        description: "Stream to run, or 'all'"
        required: false
        default: "{default_stream}"
        type: choice
        {all_streams}
      functionality:
        description: "Functionality to run, or 'all'"
        required: false
        default: "all"
        type: string
      bundle-url:
        description: "Distribution zip URL, or 'last' to resolve from Nexus"
        required: false
        default: "last"
        type: string

permissions:
  contents: read

jobs:
  select:
    name: Select {project} CSIT jobs
    runs-on: ubuntu-24.04
    outputs:
      jobs: ${{{{ steps.pick.outputs.jobs }}}}
      count: ${{{{ steps.pick.outputs.count }}}}
    steps:
      - name: Checkout
        uses: actions/checkout@{checkout_sha} # {checkout_ver}

      - name: Pick matching jobs
        id: pick
        env:
          PIPELINE: ${{{{ inputs.pipeline }}}}
          STREAM: ${{{{ inputs.stream }}}}
          FUNCTIONALITY: ${{{{ inputs.functionality }}}}
        shell: bash
        run: |
          set -euo pipefail
          # Every entry carries its own pipeline membership, so selecting is a
          # local filter -- no central job list to drift out of sync with.
          jobs="$(jq -c \
            --arg p "$PIPELINE" --arg s "$STREAM" --arg f "$FUNCTIONALITY" \
            '[.[]
              | select($p == "none" or ((.pipelines // []) | index($p)) != null)
              | select($s == "all"  or .stream == $s)
              | select($f == "all"  or .functionality == $f)]' \
            .github/csit-jobs.json)"
          count="$(jq -r 'length' <<<"$jobs")"
          echo "jobs=$jobs" >>"$GITHUB_OUTPUT"
          echo "count=$count" >>"$GITHUB_OUTPUT"
          echo "$count {project} job(s) selected" >>"$GITHUB_STEP_SUMMARY"
          jq -r '.[].job' <<<"$jobs" >>"$GITHUB_STEP_SUMMARY"

  csit:
    name: CSIT
    needs: select
    # An empty matrix is a workflow error, and a project legitimately has no
    # jobs in some pipeline/stream combinations.
    if: needs.select.outputs.count != '0'
    uses: {engine}
    with:
      jobs: ${{{{ needs.select.outputs.jobs }}}}
      bundle-url: ${{{{ inputs.bundle-url }}}}
      artifact-pattern: "{project}-csit-*"
      builder-repo: {builder_repo}
      builder-ref: {builder_ref}
"""


ORCHESTRATOR_JOB = """  {project}:
    name: {project}
    uses: ./.github/workflows/PLACEHOLDER
"""


def render_project_workflow(project: str, streams: list[str], engine: str) -> str:
    """One thin caller per project repo, owning that project's job data."""
    default = "vanadium" if "vanadium" in streams else sorted(streams)[0]
    builder_repo, builder_ref = engine_source(engine)
    return PROJECT_WORKFLOW.format(
        project=project,
        engine=engine,
        builder_repo=builder_repo,
        builder_ref=builder_ref,
        default_stream=default,
        all_streams=options(["all"] + sorted(streams)),
        checkout_sha=CHECKOUT_SHA,
        checkout_ver=CHECKOUT_VER,
    )


def render_orchestrator(projects: list[str], org: str, pipelines: list[str]) -> str:
    """The fan-out that reproduces integration-distribution-test-{stream}.

    `jobs.<id>.uses` forbids expressions, so a matrix cannot pick the repo:
    each project needs a statically named job. 13 of them is well inside the
    50-unique-reusable-workflow limit, and every called job reports into this
    single run, which is what makes one release gate possible.
    """
    schedule, pick = timers(pipelines)
    head = f"""---
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
#
# CSIT fan-out. Generated by releng/builder ci-tools -- do not edit.
#
# Replaces integration-distribution-test-{{stream}}, which used
# `trigger-builds ... block: true` over the csit-jobs-{{stream}}.lst list.
#
# Scheduled runs only ever fire from a repository's default branch, so this
# lives here rather than on a release branch; the stream is an input.

name: CSIT Pipeline

# yamllint disable-line rule:truthy
on:
  schedule:
    # Mirrors the Jenkins timers, plus one that Jenkins does not need:
    # 'distribution' is pushed there by the distribution build, and D9 found no
    # way to push it from Jenkins to GHA. It still accepts a bundle-url from a
    # caller; the timer is the fallback so the release pipeline cannot silently
    # stop running.
{schedule}
  workflow_call:
    inputs:
      pipeline:
        required: false
        default: "distribution"
        type: string
      stream:
        required: false
        default: "all"
        type: string
      bundle-url:
        required: false
        default: "last"
        type: string
  workflow_dispatch:
    inputs:
      pipeline:
        description: "Pipeline to reproduce"
        required: false
        default: "distribution"
        type: choice
        {options(pipelines, indent=8)}
      stream:
        description: "Stream to run, or 'all'"
        required: false
        default: "all"
        type: string
      bundle-url:
        description: "Distribution zip URL, or 'last' to resolve from Nexus"
        required: false
        default: "last"
        type: string

permissions:
  contents: read

jobs:
  plan:
    name: Resolve pipeline
    runs-on: ubuntu-24.04
    outputs:
      pipeline: ${{{{ steps.p.outputs.pipeline }}}}
    steps:
      # Resolved once here rather than repeating the same expression in every
      # project call below.
      - id: p
        env:
          PIPELINE: >-
            ${{{{ inputs.pipeline
{pick}               || 'distribution' }}}}
        shell: bash
        run: |
          set -euo pipefail
          echo "pipeline=$PIPELINE" >>"$GITHUB_OUTPUT"
          echo "pipeline: \\`$PIPELINE\\`" >>"$GITHUB_STEP_SUMMARY"

"""
    body = ""
    for p in projects:
        body += f"""  {p}:
    needs: plan
    uses: {org}/{p}/.github/workflows/csit.yaml@master
    with:
      pipeline: ${{{{ needs.plan.outputs.pipeline }}}}
      stream: ${{{{ inputs.stream || 'all' }}}}
      bundle-url: ${{{{ inputs.bundle-url || 'last' }}}}
"""
    return head + body + render_release_report(projects) + "\n"


RELEASE_REPORT = r"""
  # Every job already reports itself on its own page. This is the other half:
  # whether an ODL release ships is one community decision, so it needs one
  # table covering every project in the run, and a job that never started has
  # to appear as a row rather than as a gap.
  report:
    name: Release report
    {needs}
    if: always()
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      pages: write # configure-pages resolves (and can enable) the site URL
    steps:
      - name: Collect dispatched jobs
        id: expected
        env:
          NEEDS: ${{{{ toJSON(needs) }}}}
        shell: bash
        run: |
          set -euo pipefail
          # Each project workflow returns the list it selected. Merging them
          # is the exact set that should have run -- artifacts alone would
          # miss a job that died before uploading anything.
          jobs="$(jq -c '
            [.[].outputs.jobs // empty]
            | map(select(. != "") | fromjson)
            | add // []
            | map({{job}})' <<<"$NEEDS")"
          echo "jobs=$jobs" >>"$GITHUB_OUTPUT"
          echo "$(jq -r 'length' <<<"$jobs") job(s) dispatched" \
            >>"$GITHUB_STEP_SUMMARY"

      - name: Download results
        # yamllint disable-line rule:line-length
        uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093 # v4.3.0
        with:
          path: results

      - name: Render release report
        # yamllint disable-line rule:line-length
        uses: {action} # ponytail: becomes lfreleng-actions/csit-build-action once proven
        with:
          mode: report
          results-dir: results
          expected-jobs: ${{{{ steps.expected.outputs.jobs }}}}
          html-dir: site
          # yamllint disable-line rule:line-length
          title: ${{{{ needs.plan.outputs.pipeline }}}} / ${{{{ inputs.stream || 'all' }}}}

      - name: Publish release report
        # yamllint disable-line rule:line-length
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
        with:
          name: csit-release-report
          path: site
          retention-days: 90

      - name: Configure Pages
        # A cron leaves nothing behind except an artifact that expires. The
        # release discussion needs a URL that outlives it.
        # yamllint disable-line rule:line-length
        uses: actions/configure-pages@45bfe0192ca1faeb007ade9deae92b16b8254a0d # v6.0.0

      - name: Upload Pages artifact
        # yamllint disable-line rule:line-length
        uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5.0.0
        with:
          path: site

  # Separate job because deploy-pages needs id-token: write, and the report
  # job downloads untrusted job output -- it should not hold that permission.
  deploy:
    name: Publish report to Pages
    needs: report
    # always(): a failed CSIT job must not suppress the release report. That
    # report exists to show failures, so publishing it only on a green run
    # would hide exactly the runs a reader needs. Without always() GitHub
    # skips this job whenever anything upstream of `report` failed.
    if: always() && needs.report.result == 'success'
    runs-on: ubuntu-24.04
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{{{ steps.deployment.outputs.page_url }}}}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        # yamllint disable-line rule:line-length
        uses: actions/deploy-pages@cd2ce8fcbc39b97be8ca5fce6e763baed58fa128 # v5.0.0

      - name: Link the report
        shell: bash
        env:
          URL: ${{{{ steps.deployment.outputs.page_url }}}}
        run: |
          echo "Release report: $URL" >>"$GITHUB_STEP_SUMMARY"
"""


def render_release_report(projects: list[str]) -> str:
    """One go/no-go table across every project in the run."""
    # plan is in needs only so the report can name the pipeline it ran. The
    # jq merge below drops it: plan has no `jobs` output.
    return RELEASE_REPORT.format(
        needs=seq("needs", ["plan"] + projects, indent=4), action=CSIT_ACTION
    ).rstrip("\n")


VERIFY_WORKFLOW = """---
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
#
# CSIT verify for {project}. Generated by releng/builder ci-tools -- do not edit.
#
# Replaces the JJB job
#   {job}
# whose GerritTrigger fires on a patch to integration/test master, filtered to
# csit/suites/{project}/**. That is a patch on THIS repo, not on {project}, so
# `on.pull_request.paths` below is a 1:1 translation of the Gerrit filePaths --
# no extra filtering logic.
#
# The suites under test come from the patch itself, so this checks out the
# merge ref rather than master.

name: CSIT verify {project}

# yamllint disable-line rule:truthy
on:
  pull_request:
    branches: [master]
    {paths}
  workflow_dispatch:

permissions:
  contents: read

jobs:
  csit:
    name: CSIT
    uses: {engine}
    with:
      # yamllint disable-line rule:line-length
      jobs: '{jobs}'
      builder-repo: {builder_repo}
      builder-ref: {builder_ref}
      # The patch under test lives in the repository this workflow runs in,
      # which is a fork whenever CI is proven outside the ODL org.
      test-repo: ${{{{ github.repository }}}}
      test-ref: refs/pull/${{{{ github.event.pull_request.number }}}}/merge
      artifact-pattern: "{project}-csit-verify-*"
"""


def render_verify(job: dict[str, Any], engine: str) -> str:
    """One workflow per verify job: `paths` is per workflow, not per job."""
    entry = job_entry(job)
    # One line: a multi-line value would end the single-quoted YAML scalar.
    body = json.dumps([entry])
    assert "'" not in body, f"{job['job']}: quoting would break the YAML scalar"
    builder_repo, builder_ref = engine_source(engine)
    return VERIFY_WORKFLOW.format(
        project=job["project"],
        job=job["job"],
        engine=engine,
        builder_repo=builder_repo,
        builder_ref=builder_ref,
        jobs=body,
        paths=seq("paths", [f'"{g}"' for g in job["paths"]], indent=4),
    )


def seq(key: str, values: list[str], indent: int = 8) -> str:
    """A YAML sequence that prettier will not reformat.

    prettier explodes an inline sequence past its print width into a form no
    human writes, so emit a block sequence ourselves once it gets long.
    """
    inline = f"{' ' * indent}{key}: [{', '.join(values)}]"
    if len(inline) <= PRINT_WIDTH:
        return inline.lstrip()
    pad = " " * (indent + 2)
    return f"{key}:\n" + "\n".join(f"{pad}- {v}" for v in values)


def options(values: list[str], indent: int = 8) -> str:
    """A `type: choice` option list that prettier will not reformat."""
    return seq("options", values, indent)


def dumps(obj: Any) -> str:
    """JSON formatted the way prettier wants it.

    These files are generated and prettier runs in each repo's pre-commit. If
    the generator emitted anything else, every regeneration would show a diff
    that is pure formatting, and real drift would hide in the noise.
    """
    def collapse(m: re.Match[str]) -> str:
        prefix, items = m.group(1), " ".join(m.group(2).split())
        # prettier only collapses when the result fits its print width.
        line = f"{prefix}[{items}]"
        return line if len(line) <= PRINT_WIDTH else m.group(0)

    # json.dumps always explodes an array; prettier keeps a short one inline.
    return (
        re.sub(
            r'(?m)^(\s*(?:"[^"]*": )?)\[\n((?:\s*"[^"]*",?\n)+)\s*\]',
            collapse,
            json.dumps(obj, indent=2),
        )
        + "\n"
    )


def emit_per_repo(
    root: Path,
    entries: list[dict[str, Any]],
    projects: list[str],
    pipelines: list[str],
    verify: list[dict[str, Any]],
) -> None:
    """Write the per-project-repo layout into a staging tree.

    Staged rather than written into the repo clones: these are ODL Gerrit
    repos and each one needs its own reviewed change.
    """
    for project in projects:
        mine = [e for e in entries if e["project"] == project]
        streams = sorted({e["stream"] for e in mine})
        d = root / project / ".github"
        (d / "workflows").mkdir(parents=True, exist_ok=True)
        (d / "csit-jobs.json").write_text(dumps(mine))
        (d / "workflows" / "csit.yaml").write_text(
            render_project_workflow(project, streams, CSIT_ENGINE)
        )
    verify_dir = root / "integration-test" / ".github" / "workflows"
    verify_dir.mkdir(parents=True, exist_ok=True)
    for job in verify:
        name = f"csit-verify-{job['project']}.yaml"
        (verify_dir / name).write_text(render_verify(job, CSIT_ENGINE))
    orch = root / "integration-distribution" / ".github" / "workflows"
    orch.mkdir(parents=True, exist_ok=True)
    (orch / "csit-pipeline.yaml").write_text(
        render_orchestrator(projects, ORG, pipelines)
    )
    print(f"\nper-repo layout staged in {root}/")
    print(f"  {len(projects)} project workflow(s) + csit-jobs.json")
    print("  1 orchestrator -> integration-distribution/.github/workflows/")
    print(f"  {len(verify)} verify workflow(s) -> integration-test/.github/workflows/")


def main() -> int:
    """Regenerate the CSIT job data and the dispatcher workflow."""
    if len(sys.argv) < 3:
        print(__doc__)
        return 2

    argv = sys.argv[1:]
    per_repo = None
    if "--per-repo" in argv:
        i = argv.index("--per-repo")
        per_repo = Path(argv[i + 1])
        del argv[i : i + 2]
    xml_dir, out_dir = Path(argv[0]), Path(argv[1])
    jjb_dir = Path(argv[2]) if len(argv) > 2 else Path("jjb")
    data_dir = out_dir.parent / "csit"

    by_project, verify, unknown = scan(xml_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)

    entries: list[dict[str, Any]] = []
    for project, jobs in sorted(by_project.items()):
        entries += [
            job_entry(j)
            for j in sorted(jobs, key=lambda x: (x["functionality"], x["stream"]))
        ]
        shapes = sorted({(j["odl_nodes"], j["tools_nodes"]) for j in jobs})
        print(
            f"  {project:<16}{len(jobs):>4} job(s)  shapes="
            + ",".join(f"{o}|{t}" for o, t in shapes)
        )
    entries.sort(key=lambda e: e["job"])

    pipelines = pipeline_lists(jjb_dir)
    raw_names = {j for k in pipelines.values() for lst in k.values() for j in lst}
    defined = {e["job"] for e in entries}
    # A job that cannot finish inside GitHub's 6h ceiling stays on Jenkins
    # (D7). Leaving it in a pipeline would make every scheduled run launch it
    # only to kill it at 6h -- wasted runner hours plus a permanently red row
    # in the report humans read to approve a release. Drop it from the lists;
    # workflow_dispatch can still reach it, exactly like the D4 orphans.
    runnable = defined - {e["job"] for e in entries if e.get("timeout-minutes")}
    for per_stream in pipelines.values():
        for stream, lst in per_stream.items():
            per_stream[stream] = [j for j in lst if j in runnable]
    # A pipeline with nothing left to run must not be scheduled at all.
    pipelines = {k: v for k, v in pipelines.items() if any(v.values())}

    # Bake pipeline membership into each entry. A project repo then filters its
    # own jobs with jq and needs no central lookup at run time, which is the
    # whole point of moving the workflows into the project repos.
    for e in entries:
        e["pipelines"] = sorted(
            kind
            for kind, per_stream in pipelines.items()
            if e["job"] in per_stream.get(e["stream"], [])
        )
    # written after baking so the central list and the per-repo copies agree
    (data_dir / "csit-jobs.json").write_text(dumps(entries))
    assert not [
        e for e in entries if e.get("timeout-minutes") and e["pipelines"]
    ], "a job that stays on Jenkins must never be reachable from a schedule"
    dangling = sorted(raw_names - defined)
    # A name in a pipeline list can miss for two very different reasons, and
    # conflating them hides real coverage loss: either no such Jenkins job
    # exists (pre-existing JJB rot, Jenkins skips it silently today), or the
    # job exists but this generator cannot express it, which means migrating
    # the pipeline would quietly drop a test.
    unmigrated = sorted(j for j in dangling if (xml_dir / j).exists())
    dangling = [j for j in dangling if j not in set(unmigrated)]
    (data_dir / "pipelines.json").write_text(
        dumps(dict(sorted(pipelines.items())))
    )

    projects = sorted(by_project)
    streams = sorted({e["stream"] for e in entries})

    if per_repo:
        emit_per_repo(per_repo, entries, projects, sorted(pipelines), verify)
    (out_dir / "csit.yaml").write_text(
        render_dispatcher(projects, streams, sorted(pipelines), len(entries))
    )

    print(f"\n{len(entries)} CSIT jobs across {len(projects)} project(s)")
    print("  -> .github/csit/csit-jobs.json")
    for kind, per_stream in sorted(pipelines.items()):
        sizes = ", ".join(f"{s}={len(v)}" for s, v in sorted(per_stream.items()))
        print(f"  pipeline {kind:<13} {sizes}")
    print("  -> .github/csit/pipelines.json")
    print("  -> .github/workflows/csit.yaml")

    if unmigrated:
        print(
            f"\n{len(unmigrated)} pipeline job(s) EXIST on Jenkins but are not "
            f"migrated -- migrating the pipeline would lose this coverage:"
        )
        for j in unmigrated:
            print(f"  {j}")
    if dangling:
        # Pre-existing in JJB: these are triggered but no job template builds
        # them, so Jenkins silently skips them today.
        print(f"\n{len(dangling)} pipeline entries reference undefined jobs:")
        for d in dangling:
            print(f"  {d}")
    over = sorted(
        (e["timeout-minutes"], e["job"])
        for e in entries
        if e.get("timeout-minutes", DEFAULT_TIMEOUT) > GH_HOSTED_MAX_MINUTES
    )
    if over:
        print(
            f"\n{len(over)} job(s) declare a timeout above the "
            f"{GH_HOSTED_MAX_MINUTES}m GitHub-hosted ceiling and CANNOT "
            "complete on GitHub-hosted runners:"
        )
        for minutes, job in over:
            print(f"  {minutes:>5}m  {job}")
    if verify:
        print(f"\n{len(verify)} Gerrit verify job(s) -> integration/test:")
        for v in verify:
            print(f"  {v['job']}  <- {', '.join(v['paths'])}")
    if unknown:
        print(f"\n{len(unknown)} unclassified CSIT job(s):")
        for u in unknown:
            print(f"  {u}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
