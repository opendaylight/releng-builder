#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Self-check for the per-repo CSIT layout.

The filter that picks a project's jobs is a jq expression embedded in a
generated workflow, so it is never exercised by importing Python. This runs
the *shipped* expression -- pulled back out of the generated YAML -- against
generated job data. An earlier version read

    select($p == "none" or (.pipelines // []) | index($p))

which jq parses as ``select((A or B) | index($p))`` because ``|`` binds looser
than ``or``; every run died with "Cannot index boolean". Nothing in Python
would have caught that.
"""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import tempfile
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent

spec = importlib.util.spec_from_file_location(
    "gen", Path(__file__).with_name("generate-csit-workflows.py")
)
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

ENTRIES = [
    {"job": "aaa-a-vanadium", "project": "aaa", "functionality": "authn",
     "stream": "vanadium", "pipelines": ["distribution", "mri"]},
    {"job": "aaa-b-chromium", "project": "aaa", "functionality": "authn",
     "stream": "chromium", "pipelines": ["mri"]},
    {"job": "aaa-c-vanadium", "project": "aaa", "functionality": "idle",
     "stream": "vanadium", "pipelines": []},
    {"job": "netconf-a-vanadium", "project": "netconf", "functionality": "scale",
     "stream": "vanadium", "pipelines": ["distribution"]},
]


def check(cond: bool, label: str) -> None:
    """Assert and report, so a failure names the property that broke."""
    assert cond, f"FAIL: {label}"
    print(f"ok: {label}")


def jq_filter(workflow: str) -> str:
    """Recover the jq program from the generated workflow."""
    m = re.search(r"'(\[\.\[\].*?)'", workflow, re.S)
    assert m, "could not find the jq program in the generated workflow"
    return m.group(1)


def run(prog: str, data: Path, pipeline: str, stream: str, func: str) -> list[str]:
    """Run the shipped jq program exactly as the workflow does."""
    out = subprocess.run(
        ["jq", "-r", "--arg", "p", pipeline, "--arg", "s", stream,
         "--arg", "f", func, f"{prog} | .[].job", str(data)],
        capture_output=True, text=True, check=True,
    )
    return sorted(x for x in out.stdout.split())


def main() -> int:
    """Run the checks."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        gen.emit_per_repo(
            root, ENTRIES, ["aaa", "netconf"], ["distribution", "mri", "sanity"], []
        )

        aaa = root / "aaa" / ".github"
        data = aaa / "csit-jobs.json"
        prog = jq_filter((aaa / "workflows" / "csit.yaml").read_text())

        check(len(json.loads(data.read_text())) == 3, "aaa keeps only its own 3 jobs")
        check(
            run(prog, data, "distribution", "all", "all") == ["aaa-a-vanadium"],
            "pipeline filter selects by membership",
        )
        check(
            run(prog, data, "mri", "all", "all")
            == ["aaa-a-vanadium", "aaa-b-chromium"],
            "a job in two pipelines matches both",
        )
        check(
            run(prog, data, "none", "vanadium", "all")
            == ["aaa-a-vanadium", "aaa-c-vanadium"],
            "pipeline 'none' means no pipeline filter",
        )
        check(
            run(prog, data, "none", "all", "idle") == ["aaa-c-vanadium"],
            "functionality filter works",
        )
        check(
            run(prog, data, "distribution", "chromium", "all") == [],
            "filters combine (empty result is legal)",
        )
        check(
            run(prog, data, "sanity", "all", "all") == [],
            "a job with no pipelines is never picked by a pipeline run",
        )

        orch = (
            root / "integration-distribution" / ".github" / "workflows"
            / "csit-pipeline.yaml"
        ).read_text()
        calls = [
            ln for ln in orch.splitlines()
            if ln.strip().startswith("uses: ") and "/.github/workflows/csit.yaml@" in ln
        ]
        check(len(calls) == 2, "orchestrator has one static call per project")

        # Reporting has two halves and both must exist: each job reports itself
        # (robot-gate, in csit-run.yaml), and the orchestrator renders one table
        # across every project -- that second one is the release go/no-go.
        check("mode: report" in orch, "orchestrator renders a release report")
        spec = yaml.safe_load(orch)["jobs"]
        report = spec["report"]
        check(
            # plan is there so the report can name the pipeline it ran.
            report["needs"] == ["plan", "aaa", "netconf"]
            and report["if"] == "always()",
            "the release report waits on every project, pass or fail",
        )
        # The report downloads artifacts built from job output, so it must not
        # be the job holding id-token: write.
        check(
            "id-token" not in report.get("permissions", {})
            and spec["deploy"]["permissions"]["id-token"] == "write"
            and spec["deploy"]["needs"] == "report",
            "Pages deployment is a separate job from the report that builds it",
        )
        # Without always() GitHub skips deploy whenever anything upstream of
        # report failed, so the release report would publish only on green
        # runs -- hiding exactly the runs a reader needs to see.
        check(
            "always()" in spec["deploy"]["if"]
            and "needs.report.result == 'success'" in spec["deploy"]["if"],
            "a failed CSIT job still publishes the release report",
        )
        check(
            "toJSON(needs)" in orch and "expected-jobs:" in orch,
            "the release report is driven by what was dispatched, not by artifacts",
        )
        check(
            "${{ matrix." not in orch.split("jobs:")[-1].split("with:")[0],
            "orchestrator never puts an expression in uses:",
        )

        # An empty pipeline must not be scheduled: every over-cap job stays on
        # Jenkins, so a cron for it would burn 6h of runner time and post a
        # permanently red row into the release report.
        only_dist = gen.render_orchestrator(["aaa"], "opendaylight", ["distribution"])
        check(
            gen.CRONS["weekly"] not in only_dist,
            "a pipeline with no runnable jobs emits no cron",
        )
        check(
            "options: [distribution]" in only_dist,
            "workflow_dispatch offers only pipelines that have jobs",
        )

        # A called workflow may not request a permission its caller lacks: the
        # whole run fails to start. The shared engine is called by the 13
        # project workflows AND by the 4 Gerrit patch verify workflows, so any
        # elevated permission it declares would have to be handed out by all
        # of them -- an OIDC token to a patch verify job, to publish a page it
        # has nothing to do with. Proven the hard way: a verify caller
        # granting only contents: read failed with startup_failure.
        engine = (REPO / ".github/workflows/csit-run.yaml").read_text(
            encoding="utf-8"
        )
        engine_jobs = yaml.safe_load(engine)["jobs"]
        elevated = {
            job: perms
            for job, spec_ in engine_jobs.items()
            if isinstance(perms := spec_.get("permissions"), dict)
            and set(perms) - {"contents"}
        }
        check(
            not elevated,
            f"the shared engine asks for no elevated permission: {elevated}",
        )
        check(
            "uses: actions/deploy-pages@" not in engine,
            "the engine uploads the site; only the fan-out owner deploys it",
        )

        # actions/checkout defaults to the CALLER's repository. The engine
        # needs releng/builder's jjb/integration and its global-jjb submodule,
        # so an implicit checkout made every cross-repo caller check itself
        # out instead -- proven by a verify run dying on "cannot stat
        # global-jjb/jenkins-init-scripts/lf-env.sh".
        for step in engine_jobs["csit"]["steps"]:
            if "actions/checkout@" in str(step.get("uses", "")):
                check(
                    "repository" in step.get("with", {}),
                    f"engine checkout is explicit: {step.get('name')}",
                )
        dispatch = (REPO / ".github/workflows/csit.yaml").read_text(
            encoding="utf-8"
        )
        callers = [
            gen.render_project_workflow("aaa", ["vanadium"], gen.CSIT_ENGINE),
            gen.render_verify(
                {
                    "job": "aaa-csit-verify-1node-authn",
                    "project": "aaa",
                    "functionality": "authn",
                    "stream": "vanadium",
                    "paths": ["csit/suites/aaa/**"],
                    "branch": "stable/vanadium",
                    "odl_nodes": 1,
                    "tools_nodes": 0,
                    "timeout": gen.DEFAULT_TIMEOUT,
                    "params": {
                        "TESTPLAN": "aaa-authn.txt",
                        "DISTROSTREAM": "vanadium",
                        "DISTROBRANCH": "stable/vanadium",
                        "VM_0_COUNT": "1",
                    },
                },
                gen.CSIT_ENGINE,
            ),
            dispatch,
        ]
        for caller in callers:
            check(
                "builder-repo:" in caller and "builder-ref:" in caller,
                "every caller tells the engine where the CSIT scripts live",
            )
        dispatch_deploy = yaml.safe_load(dispatch)["jobs"]["deploy"]
        # A cron cannot pass an input, so the schedule is mapped onto a
        # pipeline name by an expression. That mapping cannot be proven live on
        # a fork -- GitHub disables scheduled workflows there -- so it is
        # pinned here instead: every emitted cron must resolve to a pipeline
        # that actually has jobs, or the nightly run would select nothing and
        # report a green release pipeline that never ran.
        on_ = yaml.safe_load(dispatch)[True]
        pipelines = set(json.loads(
            (REPO / ".github/csit/pipelines.json").read_text(encoding="utf-8")
        ))
        for entry in on_["schedule"]:
            cron = entry["cron"]
            m = re.search(
                rf"github\.event\.schedule == '{re.escape(cron)}' && '(\w+)'",
                dispatch,
            )
            check(
                m is not None and m.group(1) in pipelines,
                f"cron {cron} maps to a pipeline that has jobs",
            )
        check(
            "github.event_name == 'schedule' && 'unmapped'" in dispatch,
            "an unmapped cron fails the selection instead of running all 148",
        )
        check(
            dispatch_deploy["permissions"]["id-token"] == "write"
            and "deploy-pages" in dispatch
            and "always()" in dispatch_deploy["if"],
            "the dispatcher deploys the report, pass or fail",
        )
        both = gen.render_orchestrator(["aaa"], "opendaylight", ["mri", "sanity"])
        crons = {ln.split('"')[1] for ln in both.splitlines() if "- cron:" in ln}
        check(
            crons == {gen.CRONS["mri"], gen.CRONS["sanity"]},
            "each surviving pipeline gets exactly its own cron",
        )

    print("\nPASS: per-repo layout filters exactly like the central selector")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
