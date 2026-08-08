#!/usr/bin/env python3
# SPDX-License-Identifier: EPL-1.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""A CSIT job's identity is the name JJB uploads to Jenkins.

The generator must never infer that identity by taking a file apart. Every
field comes from the job's own parameters, and the name JJB would build from
those fields has to match the job they were read from -- otherwise a silent
misparse becomes a plausible-looking but wrong entry that nothing downstream
can catch.
"""

import importlib.util
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "gen", HERE / "generate-csit-workflows.py"
)
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

FAILURES: list[str] = []


def check(cond: bool, label: str) -> None:
    print(f"{'ok' if cond else 'FAIL'}: {label}")
    if not cond:
        FAILURES.append(label)


def job_xml(**params: str) -> str:
    """A minimal expanded-JJB job carrying just the parameters we read."""
    defs = "".join(
        f"<hudson.model.StringParameterDefinition><name>{k}</name>"
        f"<defaultValue>{v}</defaultValue></hudson.model.StringParameterDefinition>"
        for k, v in params.items()
    )
    return (
        f"<project><description>{gen.CSIT_MARKER}</description>"
        f"<properties/><parameters>{defs}</parameters></project>"
    )


BASE = {
    "TESTPLAN": "ovsdb-upstream-clustering.txt",
    "CONTROLLERSCOPE": "only",
    "DISTROSTREAM": "vanadium",
    "DISTROBRANCH": "stable/vanadium",
    "VM_0_COUNT": "3",
    "VM_1_COUNT": "1",
}
assert not set(gen.CSIT_FINGERPRINT) - set(BASE), "fixture must carry the fingerprint"
GOOD = "ovsdb-csit-3node-upstream-clustering-only-vanadium"


def scan_one(tmp: Path, name: str, params: dict[str, str]):
    for f in tmp.iterdir():
        f.unlink()
    (tmp / name).write_text(job_xml(**params))
    return gen.scan(tmp)


def main() -> int:
    check(
        gen.jjb_job_name("aaa", 1, "authn", "all", "vanadium")
        == "aaa-csit-1node-authn-all-vanadium",
        "jjb_job_name rebuilds the documented JJB template",
    )
    check(
        gen.testplan({"TESTPLAN": "controller-cs-chasing-leader.txt"})
        == ("controller", "cs-chasing-leader"),
        "a functionality containing hyphens still splits off the project",
    )
    check(gen.testplan({"TESTPLAN": "nonsense"}) is None, "a non-TESTPLAN is rejected")
    check(gen.testplan({}) is None, "a missing TESTPLAN is rejected")

    import tempfile

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)

        by_project, _, unknown = scan_one(tmp, GOOD, BASE)
        e = by_project["ovsdb"][0]
        check(not unknown and e["job"] == GOOD, "a consistent job is accepted")
        check(
            (e["project"], e["functionality"]) == ("ovsdb", "upstream-clustering"),
            "project and functionality come from TESTPLAN, not the file name",
        )
        check(
            (e["stream"], e["branch"]) == ("vanadium", "stable/vanadium"),
            "stream and branch come from DISTROSTREAM/DISTROBRANCH",
        )

        # The whole point: the file is a carrier, not the source of truth.
        by_project, _, unknown = scan_one(tmp, "totally-made-up-name", BASE)
        check(
            not by_project and len(unknown) == 1 and GOOD in unknown[0],
            "a job whose name disagrees with its parameters is rejected, not guessed",
        )

        # Each component of the generated name is actually checked.
        for field, value, why in (
            ("VM_0_COUNT", "1", "node count"),
            ("CONTROLLERSCOPE", "all", "install scope"),
            ("DISTROSTREAM", "chromium", "stream"),
            ("TESTPLAN", "ovsdb-southbound.txt", "functionality"),
        ):
            _, _, unknown = scan_one(tmp, GOOD, {**BASE, field: value})
            check(len(unknown) == 1, f"a wrong {why} is caught by the name check")

        _, _, unknown = scan_one(tmp, GOOD, {**BASE, "TESTPLAN": "junk"})
        check(len(unknown) == 1, "a job with no usable TESTPLAN is reported, not dropped")

        _, verify, unknown = scan_one(
            tmp, "aaa-csit-verify-1node-authn", {**BASE, "TESTPLAN": "aaa-authn.txt"}
        )
        check(
            [v["job"] for v in verify] == ["aaa-csit-verify-1node-authn"]
            and not unknown,
            "a Gerrit verify job is routed aside, not name-checked",
        )
        check(
            verify and verify[0]["project"] == "aaa"
            and verify[0]["functionality"] == "authn",
            "a verify job still gets its fields from TESTPLAN",
        )

    if FAILURES:
        print(f"\n{len(FAILURES)} FAILURE(S)")
        return 1
    print("\nPASS: job identity comes from JJB, and the name proves it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
